import 'dart:io';

import 'package:ceo_manager/api_catalog.dart';
import 'package:ceo_manager/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingClient extends StarforgeApiClient {
  final calls = <({String method, String path, Object? body})>[];
  final listCalls = <String>[];
  bool failRefresh = false;

  _RecordingClient() {
    configure(token: 'contract-session');
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
    calls.add((method: method, path: path, body: body));
    return <String, dynamic>{'id': 1};
  }

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    listCalls.add(path);
    if (failRefresh) {
      throw const ApiException(
        status: HttpStatus.serviceUnavailable,
        message: 'refresh unavailable',
        requestId: 'refresh-503',
      );
    }
    return const ApiPage(items: []);
  }
}

void main() {
  group('supplied OpenAPI catalogue', () {
    test(
      'generated catalogue covers every published operation exactly once',
      () {
        expect(kPublishedApiOperations, hasLength(487));
        expect(
          kPublishedApiOperations.map((operation) => operation.key).toSet(),
          hasLength(487),
        );
        expect(
          kPublishedApiOperations.map((operation) => operation.path).toSet(),
          hasLength(321),
        );
        final methodCounts = <String, int>{};
        for (final operation in kPublishedApiOperations) {
          methodCounts.update(
            operation.method,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        expect(methodCounts, {
          'GET': 216,
          'POST': 169,
          'PUT': 33,
          'PATCH': 37,
          'DELETE': 32,
        });
      },
    );

    test(
      'all named resources use v1 paths and no invented refund collection',
      () {
        expect(kApiResources, isNotEmpty);
        expect(kApiResources.values, everyElement(startsWith('/api/v1/')));
        expect(
          kApiResources.values,
          isNot(contains('/api/v1/finance/refunds/')),
        );
        expect(kApiResources, isNot(contains('refunds')));
      },
    );

    test('new role workspaces are backed by named collections', () {
      for (final resource in const [
        'placementTests',
        'placementAttempts',
        'placementProposals',
        'forms',
        'tasks',
        'cards',
        'cardTypes',
        'accessOverrides',
        'rooms',
        'scheduleRules',
        'meetingsUpcoming',
        'rulesMine',
        'rulesPending',
        'tasksMine',
        'achievementsMine',
        'rewardGrantsMine',
        'coverPool',
      ]) {
        expect(kApiResources, contains(resource), reason: resource);
      }
    });

    test('read-only collections reject invented generic mutations', () async {
      final session = ApiSession(client: _RecordingClient());
      addTearDown(session.dispose);

      await expectLater(
        session.create('payments', const {'amount': 1}),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        session.update('audit', 1, const {'status': 'changed'}),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        session.remove('accessPermissions', 1),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('mutation contracts', () {
    test(
      'published operation resolves path and preserves JSON payload',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client);
        addTearDown(session.dispose);
        final operation = kPublishedApiOperations.singleWhere(
          (item) =>
              item.method == 'POST' &&
              item.path == '/api/v1/cards/wallets/{student_id}/topup/',
        );

        await session.executePublishedOperation(
          operation,
          pathParameters: const {'student_id': 'student 7'},
          body: const {'amount': 125000},
        );

        expect(client.calls.single.method, 'POST');
        expect(
          client.calls.single.path,
          '/api/v1/cards/wallets/student%207/topup/',
        );
        expect(client.calls.single.body, {'amount': 125000});
      },
    );

    test(
      'resource actions use the exact published path and JSON body',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        await session.resourceAction(
          'payments',
          42,
          'refund',
          body: const {'amount': 25000, 'reason': 'duplicate'},
        );

        expect(client.calls.single.method, 'POST');
        expect(client.calls.single.path, '/api/v1/payments/42/refund/');
        expect(client.calls.single.body, {
          'amount': 25000,
          'reason': 'duplicate',
        });
      },
    );

    test('body-required command receives an empty JSON object', () async {
      final client = _RecordingClient();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      await session.action('POST', '/api/v1/notifications/read-all/');

      expect(client.calls.single.body, const <String, Object?>{});
    });

    test(
      'successful mutation is not reported failed when refresh fails',
      () async {
        final client = _RecordingClient()..failRefresh = true;
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        final result = await session.action(
          'POST',
          '/api/v1/approvals/requests/7/approve/',
          refreshResources: const ['approvals'],
        );

        expect(result, isA<Map<String, dynamic>>());
        expect(session.lastError, contains('Action completed'));
      },
    );

    test('thread message uses the published nested endpoint', () async {
      final client = _RecordingClient();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      await session.sendThreadMessage(9, 'Salom');

      expect(client.calls.single.path, '/api/v1/messaging/threads/9/messages/');
      expect(client.calls.single.body, {
        'body': 'Salom',
        'attachments': <String>[],
      });
    });

    test('thread read marker uses the published nested endpoint', () async {
      final client = _RecordingClient();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      await session.markThreadRead('9');

      expect(client.calls.single.method, 'POST');
      expect(client.calls.single.path, '/api/v1/messaging/threads/9/read/');
      expect(client.calls.single.body, <String, Object?>{});
    });

    test(
      'new direct thread sends its first message through messages API',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        await session.createMessageThread(
          participantIds: const [42],
          subject: 'Student account',
          firstBody: 'Hello from the real chat',
        );

        expect(client.calls, hasLength(2));
        expect(client.calls.first.method, 'POST');
        expect(client.calls.first.path, '/api/v1/messaging/threads/');
        expect(client.calls.first.body, {
          'participant_ids': [42],
          'subject': 'Student account',
        });
        expect(client.calls.last.path, '/api/v1/messaging/threads/1/messages/');
        expect(client.calls.last.body, {
          'body': 'Hello from the real chat',
          'attachments': <String>[],
        });
      },
    );

    test(
      'messaging bootstrap never probes unpublished contacts route',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client)
          ..me = {
            'id': 17,
            'permissions': ['messaging:read'],
          };
        addTearDown(session.dispose);

        await session.reloadAll();

        expect(client.listCalls, contains('/api/v1/messaging/threads/'));
        expect(
          client.listCalls,
          isNot(contains('/api/v1/messaging/contacts/')),
        );
        expect(session.messagingSelfUserId, 17);
      },
    );

    test(
      'absolute attachment URLs need no unpublished download endpoint',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        final url = await session.messageAttachmentDownloadUrl(
          9,
          'https://cdn.example.test/chat/photo.jpg',
        );

        expect(url, 'https://cdn.example.test/chat/photo.jpg');
        expect(client.calls, isEmpty);
      },
    );

    test(
      'teacher payroll uses payout-policy and prepare-salary endpoints',
      () async {
        final client = _RecordingClient();
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        await session.teacherPayoutPolicy(17);
        await session.saveTeacherPayoutPolicy(17, const {
          'salary_type': 'monthly',
          'base_amount': 6500000,
        });
        await session.resourceAction('teachers', 17, 'prepare-salary');

        expect(client.calls.map((call) => '${call.method} ${call.path}'), [
          'GET /api/v1/teachers/17/payout-policy/',
          'PUT /api/v1/teachers/17/payout-policy/',
          'POST /api/v1/teachers/17/prepare-salary/',
        ]);
        expect(client.calls[1].body, {
          'salary_type': 'monthly',
          'base_amount': 6500000,
        });
        expect(client.calls[2].body, <String, Object?>{});
      },
    );
  });

  group('authentication and permissions', () {
    test(
      'password lifecycle uses the three published auth endpoints',
      () async {
        final client = _RecordingClient();

        await client.requestPasswordReset('+998901234567');
        await client.confirmPasswordReset(
          phone: '+998901234567',
          code: '246810',
          newPassword: 'new-secret',
        );
        await client.changePassword(
          currentPassword: 'old-secret',
          newPassword: 'new-secret',
        );

        expect(client.calls.map((call) => '${call.method} ${call.path}'), [
          'POST /api/v1/auth/password/reset/request/',
          'POST /api/v1/auth/password/reset/confirm/',
          'POST /api/v1/auth/password/change/',
        ]);
        expect(client.calls[0].body, {'phone': '+998901234567'});
        expect(client.calls[1].body, {
          'phone': '+998901234567',
          'code': '246810',
          'new_password': 'new-secret',
        });
        expect(client.calls[2].body, {
          'old_password': 'old-secret',
          'new_password': 'new-secret',
        });
      },
    );

    test('401 callback clears live data and bearer session', () {
      final client = _RecordingClient();
      final session = ApiSession(client: client)
        ..collections['payments'] = [
          {'id': 1},
        ]
        ..me = {'id': 3, 'role': 'manager'};
      addTearDown(session.dispose);

      client.clearSession();
      client.onUnauthorized?.call();

      expect(session.authenticated, isFalse);
      expect(session.collections, isEmpty);
      expect(session.me, isNull);
      expect(session.lastError, contains('Session expired'));
    });

    test('published permissions support exact and namespace grants', () {
      final session = ApiSession()
        ..me = {
          'role': 'manager',
          'permissions': [
            'payments:read',
            {'code': 'schedule:*'},
          ],
        };
      addTearDown(session.dispose);

      expect(session.hasPermission('payments:read'), isTrue);
      expect(session.hasPermission('schedule:write'), isTrue);
      expect(session.hasPermission('audit:read'), isFalse);
    });

    test('AI never POSTs to the read-only request history endpoint', () async {
      final client = _RecordingClient();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      await expectLater(
        session.requestAi('Analyze'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'ai_prompt_endpoint_not_published',
          ),
        ),
      );
      expect(client.calls, isEmpty);
    });
  });
}
