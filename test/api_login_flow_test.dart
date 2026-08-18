import 'dart:async';

import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_connection.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoginClient extends StarforgeApiClient {
  _LoginClient({
    this.failOptionalResource = false,
    this.failOptionalUnexpected = false,
    this.invalidProfileResponse = false,
    this.loginError,
  });

  final bool failOptionalResource;
  final bool failOptionalUnexpected;
  final bool invalidProfileResponse;
  final ApiException? loginError;
  final List<String> requestedPaths = [];
  final Map<String, Object?> requestedBodies = {};

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    requestedPaths.add(path);
    requestedBodies[path] = body;
    if (path == '/api/v1/auth/role-login/' || path == '/api/v1/auth/login/') {
      if (loginError case final error?) throw error;
      return const {'access': 'secure-test-session'};
    }
    if (path == '/api/v1/users/me/') {
      if (invalidProfileResponse) return const ['not-a-profile'];
      return const {
        'id': 'user-7',
        'username': 'director',
        'full_name': 'API Director',
        'role': 'ceo',
        'permissions': ['*'],
      };
    }
    if (failOptionalResource && path == '/api/v1/meetings/') {
      throw const ApiException(
        status: 503,
        message: 'Meetings temporarily unavailable',
        requestId: 'login-partial-resource',
      );
    }
    if (failOptionalUnexpected && path == '/api/v1/meetings/') {
      throw StateError('Malformed meetings response');
    }
    return const {
      'success': true,
      'data': <Map<String, dynamic>>[],
      'pagination': {'page': 1, 'page_size': 25, 'total': 0},
    };
  }
}

class _SlowBootstrapClient extends _LoginClient {
  final Completer<dynamic> studentsGate = Completer<dynamic>();

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    if (path == '/api/v1/students/') {
      requestedPaths.add(path);
      return studentsGate.future;
    }
    return super.request(
      method,
      path,
      query: query,
      body: body,
      authenticate: authenticate,
      timeout: timeout,
    );
  }
}

Widget _host(ApiSession session) {
  final settings = AppSettings(lang: SfLang.ru);
  return ApiScope(
    session: session,
    child: SettingsScope(
      settings: settings,
      child: AppScope(
        store: AppStore.seed(SfRole.ceo),
        child: MaterialApp(
          theme: sfMaterialTheme(settings.colors, dark: settings.dark),
          home: const SfTheme(colors: SfColors.light, child: ApiLoginScreen()),
        ),
      ),
    ),
  );
}

