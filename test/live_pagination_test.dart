import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagingClient extends StarforgeApiClient {
  _PagingClient({this.records = const []});

  final List<Map<String, dynamic>> records;
  Map<String, Object?>? lastQuery;
  String? lastMethod;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastMethod = method;
    lastQuery = query;
    final page = int.tryParse('${query?['page']}') ?? 1;
    final size = int.tryParse('${query?['page_size']}') ?? 25;
    final start = ((page - 1) * size).clamp(0, records.length);
    final end = (start + size).clamp(0, records.length);
    return {
      'count': records.length,
      'next': end < records.length
          ? 'https://api.test/items?page=${page + 1}'
          : null,
      'previous': page > 1 ? 'https://api.test/items?page=${page - 1}' : null,
      'results': records.sublist(start, end),
    };
  }
}

class _ForbiddenClient extends StarforgeApiClient {
  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    throw const ApiException(
      status: 403,
      message: 'Forbidden',
      requestId: 'permission-test',
    );
  }
}

class _NotificationClient extends StarforgeApiClient {
  _NotificationClient()
    : records = [
        {
          'id': 'notification-payment-1',
          'type': 'payment',
          'title': 'Payment received',
          'message': 'Student payment was accepted',
          'is_read': false,
        },
        {
          'id': 'notification-history-1',
          'type': 'message',
          'title': 'Old message',
          'message': 'Already reviewed',
          'is_read': true,
        },
      ] {
    configure(token: 'test-token');
  }

  final List<Map<String, dynamic>> records;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (method == 'POST' && path.contains('/notifications/')) {
      final id = path.split('/').where((part) => part.isNotEmpty).elementAt(3);
      for (final record in records) {
        if (record['id'] == id) record['is_read'] = true;
      }
      return const <String, dynamic>{};
    }
    if (path == '/api/v1/notifications/unread-count/') {
      return {
        'count': records.where((record) => record['is_read'] != true).length,
      };
    }
    if (path == '/api/v1/notifications/') {
      return {'count': records.length, 'results': records};
    }
    return const <String, dynamic>{};
  }
}

Widget _host(ApiSession session, Widget child) => ApiScope(
  session: session,
  child: MaterialApp(
    theme: sfMaterialTheme(SfColors.light, dark: false),
    home: SfTheme(
      colors: SfColors.light,
      child: Scaffold(body: child),
    ),
  ),
);

Widget _notificationHost(ApiSession session, AppStore store, Widget child) =>
    AppScope(
      store: store,
      child: ApiScope(
        session: session,
        child: MaterialApp(
          theme: sfMaterialTheme(SfColors.light, dark: false),
          home: SfTheme(
            colors: SfColors.light,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );

void _surface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test('ApiPage normalizes StarForge and conventional paging metadata', () {
    const starforge = ApiPage(
      items: [
        {'_': 1},
      ],
      pagination: {
        'current_page': 2,
        'per_page': 20,
        'total_count': 45,
        'total_pages': 3,
        'has_prev': true,
      },
    );

    expect(starforge.page, 2);
    expect(starforge.pageSize, 20);
    expect(starforge.total, 45);
    expect(starforge.pages, 3);
    expect(starforge.hasPrevious, isTrue);
    expect(starforge.hasNext, isTrue);
  });

  test('listPage requests one real backend page and preserves count', () async {
    final client = _PagingClient(
      records: [
        for (var index = 1; index <= 5; index++)
          {'id': index, 'name': 'Record $index'},
      ],
    );

    final result = await client.listPage(
      '/api/v1/students/',
      page: 2,
      pageSize: 2,
    );

    expect(client.lastMethod, 'GET');
    expect(client.lastQuery, containsPair('page', 2));
    expect(client.lastQuery, containsPair('page_size', 2));
    expect(result.items.map((row) => row['id']), [3, 4]);
    expect(result.page, 2);
    expect(result.pageSize, 2);
    expect(result.total, 5);
    expect(result.pages, 3);
    expect(result.hasPrevious, isTrue);
    expect(result.hasNext, isTrue);
  });

  test('session exposes backend total with a cache-length fallback', () {
    final session = ApiSession()
      ..collections['students'] = [
        {'id': 1},
        {'id': 2},
      ]
      ..collectionPagination['students'] = {
        'page': 1,
        'page_size': 2,
        'total': 47,
      }
      ..collections['teachers'] = [
        {'id': 1},
      ];
    addTearDown(session.dispose);

    expect(session.totalFor('students'), 47);
    expect(session.paginationFor('students')?['page_size'], 2);
    expect(session.totalFor('teachers'), 1);
  });

  test(
    'session retains permission errors instead of presenting empty data',
    () async {
      final session = ApiSession(client: _ForbiddenClient());
      addTearDown(session.dispose);

      await expectLater(
        session.refresh('students'),
        throwsA(isA<ApiException>()),
      );

      expect(session.resourceError('students')?.status, 403);
    },
  );

  testWidgets('live collection paginates and search resets to first page', (
    tester,
  ) async {
    _surface(tester);
    final records = [
      for (var index = 1; index <= 45; index++)
        {'full_name': 'Parent $index', 'id': index, 'status': 'active'},
    ];
    final session = ApiSession(client: _PagingClient(records: records))
      ..collections['parents'] = records;
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(
        session,
        const LiveCollectionPage(
          resource: 'parents',
          title: 'Ota-onalar',
          icon: Icons.family_restroom_rounded,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parent 1'), findsOneWidget);
    expect(find.text('Parent 21'), findsNothing);
    final next = find.byKey(const ValueKey('pagination-parents-next'));
    final list = find.byType(ListView);
    for (var attempt = 0; attempt < 30 && next.evaluate().isEmpty; attempt++) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
    }
    expect(next, findsOneWidget);
    expect(tester.getSize(next), const Size(44, 44));

    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 10000));
    await tester.pumpAndSettle();
    expect(find.text('Parent 21'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Parent 45');
    await tester.pumpAndSettle();

    // One match is the query inside EditableText and one is the result card.
    expect(find.text('Parent 45'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('pagination-parents-previous')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live notification opens payment route and leaves new list', (
    tester,
  ) async {
    _surface(tester);
    final client = _NotificationClient();
    final session = ApiSession(client: client);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(session.dispose);
    addTearDown(store.dispose);
    String? destination;

    await tester.pumpWidget(
      _notificationHost(
        session,
        store,
        LiveNotificationsPage(onNavigate: (route) => destination = route),
      ),
    );
    await tester.pumpAndSettle();

    expect(session.records('notifications'), hasLength(2));
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('Old message'), findsNothing);
    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();

    expect(destination, 'payments');
    expect(find.text('Payment received'), findsNothing);
    expect(find.textContaining('Yangi bildirishnoma yo‘q'), findsOneWidget);

    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('Old message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
