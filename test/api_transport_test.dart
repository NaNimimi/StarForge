import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ceo_manager/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'JSON transport sends login body with a declared content length',
    () async {
      const expectedBody = {
        'username': 'admin',
        'password': 'пароль🔐',
        'platform': 'mobile',
      };
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
      expect(request.path, '/api/v1/auth/login/');
      expect(
        request.contentLength,
        utf8.encode(jsonEncode(expectedBody)).length,
      );
      expect(request.chunked, isFalse);
      expect(request.contentType, 'application/json');
      expect(request.body, expectedBody);
    },
  );
}
