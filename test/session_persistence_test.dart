import 'dart:convert';

import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

enum _ProfileResponse { valid, offline, unauthorized, invalid }

class _SessionClient extends StarforgeApiClient {
  _SessionClient({
    this.profileResponse = _ProfileResponse.valid,
    this.role = 'ceo',
  });

  final _ProfileResponse profileResponse;
  final String role;
  final List<String> paths = [];
  final Map<String, Object?> bodies = {};

  Map<String, dynamic> get profile => {
    'id': '$role-user',
    'username': '$role.user',
    'first_name': 'Saved',
    'last_name': 'Account',
    'role': role,
    'permission_codes': <String>[],
  };

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    paths.add(path);
    bodies[path] = body;
    if (path.startsWith('/api/v1/auth/role-login') ||
        path.startsWith('/api/v1/auth/login')) {
      return const {'access': 'opaque-session-key'};
    }
    if (path == '/api/v1/auth/logout/') return const <String, dynamic>{};
    if (path == '/api/v1/users/me/' && method == 'PATCH') {
      final requestBody = Map<String, Object?>.from(body! as Map);
      return {
        'first_name': requestBody['first_name'],
        'full_name': '${requestBody['first_name']} Account',
      };
    }
    if (path == '/api/v1/users/me/') {
      switch (profileResponse) {
        case _ProfileResponse.valid:
          return profile;
        case _ProfileResponse.offline:
          throw const ApiException(
            status: 0,
            message: 'Request timed out',
            requestId: 'offline-restore',
          );
        case _ProfileResponse.unauthorized:
          throw const ApiException(
            status: 401,
            message: 'Session expired',
            requestId: 'expired-restore',
          );
        case _ProfileResponse.invalid:
          return const ['not', 'a', 'profile'];
      }
    }
    return const {
      'results': <Map<String, dynamic>>[],
      'pagination': {
        'page': 1,
        'page_size': 100,
        'total': 0,
        'pages': 1,
        'has_next': false,
      },
    };
  }
}

class _TrackingStorage implements ApiSessionStorage {
  _TrackingStorage([this.value]);

  PersistedApiSession? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<PersistedApiSession?> read() async => value;

  @override
  Future<void> write(PersistedApiSession session) async {
    writes++;
    value = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

PersistedApiSession _saved(String role) => PersistedApiSession(
  baseUrl: 'https://tenant.example.test',
  token: 'saved-opaque-key',
  profile: {
    'id': '$role-user',
    'username': '$role.user',
    'full_name': 'Cached Account',
    'role': role,
  },
);

void main() {
  test(
    'successful login persists only token, endpoint and server profile',
    () async {
      final storage = _TrackingStorage();
      final client = _SessionClient();
      final session = ApiSession(client: client, sessionStorage: storage);
      addTearDown(session.dispose);

      await session.login(
        endpoint: 'https://tenant.example.test/api/v1/auth/login/',
        username: 'ceo.user',
        password: 'NeverPersistThisPassword!',
      );

      expect(session.authenticated, isTrue);
      expect(storage.writes, 1);
      expect(storage.value?.baseUrl, 'https://tenant.example.test');
      expect(storage.value?.token, 'opaque-session-key');
      expect(storage.value?.profile['role'], 'ceo');
      expect(
        jsonEncode(storage.value?.toJson()),
        isNot(contains('NeverPersistThisPassword!')),
      );
    },
  );

  test('valid encrypted session restores and refreshes its account', () async {
    final storage = _TrackingStorage(_saved('manager'));
    final client = _SessionClient(role: 'manager');
    final session = ApiSession(client: client, sessionStorage: storage);
    addTearDown(session.dispose);

    expect(await session.restore(language: 'ru'), isTrue);

    expect(session.authenticated, isTrue);
    expect(session.me?['role'], 'manager');
    expect(session.me?['first_name'], 'Saved');
    expect(client.baseUrl, 'https://tenant.example.test');
    expect(client.paths.first, '/api/v1/users/me/');
    expect(storage.writes, 1);
  });

  test(
    'temporary startup outage keeps the last valid encrypted session',
    () async {
      final storage = _TrackingStorage(_saved('audit'));
      final session = ApiSession(
        client: _SessionClient(
          role: 'audit',
          profileResponse: _ProfileResponse.offline,
        ),
        sessionStorage: storage,
      );
      addTearDown(session.dispose);

      expect(await session.restore(), isTrue);
      expect(session.authenticated, isTrue);
      expect(session.me?['role'], 'audit');
      expect(session.lastError, 'Request timed out');
      expect(storage.clears, 0);
    },
  );

  test(
    'expired or structurally invalid account clears saved credentials',
    () async {
      for (final response in const [
        _ProfileResponse.unauthorized,
        _ProfileResponse.invalid,
      ]) {
        final storage = _TrackingStorage(_saved('ceo'));
        final session = ApiSession(
          client: _SessionClient(profileResponse: response),
          sessionStorage: storage,
        );

        expect(await session.restore(), isFalse, reason: response.name);
        expect(session.authenticated, isFalse, reason: response.name);
        expect(session.me, isNull, reason: response.name);
        expect(storage.value, isNull, reason: response.name);
        expect(storage.clears, greaterThanOrEqualTo(1), reason: response.name);
        session.dispose();
      }
    },
  );

  test(
    'logout revokes the local persistence boundary even if UI is rebuilt',
    () async {
      final storage = _TrackingStorage(_saved('student'));
      final client = _SessionClient(role: 'student')
        ..configure(
          baseUrl: 'https://tenant.example.test',
          token: 'saved-opaque-key',
        );
      final session = ApiSession(client: client, sessionStorage: storage)
        ..me = Map<String, dynamic>.from(_saved('student').profile);
      addTearDown(session.dispose);

      await session.logout();

      expect(session.authenticated, isFalse);
      expect(session.me, isNull);
      expect(storage.value, isNull);
    },
  );

  test(
    'profile update is editable for every app role but role is immutable',
    () async {
      for (final role in const ['ceo', 'manager', 'audit', 'student']) {
        final storage = _TrackingStorage(_saved(role));
        final client = _SessionClient(role: role)
          ..configure(
            baseUrl: 'https://tenant.example.test',
            token: 'opaque-session-key',
          );
        final session = ApiSession(client: client, sessionStorage: storage)
          ..me = Map<String, dynamic>.from(_saved(role).profile);

        await session.updateMe({
          'first_name': 'Edited-$role',
          'phone': '+998900000000',
          'role': role == 'ceo' ? 'student' : 'ceo',
          'permission_codes': const ['*'],
          'username': 'forbidden-change',
          'is_active': false,
        });

        final body = client.bodies['/api/v1/users/me/'] as Map;
        expect(body, {
          'first_name': 'Edited-$role',
          'phone': '+998900000000',
        }, reason: role);
        expect(session.me?['role'], role, reason: role);
        expect(storage.value?.profile['role'], role, reason: role);
        session.dispose();
      }
    },
  );
}
