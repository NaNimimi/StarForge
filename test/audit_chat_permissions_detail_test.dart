import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuditMessagingClient extends StarforgeApiClient {
  _AuditMessagingClient() {
    configure(baseUrl: 'https://api.test', token: 'audit-session');
  }

  final List<(String, String)> calls = <(String, String)>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add((method, path));
    if (method == 'GET' && path == '/api/v1/messaging/threads/91/messages/') {
      return const {
        'data': [
          {
            'id': 501,
            'sender': 8,
            'body': 'Server-only transcript',
            'created_at': '2026-08-10T08:14:00Z',
          },
        ],
        'pagination': {
          'page': 1,
          'page_size': 100,
          'total': 1,
          'pages': 1,
          'has_next': false,
        },
      };
    }
    throw ApiException(
      status: 404,
      message: 'Unexpected test request: $method $path',
      requestId: 'audit-live-test',
    );
  }
}

void _usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 760);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _host(Widget child, {AppStore? store, ApiSession? session}) {
  final settings = AppSettings();
  final content = SettingsScope(
    settings: settings,
    child: AppScope(
      store: store ?? AppStore.seed(SfRole.ceo),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sfMaterialTheme(settings.colors, dark: false),
        home: SfTheme(colors: settings.colors, child: child),
      ),
    ),
  );
  return session == null ? content : ApiScope(session: session, child: content);
}

Future<void> _pumpPhone(
  WidgetTester tester,
  Widget child, {
  AppStore? store,
  ApiSession? session,
}) async {
  _usePhone(tester);
  await tester.pumpWidget(_host(child, store: store, session: session));
  await tester.pump(const Duration(milliseconds: 900));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'authenticated oversight renders only live API threads and stays read-only',
    (tester) async {
      final client = _AuditMessagingClient();
      final session = ApiSession(client: client)
        ..me = const {'id': 7, 'full_name': 'Audit Inspector', 'role': 'audit'}
        ..messagingSelfUserId = 7;
      final store = AppStore.empty(SfRole.audit)
        ..threads.add(
          ChatThread(
            const Thread(
              'Live Teacher',
              'API direct conversation',
              'Cached preview',
              '14:14',
              serverId: '91',
              participantIds: ['7', '8'],
            ),
            [ChatMsg('Cached preview', mine: false)],
          ),
        );
      addTearDown(session.dispose);
      addTearDown(store.dispose);

      await _pumpPhone(
        tester,
        ChatsAdminPage(colors: SfColors.light),
        store: store,
        session: session,
      );

      expect(
        find.byKey(const ValueKey('oversight-live-thread-91')),
        findsOneWidget,
      );
      expect(find.textContaining('Live ↔ Audit'), findsOneWidget);
      expect(find.textContaining('API direct conversation'), findsOneWidget);
      expect(find.textContaining('Nigora Karimova'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('oversight-live-thread-91')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Server-only transcript'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('oversight-read-only-banner')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.byKey(const ValueKey('chat-send-action')), findsNothing);
      expect(find.byKey(const ValueKey('chat-voice-action')), findsNothing);
      expect(find.byKey(const ValueKey('chat-attachment')), findsNothing);
      expect(
        find.byKey(const ValueKey('messages-new-conversation')),
        findsNothing,
      );
      expect(find.text('👍'), findsNothing);
      expect(
        client.calls,
        contains(('GET', '/api/v1/messaging/threads/91/messages/')),
      );
      expect(client.calls.every((call) => call.$1 == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared messages resolver keeps audit on oversight instead of writable chat',
    (tester) async {
      final page = buildAdminPage('messages', SfColors.light, SfRole.audit);
      expect(page, isNotNull);

      await _pumpPhone(tester, page!);

      expect(find.textContaining('Audit rejimi'), findsOneWidget);
      expect(find.textContaining('faqat o‘qish'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('messages-new-conversation')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('chat-send-action')), findsNothing);
      expect(find.byKey(const ValueKey('chat-voice-action')), findsNothing);
      expect(find.byKey(const ValueKey('chat-attachment')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'oversight row opens searchable read-only transcript with metadata at 320px',
    (tester) async {
      await _pumpPhone(tester, ChatsAdminPage(colors: SfColors.light));

      await tester.tap(
        find.byKey(const ValueKey('oversight-thread-0')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('oversight-chat-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('oversight-read-only-banner')),
        findsOneWidget,
      );
      expect(find.text('Метаданные разговора'), findsOneWidget);
      expect(find.text('Nigora Karimova'), findsWidgets);
      expect(find.text('Akbarova Dilnoza'), findsWidgets);
      expect(find.text('O‘quvchi · guruh'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);

      // The only editable control is transcript search: there is no composer,
      // send button or destructive message action on this oversight route.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.text('Изменить'), findsNothing);
      expect(find.text('Удалить'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('oversight-chat-search')),
        'nazorat',
      );
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget);
      expect(
        find.text('Ertaga nazorat ishi bo‘ladi. Daftarini olib kelsin.'),
        findsOneWidget,
      );
      expect(
        find.text('Rahmat, uyda ham mashqlarni davom ettiramiz.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permission detail mirrors role menu routes and scopes at 320px',
    (tester) async {
      await _pumpPhone(tester, PermissionsAdminPage(colors: SfColors.light));

      expect(find.byKey(const ValueKey('permission-role-ceo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('permission-role-manager')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('permission-role-audit')),
        findsOneWidget,
      );
      expect(find.text('Metodist'), findsNothing);
      expect(find.text('O‘qituvchi'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('permission-role-manager')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('permission-matrix-manager')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-payments')),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-payments')),
        findsOneWidget,
      );
      expect(
        navigationRoutesFor(SfRole.manager),
        isNot(contains('permissions')),
      );
      expect(navigationRoutesFor(SfRole.manager), isNot(contains('anomalies')));
      expect(find.textContaining('Просмотр операций'), findsOneWidget);
      expect(find.textContaining('Yunusobod'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-role-ceo')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-permissions')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-permissions')),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-role-audit')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-cases')),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-cases')),
        findsOneWidget,
      );
      expect(navigationRoutesFor(SfRole.audit), isNot(contains('payments')));
      expect(tester.takeException(), isNull);
    },
  );
}
