import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ceo_manager/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API build variable accepts an origin or API prefix', () {
    expect(
      normalizeStarforgeApiBaseUrl('https://api.example.test/'),
      'https://api.example.test',
    );
    expect(
      normalizeStarforgeApiBaseUrl('https://api.example.test/api/v1/'),
      'https://api.example.test',
    );
    expect(
      normalizeStarforgeApiBaseUrl(
        'https://api.example.test/tenant/api/v1?ignored=true',
      ),
      'https://api.example.test/tenant',
    );
  });

  test(
    'JSON transport sends login body with a declared content length',
    () async {
      const expectedBody = {'username': 'admin', 'password': 'пароль🔐'};
      final received =
          Completer<
            ({
              String method,
              String path,
              int contentLength,
              bool chunked,
              String? contentType,
              Object? body,
            })
          >();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        received.complete((
          method: request.method,
          path: request.uri.path,
          contentLength: request.contentLength,
          chunked: request.headers.chunkedTransferEncoding,
          contentType: request.headers.contentType?.mimeType,
          body: jsonDecode(text),
        ));
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'success': true,
              'data': {'access': 'transport-test-session'},
            }),
          );
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      final session = await client.login(
        username: ' admin ',
        password: 'пароль🔐',
      );
      final request = await received.future.timeout(const Duration(seconds: 5));

      expect(session['access'], 'transport-test-session');
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/role-login/');
      expect(
        request.contentLength,
        utf8.encode(jsonEncode(expectedBody)).length,
      );
      expect(request.chunked, isFalse);
      expect(request.contentType, 'application/json');
      expect(request.body, expectedBody);
    },
  );

  test(
    'full login URL build variable does not duplicate the API path',
    () async {
      final receivedPath = Completer<String>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        receivedPath.complete(request.uri.path);
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'success': true,
              'data': {'access': 'normalized-session'},
            }),
          );
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl:
            'http://${server.address.host}:${server.port}/api/v1/auth/login/',
      );
      await client.login(username: 'admin', password: 'root');

      expect(client.baseUrl, 'http://${server.address.host}:${server.port}');
      expect(
        await receivedPath.future.timeout(const Duration(seconds: 5)),
        '/api/v1/auth/role-login/',
      );
    },
  );

  test(
    'login falls back to generic login only after a missing role route',
    () async {
      final paths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        paths.add(request.uri.path);
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/v1/auth/role-login/') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write(
              jsonEncode({
                'success': false,
                'code': 'not_found',
                'message': 'Resource not found.',
              }),
            );
        } else {
          request.response
            ..statusCode = HttpStatus.created
            ..write(
              jsonEncode({
                'success': true,
                'data': {'access': 'fallback-session'},
              }),
            );
        }
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      await client.login(username: 'admin', password: 'root');

      expect(paths, ['/api/v1/auth/role-login/', '/api/v1/auth/login/']);
      expect(client.token, 'fallback-session');
    },
  );

  test('login never retries invalid credentials on another route', () async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      paths.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'success': false,
            'code': 'invalid_credentials',
            'message': 'Invalid username or password.',
          }),
        );
      await request.response.close();
    });

    final client = StarforgeApiClient(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    await expectLater(
      client.login(username: 'admin', password: 'wrong'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.status, 'status', 401)
            .having((error) => error.code, 'code', 'invalid_credentials'),
      ),
    );

    expect(paths, ['/api/v1/auth/role-login/']);
  });

  test('cursor page does not send an unsupported numeric page', () async {
    Uri? receivedUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      receivedUri = request.uri;
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'success': true,
            'data': {
              'results': [
                {'id': 7, 'action': 'login'},
              ],
              'next': null,
              'previous': null,
            },
          }),
        );
      await request.response.close();
    });

    final client = StarforgeApiClient(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    client.configure(token: 'session');
    final page = await client.cursorPage('/api/v1/audit/', pageSize: 500);

    expect(receivedUri?.path, '/api/v1/audit/');
    expect(receivedUri?.queryParameters['page'], isNull);
    expect(receivedUri?.queryParameters['page_size'], '100');
    expect(page.items.single['action'], 'login');
  });

  test(
    'cursor list follows notification history without numeric pages',
    () async {
      final received = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        received.add(request.uri);
        final cursor = request.uri.queryParameters['cursor'];
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'results': [
                {'id': cursor == null ? 1 : 2, 'title': 'Notification'},
              ],
              'next': cursor == null
                  ? 'http://${server.address.host}:${server.port}'
                        '/api/v1/notifications/?cursor=second-page'
                  : null,
              'previous': null,
            }),
          );
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      )..configure(token: 'session');
      final page = await client.cursorList('/api/v1/notifications/');

      expect(page.items.map((row) => row['id']), [1, 2]);
      expect(received, hasLength(2));
      expect(
        received.every((uri) => !uri.queryParameters.containsKey('page')),
        isTrue,
      );
      expect(received.last.queryParameters['cursor'], 'second-page');
    },
  );

  test('ordinary collections never exceed the live page-size limit', () async {
    final receivedSizes = <int>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final page = int.parse(request.uri.queryParameters['page'] ?? '1');
      final size = int.parse(request.uri.queryParameters['page_size'] ?? '0');
      receivedSizes.add(size);
      final start = (page - 1) * size;
      final end = (start + size).clamp(0, 205);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'success': true,
            'data': [
              for (var index = start; index < end; index++) {'id': index + 1},
            ],
            'pagination': {
              'page': page,
              'page_size': size,
              'total': 205,
              'pages': 3,
              'has_next': page < 3,
            },
          }),
        );
      await request.response.close();
    });

    final client = StarforgeApiClient(
      baseUrl: 'http://${server.address.host}:${server.port}',
    )..configure(token: 'session');
    final result = await client.list('/api/v1/students/');

    expect(result.items, hasLength(205));
    expect(receivedSizes, [100, 100, 100]);
  });

  test(
    'ordinary collections follow a hidden two-row server page cap',
    () async {
      final receivedPages = <int>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final page = int.parse(request.uri.queryParameters['page'] ?? '1');
        receivedPages.add(page);
        final start = (page - 1) * 2;
        final end = (start + 2).clamp(0, 5);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'success': true,
              'data': [
                for (var index = start; index < end; index++)
                  {'id': index + 1, 'name': 'Student ${index + 1}'},
              ],
              // This intentionally reproduces the deployment that caps the
              // response but omits page_size/pages/has_next.
              'pagination': {'page': page, 'total': 5},
            }),
          );
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      )..configure(token: 'session');
      final result = await client.list('/api/v1/students/');

      expect(receivedPages, [1, 2, 3]);
      expect(result.items.map((row) => row['id']), [1, 2, 3, 4, 5]);
      expect(result.total, 5);
    },
  );

  test(
    'ordinary collections stop repeated pages and deduplicate records',
    () async {
      var requests = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requests++;
        final page = int.parse(request.uri.queryParameters['page'] ?? '1');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'success': true,
              // Simulates an older proxy that advertises more pages but repeats
              // the same database rows for every `page` value.
              'data': [
                {'id': 1, 'name': 'Actual student'},
                {'id': 1, 'name': 'Actual student'},
              ],
              'pagination': {
                'page': page,
                'page_size': 100,
                'total': 900,
                'pages': 9,
                'has_next': true,
              },
            }),
          );
        await request.response.close();
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      )..configure(token: 'session');
      await expectLater(
        client.list('/api/v1/students/'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'invalid_pagination',
          ),
        ),
      );

      expect(requests, 2);
    },
  );

  test('self profile update rejects unsupported gender explicitly', () async {
    final receivedBodies = <Object?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      if (rawBody.isNotEmpty) receivedBodies.add(jsonDecode(rawBody));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'success': true,
            'data': {'first_name': 'Aziza', 'full_name': 'Aziza Student'},
          }),
        );
      await request.response.close();
    });

    final client = StarforgeApiClient(
      baseUrl: 'http://${server.address.host}:${server.port}',
    )..configure(token: 'session');
    final session = ApiSession(client: client)
      ..me = {
        'id': 5,
        'role': 'student',
        'permission_codes': ['students:self'],
      };
    addTearDown(session.dispose);

    await expectLater(
      session.updateMe({
        'first_name': 'Aziza',
        'gender': 'f',
        'role': 'ceo',
        'username': 'changed',
        'is_active': false,
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'profile_field_not_supported',
        ),
      ),
    );

    expect(receivedBodies, isEmpty);
    expect(session.me?['role'], 'student');
    expect(session.me?['permission_codes'], ['students:self']);
    expect(session.me?['full_name'], 'Aziza Student');
    expect(session.me?['gender'], isNull);
  });

  test('self profile update sends gender when server publishes it', () async {
    final patchBodies = <Object?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final bodyText = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/v1/auth/role-login/') {
        request.response
          ..statusCode = HttpStatus.created
          ..write(
            jsonEncode({
              'success': true,
              'data': {'access': 'profile-gender-session'},
            }),
          );
      } else if (request.uri.path == '/api/v1/users/me/' &&
          request.method == 'GET') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            jsonEncode({
              'success': true,
              'data': {
                'id': 5,
                'username': 'director',
                'first_name': 'Aziza',
                'gender': '',
                'birthdate': null,
              },
            }),
          );
      } else if (request.uri.path == '/api/v1/users/me/' &&
          request.method == 'PATCH') {
        final body = jsonDecode(bodyText);
        patchBodies.add(body);
        request.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': true, 'data': body}));
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': true, 'data': <Object?>[]}));
      }
      await request.response.close();
    });

    final session = ApiSession();
    addTearDown(session.dispose);
    await session.login(
      endpoint: 'http://${server.address.host}:${server.port}',
      username: 'director',
      password: 'secret',
    );
    await session.updateMe({'gender': 'f'});

    expect(patchBodies, [
      {'gender': 'f'},
    ]);
    expect(session.me?['gender'], 'f');
  });
}
