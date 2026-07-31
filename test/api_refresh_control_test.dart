import 'dart:async';

import 'package:ceo_manager/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _RefreshClient extends StarforgeApiClient {
  int calls = 0;
  Completer<ApiPage>? gate;
  ApiException? error;

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    final pending = gate;
    if (pending != null) return pending.future;
    return const ApiPage(
      items: [
        {'id': 1, 'name': 'Live student'},
      ],
    );
  }
}

void main() {
  test(
    'concurrent refreshes share one request and fresh data is reused',
    () async {
      final client = _RefreshClient()..gate = Completer<ApiPage>();
      final session = ApiSession(client: client);
      addTearDown(session.dispose);

      final first = session.refresh('students');
      final second = session.refresh('students');

      expect(client.calls, 1);
      client.gate!.complete(
        const ApiPage(
          items: [
            {'id': 7, 'name': 'Shared result'},
          ],
        ),
      );
      await Future.wait([first, second]);
      expect(session.records('students').single['id'], 7);

      await session.refresh('students');
      expect(client.calls, 1, reason: '30-second snapshots must not refetch');

      client.gate = null;
      await session.refresh('students', force: true);
      expect(
        client.calls,
        2,
        reason: 'explicit refresh bypasses freshness only',
      );
    },
  );

  test('429 cooldown prevents repeated resource requests', () async {
    final client = _RefreshClient()
      ..error = const ApiException(
        status: 429,
        code: 'throttled',
        message: 'Too many requests. Please slow down.',
        requestId: 'refresh-429',
        retryAfter: Duration(minutes: 1),
      );
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await expectLater(
      session.refresh('students'),
      throwsA(
        isA<ApiException>().having((error) => error.status, 'status', 429),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      session.refresh('students', force: true),
      throwsA(
        isA<ApiException>()
            .having((error) => error.status, 'status', 429)
            .having((error) => error.retryAfter, 'retryAfter', isNotNull),
      ),
    );

    expect(client.calls, 1, reason: 'cooldown must block the second HTTP call');
  });
}