void main() {
  test(
    'successful authentication does not wait for dashboard bootstrap',
    () async {
      final client = _SlowBootstrapClient();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      await session
          .login(
            endpoint: 'https://api.example.test',
            username: 'director',
            password: 'secret',
          )
          .timeout(const Duration(seconds: 1));

      expect(session.authenticated, isTrue);
      expect(session.me?['role'], 'ceo');
      expect(client.requestedPaths, contains('/api/v1/students/'));
      expect(client.studentsGate.isCompleted, isFalse);
      client.studentsGate.complete(const {
        'data': <Map<String, dynamic>>[],
        'pagination': {'page': 1, 'page_size': 100, 'total': 0},
      });
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets('startup login authenticates against API and loads profile', (
    tester,
  ) async {
    final client = _LoginClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pumpAndSettle();

    expect(session.authenticated, isTrue);
    expect(session.me?['role'], 'ceo');
    expect(session.me?['full_name'], 'API Director');
    expect(client.requestedPaths.first, '/api/v1/auth/role-login/');
    expect(client.requestedBodies['/api/v1/auth/role-login/'], {
      'username': 'director',
      'password': 'secret',
    });
    expect(client.requestedPaths, contains('/api/v1/users/me/'));
    expect(find.byKey(const ValueKey('workspace-ceo')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional bootstrap failure does not cancel valid login', (
    tester,
  ) async {
    final session = ApiSession(
      client: _LoginClient(failOptionalResource: true),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pumpAndSettle();

    expect(session.authenticated, isTrue);
    expect(session.resourceError('meetings')?.status, 503);
    expect(session.me?['role'], 'ceo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unexpected bootstrap failure does not cancel valid login', (
    tester,
  ) async {
    final session = ApiSession(
      client: _LoginClient(failOptionalUnexpected: true),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pumpAndSettle();

    expect(session.authenticated, isTrue);
    expect(session.me?['role'], 'ceo');
    expect(
      session.resourceError('meetings')?.code,
      'invalid_resource_response',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid profile response clears token and shows exact error', (
    tester,
  ) async {
    final session = ApiSession(
      client: _LoginClient(invalidProfileResponse: true),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pumpAndSettle();

    expect(session.authenticated, isFalse);
    expect(session.me, isNull);
    expect(
      find.textContaining('Сервер вернул профиль аккаунта в неверном формате.'),
      findsOneWidget,
    );
    expect(find.text('Не удалось подключиться к API.'), findsNothing);
  });

  testWidgets('login exposes published phone password reset flow', (
    tester,
  ) async {
    final client = _LoginClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.tap(
      find.byKey(const ValueKey('api-login-forgot-password')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('api-reset-phone')),
      '+998901234567',
    );
    await tester.tap(
      find.byKey(const ValueKey('api-reset-request-submit')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(
      client.requestedPaths,
      contains('/api/v1/auth/password/reset/request/'),
    );
    expect(client.requestedBodies['/api/v1/auth/password/reset/request/'], {
      'phone': '+998901234567',
    });
    expect(find.byKey(const ValueKey('api-reset-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-reset-password')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid credentials are shown in the selected language', (
    tester,
  ) async {
    final client = _LoginClient(
      loginError: const ApiException(
        status: 401,
        code: 'invalid_credentials',
        message: 'Login yoki parol noto‘g‘ri.',
        requestId: 'login-invalid-401',
      ),
    );
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pumpAndSettle();

    expect(session.authenticated, isFalse);
    expect(client.requestedPaths, ['/api/v1/auth/role-login/']);
    expect(find.textContaining('Неверный логин или пароль'), findsOneWidget);
    expect(find.textContaining('login-invalid-401'), findsOneWidget);
    expect(find.text('Validation failed'), findsNothing);
  });

  testWidgets('rate limit disables login until server retry window expires', (
    tester,
  ) async {
    final session = ApiSession(
      client: _LoginClient(
        loginError: const ApiException(
          status: 429,
          code: 'throttled',
          message: 'Too many requests. Please slow down.',
          requestId: 'login-throttled-429',
          retryAfter: Duration(seconds: 60),
        ),
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));
    await tester.enterText(
      find.byKey(const ValueKey('api-login-username')),
      'director',
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-login-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('api-login-submit')));
    await tester.pump();

    expect(find.textContaining('Слишком много попыток'), findsOneWidget);
    expect(find.textContaining('Повторить · 60 сек.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('api-login-submit')))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Войти'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('api-login-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'validation failure includes field details instead of raw title',
    (tester) async {
      final session = ApiSession(
        client: _LoginClient(
          loginError: const ApiException(
            status: 422,
            code: 'validation_error',
            message: 'Validation failed',
            errors: {
              'username': ['This field is required.'],
            },
            requestId: 'login-validation-422',
          ),
        ),
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(_host(session));
      await tester.enterText(
        find.byKey(const ValueKey('api-login-username')),
        'director',
      );
      await tester.enterText(
        find.byKey(const ValueKey('api-login-password')),
        'secret',
      );
      await tester.tap(find.byKey(const ValueKey('api-login-submit')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Проверьте введённые данные.'),
        findsOneWidget,
      );
      expect(find.textContaining('Логин: Обязательное поле'), findsOneWidget);
      expect(find.textContaining('[This field is required.]'), findsNothing);
      expect(find.textContaining('login-validation-422'), findsOneWidget);
      expect(find.text('Validation failed'), findsNothing);
    },
  );

  testWidgets('login contains no editable server selector', (tester) async {
    final session = ApiSession(client: _LoginClient());
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session));

    expect(find.byKey(const ValueKey('api-login-server-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('api-login-endpoint')), findsNothing);
    expect(find.text('Сервер API'), findsNothing);
    expect(find.byKey(const ValueKey('api-login-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-login-password')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('api-login-forgot-password')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
