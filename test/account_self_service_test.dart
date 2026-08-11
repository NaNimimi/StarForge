import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/main.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SelfServiceClient extends StarforgeApiClient {
  _SelfServiceClient() {
    configure(token: 'self-service-session');
  }

  final paths = <String>[];

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    paths.add(path);
    return const ApiPage(items: []);
  }

  @override
  Future<ApiPage> cursorList(
    String path, {
    Map<String, Object?>? query,
    int pageSize = 100,
  }) async {
    paths.add(path);
    return const ApiPage(items: []);
  }

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
    if (path == '/api/v1/parents/me/children/') {
      return const [
        {'id': 81, 'full_name': 'QA Child', 'cohort_name': 'QA Group'},
      ];
    }
    return const <String, dynamic>{'count': 0};
  }
}

void main() {
  test('student and parent aliases enter only the self-service workspace', () {
    for (final alias in const [
      'student',
      'learner',
      'pupil',
      'parent',
      'guardian',
      'caregiver',
    ]) {
      expect(
        sfRoleFromApiProfile({'principal_kind': alias}),
        SfRole.student,
        reason: alias,
      );
    }
  });

  test('student and parent bootstrap only messages and notifications when the '
      'legacy profile omits permissions', () async {
    for (final principal in const ['student', 'parent']) {
      final client = _SelfServiceClient();
      final session = ApiSession(client: client)
        ..me = {
          'id': principal == 'student' ? 71 : 72,
          'username': 'qa.$principal.20260804',
          'principal_kind': principal,
        };
      addTearDown(session.dispose);

      await session.reloadAll();

      expect(client.paths.toSet(), {
        '/api/v1/messaging/threads/',
        '/api/v1/notifications/',
        '/api/v1/notifications/unread-count/',
      }, reason: principal);
      expect(
        client.paths,
        isNot(contains('/api/v1/students/')),
        reason: principal,
      );
      expect(
        client.paths,
        isNot(contains('/api/v1/parents/')),
        reason: principal,
      );
    }
  });

  test(
    'participant-scoped chat loads when self-service permissions are empty',
    () async {
      for (final principal in const ['student', 'parent']) {
        final client = _SelfServiceClient();
        final session = ApiSession(client: client)
          ..me = {
            'id': principal == 'student' ? 71 : 72,
            'username': 'qa.$principal.20260804',
            'principal_kind': principal,
            // An empty published list is authoritative for staff resources,
            // but must not suppress the participant-owned messaging feed.
            'permissions': <String>[],
          };
        addTearDown(session.dispose);

        await session.reloadAll();

        expect(
          client.paths,
          contains('/api/v1/messaging/threads/'),
          reason: principal,
        );
        expect(
          client.paths,
          contains('/api/v1/notifications/'),
          reason: principal,
        );
        expect(
          client.paths,
          isNot(contains('/api/v1/students/')),
          reason: principal,
        );
      }
    },
  );

  testWidgets(
    'parent self-service reads the published children endpoint, not student '
    'dashboard endpoints',
    (tester) async {
      final client = _SelfServiceClient();
      final session = ApiSession(client: client)
        ..me = {
          'id': 72,
          'username': 'qa.parent.20260804',
          'role': {'account_type_slug': 'guardian'},
        };
      final store = AppStore.empty(SfRole.student);
      addTearDown(session.dispose);
      addTearDown(store.dispose);

      await tester.pumpWidget(
        SettingsScope(
          settings: AppSettings(),
          child: ApiScope(
            session: session,
            child: AppScope(
              store: store,
              child: MaterialApp(
                home: SfTheme(
                  colors: SfColors.light,
                  child: const Scaffold(
                    body: StudentSelfServiceScreen(colors: SfColors.light),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('QA Child'), findsOneWidget);
      expect(client.paths, contains('/api/v1/parents/me/children/'));
      expect(client.paths, isNot(contains('/api/v1/students/me/dashboard/')));
      expect(client.paths, isNot(contains('/api/v1/students/me/report/')));
      expect(tester.takeException(), isNull);
    },
  );
}
