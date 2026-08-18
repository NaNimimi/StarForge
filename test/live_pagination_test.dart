import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/settings.dart';
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

Widget _host(ApiSession session, Widget child) => SettingsScope(
  settings: AppSettings(),
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

Widget _notificationHost(
  ApiSession session,
  AppStore store,
  Widget child, {
  AppSettings? settings,
}) => SettingsScope(
  settings: settings ?? AppSettings(),
  child: AppScope(
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

  testWidgets(
    'live collection shows all data without pagination and searches',
    (tester) async {
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
      expect(
        find.byKey(const ValueKey('pagination-parents-next')),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField).first, 'Parent 45');
      await tester.pumpAndSettle();

      // One match is the query inside EditableText and one is the result card.
      expect(find.text('Parent 45'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('pagination-parents-previous')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('live API collections keep product cards and business copy', (
    tester,
  ) async {
    _surface(tester);
    tester.view.physicalSize = const Size(430, 1600);
    final cases =
        <
          ({
            String resource,
            String title,
            IconData icon,
            Map<String, dynamic> record,
            List<String> visibleFacts,
          })
        >[
          (
            resource: 'branches',
            title: 'Филиалы',
            icon: Icons.apartment_rounded,
            record: const {
              'id': 101,
              'name': 'API Chilonzor',
              'address': 'Bunyodkor 21',
              'phone': '+998712000002',
              'max_students': 180,
              'is_active': true,
            },
            visibleFacts: const [
              'API Chilonzor',
              'Bunyodkor 21',
              '+998712000002',
            ],
          ),
          (
            resource: 'groups',
            title: 'Группы',
            icon: Icons.workspaces_rounded,
            record: const {
              'id': 102,
              'name': 'API IELTS Evening',
              'teacher_name': 'Dilshod Karimov',
              'branch_name': 'Yunusobod',
              'student_count': 14,
              'status': 'active',
            },
            visibleFacts: const [
              'API IELTS Evening',
              'Dilshod Karimov',
              'Yunusobod',
            ],
          ),
          (
            resource: 'parents',
            title: 'Родители',
            icon: Icons.family_restroom_rounded,
            record: const {
              'id': 103,
              'full_name': 'API Parent Unique',
              'child_name': 'API Child Unique',
              'teacher_name': 'API Teacher Unique',
              'education_started': '2026-01-10',
              'last_call_at': '2026-07-20',
            },
            visibleFacts: const [
              'API Parent Unique',
              'API Child Unique',
              'API Teacher Unique',
              '2026-01-10',
            ],
          ),
          (
            resource: 'departments',
            title: 'Департаменты',
            icon: Icons.account_tree_rounded,
            record: const {
              'id': 104,
              'name': 'API Sales Department',
              'branch_name': 'Sergeli',
              'manager_name': 'API Head Unique',
              'responsible_name': 'API Owner Unique',
              'status': 'active',
            },
            visibleFacts: const [
              'API Sales Department',
              'Sergeli',
              'API Head Unique',
              'API Owner Unique',
            ],
          ),
          (
            resource: 'studentRisk',
            title: 'Риски',
            icon: Icons.warning_amber_rounded,
            record: const {
              'id': 105,
              'student_name': 'API Risk Student',
              'risk_level': 'high',
              'reason': 'Attendance below target',
              'group_name': 'API Group Risk',
            },
            visibleFacts: const [
              'API Risk Student',
              'Attendance below target',
              'API Group Risk',
            ],
          ),
          (
            resource: 'audit',
            title: 'Аудит',
            icon: Icons.policy_outlined,
            record: const {
              'id': 106,
              'action': 'payment.approved',
              'actor_name': 'API Auditor Unique',
              'entity_type': 'payment',
              'created_at': '2026-07-31T10:00:00Z',
            },
            visibleFacts: const [
              'payment.approved',
              'API Auditor Unique',
              'payment',
            ],
          ),
        ];

    for (final item in cases) {
      final client = _PagingClient(records: [item.record]);
      final session = ApiSession(client: client)
        ..collections[item.resource] = [item.record];
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _host(
          session,
          LiveCollectionPage(
            resource: item.resource,
            title: item.title,
            icon: item.icon,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: item.resource);
      expect(
        session.records(item.resource).single['id'],
        item.record['id'],
        reason: 'API cache ${item.resource}',
      );
      final cardFinder = find.byKey(
        ValueKey('live-${item.resource}-${item.record['id']}'),
      );
      await tester.scrollUntilVisible(
        cardFinder,
        280,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final cardTexts = tester
          .widgetList<Text>(
            find.descendant(of: cardFinder, matching: find.byType(Text)),
          )
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      for (final fact in item.visibleFacts) {
        expect(cardTexts, contains(fact), reason: item.resource);
      }
      expect(find.textContaining('LIVE API'), findsNothing);
      expect(find.textContaining(' fields'), findsNothing);
      expect(cardFinder, findsOneWidget);
    }
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

    await tester.tap(find.text('Tarix'));
    await tester.pumpAndSettle();
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('Old message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification cards localize nested server data and time', (
    tester,
  ) async {
    _surface(tester);
    final client = _NotificationClient();
    client.records
      ..clear()
      ..add({
        'id': 'notification-nested-1',
        'event_type': 'payment.received',
        'is_read': false,
        'data': {
          'title': 'Оплата получена',
          'body': 'Платёж ученика успешно принят',
          'created_at': DateTime.now()
              .subtract(const Duration(minutes: 2))
              .toUtc()
              .toIso8601String(),
        },
      });
    final session = ApiSession(client: client);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _notificationHost(
        session,
        store,
        const LiveNotificationsPage(),
        settings: AppSettings(lang: SfLang.ru),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оплата получена'), findsOneWidget);
    expect(find.text('Платёж ученика успешно принят'), findsOneWidget);
    expect(find.text('ПЛАТЁЖ'), findsOneWidget);
    expect(find.textContaining('мин назад'), findsOneWidget);
    expect(find.textContaining('payment.received'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'own notification feed loads without an admin permission code',
    () async {
      final client = _NotificationClient();
      final session = ApiSession(client: client)
        ..me = {'permission_codes': <String>[]};
      addTearDown(session.dispose);

      await session.reloadAll();

      expect(session.records('notifications'), hasLength(2));
      expect(session.document('unreadNotifications'), {'count': 1});
    },
  );

  testWidgets('informational notification marks read without empty detail', (
    tester,
  ) async {
    _surface(tester);
    final client = _NotificationClient();
    client.records
      ..clear()
      ..add({
        'id': 'notification-info-1',
        'event_type': 'system.info',
        'title': 'Database notice',
        'body': 'No destination was published',
        'data': const <String, dynamic>{},
        'read_at': null,
      });
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

    await tester.tap(find.text('Database notice'));
    await tester.pumpAndSettle();

    expect(destination, isNull);
    expect(find.byType(LiveRecordDetailPage), findsNothing);
    expect(find.text('Database notice'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
