import 'dart:convert';
import 'dart:io';

import 'package:ceo_manager/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _json(
  HttpResponse response,
  int status,
  Object body, {
  Map<String, String> headers = const {},
}) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  for (final entry in headers.entries) {
    response.headers.set(entry.key, entry.value);
  }
  response.write(jsonEncode(body));
  await response.close();
}

void main() {
  test(
    'transport keeps schema fallbacks without changing response data',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        switch (request.uri.path) {
          case '/api/v1/auth/login/':
            await utf8.decoder.bind(request).join();
            await _json(request.response, HttpStatus.created, {
              'success': true,
              'data': {
                'auth': {'access_token': 'nested-session-key'},
              },
            });
            return;
          case '/warnings/':
            await _json(request.response, HttpStatus.ok, {
              'success': true,
              'data': {'value': 7},
              'warnings': ['analytics temporarily degraded', ''],
            });
            return;
          case '/plain/':
            await _json(request.response, HttpStatus.ok, {'legacy': true});
            return;
          case '/forbidden/':
            await _json(request.response, HttpStatus.forbidden, {
              'success': false,
              'error': {
                'code': 'permission_denied',
                'message': 'This role cannot read the resource.',
                'errors': {
                  'permission': ['audit:read'],
                },
              },
              'request_id': 'server-forbidden-403',
            });
            return;
          case '/rate-limited/':
            await _json(
              request.response,
              HttpStatus.tooManyRequests,
              {
                'success': false,
                'code': 'throttled',
                'message': 'Please slow down.',
              },
              headers: {'retry-after': '17'},
            );
            return;
          case '/expired/':
            await _json(request.response, HttpStatus.unauthorized, {
              'success': false,
              'code': 'session_expired',
              'message': 'Sign in again.',
            });
            return;
          default:
            await _json(request.response, HttpStatus.notFound, {
              'success': false,
              'code': 'not_found',
              'message': 'Missing.',
            });
            return;
        }
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      await client.login(username: 'admin', password: 'root');
      expect(client.token, 'nested-session-key');

      expect(await client.request('GET', '/warnings/'), {'value': 7});
      expect(client.lastWarnings, ['analytics temporarily degraded']);
      expect(await client.request('GET', '/plain/'), {'legacy': true});
      expect(client.lastWarnings, isEmpty);

      await expectLater(
        client.request('GET', '/forbidden/'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 403)
              .having((error) => error.code, 'code', 'permission_denied')
              .having(
                (error) => error.message,
                'message',
                'This role cannot read the resource.',
              )
              .having(
                (error) => error.requestId,
                'requestId',
                'server-forbidden-403',
              )
              .having((error) => error.errors?['permission'], 'field errors', [
                'audit:read',
              ]),
        ),
      );
      expect(
        client.hasSession,
        isTrue,
        reason: '403 must not destroy a session',
      );

      await expectLater(
        client.request('GET', '/rate-limited/'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 429)
              .having((error) => error.code, 'code', 'throttled')
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 17),
              ),
        ),
      );
      expect(
        client.hasSession,
        isTrue,
        reason: '429 must not destroy a session',
      );

      var unauthorizedCalls = 0;
      client.onUnauthorized = () => unauthorizedCalls++;
      await expectLater(
        client.request('GET', '/expired/'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 401)
              .having((error) => error.code, 'code', 'session_expired'),
        ),
      );
      expect(client.hasSession, isFalse);
      expect(unauthorizedCalls, 1);
    },
  );

  test(
    'login accepts a nested opaque session key from the schema envelope',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'data': {
            'session': {'key': 'opaque-session-key'},
          },
        });
      });

      final client = StarforgeApiClient(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      await client.login(username: 'admin', password: 'root');

      expect(client.token, 'opaque-session-key');
    },
  );
}
