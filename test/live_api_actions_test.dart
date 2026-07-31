import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ActionClient extends StarforgeApiClient {
  _ActionClient() {
    configure(token: 'manager-session');
  }

  final calls = <({String method, String path, Object? body})>[];

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    if (path == '/api/v1/approvals/requests/') {
      return const ApiPage(
        items: [
          {'id': 7, 'title': 'Refund approval', 'status': 'pending'},
        ],
      );
    }
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
    calls.add((method: method, path: path, body: body));
    if (method == 'GET' && path == '/api/v1/org/branches/5/') {
      return const {
        'id': 5,
        'name': 'Chilonzor filiali',
        'slug': 'chilanzar',
        'address': 'Toshkent, Bunyodkor 21',
        'phone': '+998712000002',
        'timezone': 'Asia/Tashkent',
        'is_active': true,
        'max_students': 180,
        'max_teachers': 24,
        'created_at': '2026-07-31T15:36:31Z',
        'departments': [],
      };
    }
    if (method == 'GET' && path.endsWith('/7/')) {
      return {'id': 7, 'title': 'Refund approval', 'status': 'pending'};
    }
    return const <String, dynamic>{'success': true};
  }
}

Widget _host(ApiSession session, Widget child) {
  final settings = AppSettings();
  return ApiScope(
    session: session,
    child: SettingsScope(
      settings: settings,
      child: AppScope(
        store: AppStore.seed(SfRole.manager),
        child: MaterialApp(
          theme: sfMaterialTheme(SfColors.light, dark: false),
          home: SfTheme(colors: SfColors.light, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('branch edit uses typed fields and sends only writable DTO', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final client = _ActionClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(
        session,
        const Scaffold(
          body: LiveRecordDetailPage(
            resource: 'branches',
            initial: {
              'id': 5,
              'name': 'Chilonzor filiali',
              'slug': 'chilanzar',
              'address': 'Toshkent, Bunyodkor 21',
              'phone': '+998712000002',
              'timezone': 'Asia/Tashkent',
              'is_active': true,
              'max_students': 180,
              'max_teachers': 24,
              'created_at': '2026-07-31T15:36:31Z',
            },
            title: 'Filiallar',
            colors: SfColors.light,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();

    expect(find.text('JSON'), findsNothing);
    expect(find.textContaining('Схема публикует'), findsNothing);
    expect(find.byKey(const ValueKey('branch-edit-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-edit-address')), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-edit-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('branch-edit-status')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('branch-edit-name')),
      'Chilonzor Premium',
    );
    await tester.tap(find.byKey(const ValueKey('branch-edit-save')));
    await tester.pumpAndSettle();

    final call = client.calls.singleWhere(
      (call) =>
          call.method == 'PATCH' && call.path == '/api/v1/org/branches/5/',
    );
    final body = Map<String, dynamic>.from(call.body! as Map);
    expect(body['name'], 'Chilonzor Premium');
    expect(body['slug'], 'chilanzar');
    expect(body['max_students'], 180);
    expect(body, isNot(contains('id')));
    expect(body, isNot(contains('created_at')));
    expect(body, isNot(contains('departments')));
  });

  testWidgets('manager approval button calls published approve action', (
    tester,
  ) async {
    final client = _ActionClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(
        session,
        const Scaffold(
          body: LiveCollectionPage(
            resource: 'approvals',
            title: 'Tasdiqlar',
            icon: Icons.task_alt_rounded,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(session.records('approvals'), hasLength(1));
    await tester.tap(
      find.byKey(const ValueKey('live-approvals-7')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Одобрить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(
      client.calls.where(
        (call) =>
            call.method == 'POST' &&
            call.path == '/api/v1/approvals/requests/7/approve/',
      ),
      hasLength(1),
    );
  });

  testWidgets('manager cash payment dialog posts edited JSON payload', (
    tester,
  ) async {
    final client = _ActionClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(session, const Scaffold(body: LiveRevenueReportPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять оплату'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('live-cash-payment-json')),
      '{"student_id": 55, "amount": 120000, "payment_method_id": 2}',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Принять'));
    await tester.pumpAndSettle();

    final call = client.calls.singleWhere(
      (call) => call.method == 'POST' && call.path == '/api/v1/payments/cash/',
    );
    expect(call.body, {
      'student_id': 55,
      'amount': 120000,
      'payment_method_id': 2,
    });
  });

  testWidgets('manager attendance command uses published lesson endpoint', (
    tester,
  ) async {
    final client = _ActionClient();
    final session = ApiSession(client: client);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(session, const Scaffold(body: LiveAttendanceAnalyticsPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('live-attendance-mark')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '{"lesson_id": "lesson-14", "records": [{"student_id": 9, "status": "present"}]}',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    final call = client.calls.singleWhere(
      (call) =>
          call.method == 'POST' &&
          call.path == '/api/v1/attendance/lessons/lesson-14/mark/',
    );
    expect(call.body, {
      'records': [
        {'student_id': 9, 'status': 'present'},
      ],
    });
  });
}
