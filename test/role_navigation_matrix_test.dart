import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/i18n.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoNetworkClient extends StarforgeApiClient {
  _NoNetworkClient({bool authenticated = false}) {
    configure(
      baseUrl: 'https://api.test',
      token: authenticated ? 'test-session' : null,
    );
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
    if (path.contains('unread-count')) return {'count': 0};
    return const <String, dynamic>{
      'count': 0,
      'next': null,
      'previous': null,
      'results': <Map<String, dynamic>>[],
    };
  }
}

void _surface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _host(SfRole role, {bool authenticated = false, ApiSession? session}) {
  final settings = AppSettings(dark: role == SfRole.audit);
  final api =
      session ??
      ApiSession(client: _NoNetworkClient(authenticated: authenticated));
  if (authenticated) {
    api.me = {
      'id': '${role.name}-user',
      'full_name': kRoleConfigs[role]!.who,
      'role': role.name,
    };
  }
  return ApiScope(
    session: api,
    child: SettingsScope(
      settings: settings,
      child: AppScope(
        store: AppStore.seed(role),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sfMaterialTheme(settings.colors, dark: settings.dark),
          home: Console(cfg: kRoleConfigs[role]!, onSwitchRole: () {}),
        ),
      ),
    ),
  );
}

List<MenuItem> _itemsFor(SfRole role) => [
  for (final group in menuFor(role)) ...group.items,
];

Future<void> _pumpConsole(
  WidgetTester tester,
  SfRole role,
  Size size, {
  bool authenticated = false,
}) async {
  _surface(tester, size);
  await tester.pumpWidget(_host(role, authenticated: authenticated));
  await tester.pump(const Duration(milliseconds: 900));
  expect(
    tester.takeException(),
    isNull,
    reason: '${role.name} Console must render at ${size.width}px',
  );
}

Future<void> _openNavigation(
  WidgetTester tester, {
  required bool compact,
}) async {
  final search = find.byKey(const ValueKey('sidebar-section-search'));
  if (compact) {
    final opener = find
        .byKey(const ValueKey('console-open-navigation'))
        .hitTestable();
    expect(opener, findsOneWidget);
    await tester.tap(opener);
    // The off-canvas sidebar uses RefMotion.emphasized (360 ms). Pump past
    // the complete transition so hit testing is deterministic at 320 px.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
  }
  expect(search.hitTestable(), findsOneWidget);
}

Future<void> _openMenuItem(
  WidgetTester tester,
  MenuItem item, {
  required bool compact,
}) async {
  await _openNavigation(tester, compact: compact);
  final search = find.byKey(const ValueKey('sidebar-section-search'));
  await tester.enterText(search, item.id);
  await tester.pump();

  final label = menuLabel(tester.element(search), item.label);
  final target = find.byTooltip(label).hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'Sidebar route ${item.id} ($label) must be discoverable',
  );
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 420));
  expect(
    tester.takeException(),
    isNull,
    reason: 'Sidebar route ${item.id} must render without an exception',
  );
  if (compact) {
    expect(
      search.hitTestable(),
      findsNothing,
      reason: 'Selecting ${item.id} must close the mobile drawer',
    );
  }
}

void main() {
  const phone = Size(320, 760);
  const expanded = Size(840, 900);

  group('role permission matrix', () {
    test('CEO includes every manager business destination', () {
      final ceo = navigationRoutesFor(SfRole.ceo);
      final manager = navigationRoutesFor(SfRole.manager);

      expect(ceo, containsAll(manager));
      expect(
        ceo,
        containsAll(const {'leads', 'enroll', 'approvals', 'schedule'}),
      );
    });

    test('manager cannot discover executive, RBAC or audit destinations', () {
      final routes = navigationRoutesFor(SfRole.manager);

      expect(
        routes.intersection(const {
          'branches',
          'comparison',
          'history',
          'report',
        }),
        isEmpty,
      );
      expect(routes, isNot(contains('permissions')));
      expect(
        routes.intersection(const {
          'anomalies',
          'fairness',
          'finance',
          'logs',
          'aiusage',
          'surveys',
          'cases',
        }),
        isEmpty,
      );
      expect(
        buildAdminPage('permissions', SfColors.light, SfRole.manager),
        isNull,
      );
    });

    test('audit has only audit, communication and system destinations', () {
      final routes = navigationRoutesFor(SfRole.audit);

      expect(
        routes,
        equals({
          'dash',
          'tools',
          'anomalies',
          'fairness',
          'finance',
          'logs',
          'aiusage',
          'surveys',
          'messages',
          'cases',
          'notifications',
          'settings',
          'me',
          'account_preferences',
          'account_activity',
          'privacy',
          'security',
        }),
      );
      expect(buildAdminPage('students', SfColors.dark, SfRole.audit), isNull);
      expect(buildAdminPage('payments', SfColors.dark, SfRole.audit), isNull);
      expect(
        buildAdminPage('permissions', SfColors.dark, SfRole.audit),
        isNull,
      );
    });

    test('all role tabs are allowed and menu ids are unique', () {
      for (final role in SfRole.values) {
        final routes = navigationRoutesFor(role);
        final items = _itemsFor(role);
        final ids = items.map((item) => item.id).toList(growable: false);

        expect(ids.toSet().length, ids.length, reason: role.name);
        expect(
          kRoleConfigs[role]!.tabs.map((tab) => tab.id),
          everyElement(isIn(routes)),
          reason: '${role.name} tabs must pass the route guard',
        );
        expect(
          items.map((item) => item.badge),
          everyElement(isNull),
          reason: '${role.name} must not expose seeded unread counts',
        );
      }
    });

    test('student exposes self-service routes only', () {
      expect(
        navigationRoutesFor(SfRole.student),
        equals({
          'dash',
          'student_report',
          'messages',
          'notifications',
          'settings',
          'me',
          'account_preferences',
          'account_activity',
          'privacy',
          'security',
        }),
      );
      for (final forbidden in const [
        'branches',
        'comparison',
        'students',
        'groups',
        'teachers',
        'payments',
        'permissions',
        'audit',
      ]) {
        expect(roleCanNavigate(SfRole.student, forbidden), isFalse);
        expect(
          buildAdminPage(forbidden, SfColors.light, SfRole.student),
          isNull,
        );
      }
    });
  });

  testWidgets(
    'audit messages tab opens read-only oversight with an empty permission list',
    (tester) async {
      final session = ApiSession(client: _NoNetworkClient(authenticated: true))
        ..me = const {
          'id': 31,
          'username': 'audit.user',
          'role': 'audit',
          'permissions': <String>[],
        }
        ..collections['threads'] = const <Map<String, dynamic>>[];
      addTearDown(session.dispose);
      _surface(tester, phone);
      await tester.pumpWidget(_host(SfRole.audit, session: session));
      await tester.pump(const Duration(milliseconds: 300));

      final chatTab = find
          .descendant(
            of: find.byKey(const ValueKey('console-bottom-navigation')),
            matching: find.byIcon(Icons.chat_bubble_rounded),
          )
          .hitTestable();
      expect(chatTab, findsOneWidget);
      await tester.tap(chatTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Audit rejimi'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-send-action')), findsNothing);
      expect(find.byKey(const ValueKey('chat-voice-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in SfRole.values) {
    testWidgets(
      '${role.name}: mobile drawer opens, searches, navigates and closes',
      (tester) async {
        await _pumpConsole(tester, role, phone);
        await _openNavigation(tester, compact: true);

        final search = find.byKey(const ValueKey('sidebar-section-search'));
        await tester.enterText(search, 'route-that-does-not-exist');
        await tester.pump();
        expect(
          find.byKey(const ValueKey('sidebar-search-empty')).hitTestable(),
          findsOneWidget,
        );

        final secondary = _itemsFor(
          role,
        ).firstWhere((item) => item.id != 'dash');
        await tester.enterText(search, secondary.id);
        await tester.pump();
        final label = menuLabel(tester.element(search), secondary.label);
        await tester.tap(find.byTooltip(label).hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 420));

        expect(search.hitTestable(), findsNothing);
        expect(
          find.byKey(const ValueKey('console-open-navigation')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final entry in const [
      (name: '320', size: phone, compact: true),
      (name: '840', size: expanded, compact: false),
    ]) {
      testWidgets(
        '${role.name}: every menu route renders at ${entry.name}px',
        (tester) async {
          await _pumpConsole(tester, role, entry.size);
          for (final item in _itemsFor(role)) {
            await _openMenuItem(tester, item, compact: entry.compact);
          }

          if (role == SfRole.audit) {
            final context = tester.element(find.byType(Console));
            expect(Theme.of(context).brightness, Brightness.dark);
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }

  final newlyConnectedRoutes = <SfRole, List<String>>{
    SfRole.ceo: ['payroll', 'leads', 'enroll', 'chats'],
    SfRole.manager: ['payroll', 'leads', 'enroll', 'chats'],
    SfRole.audit: ['fairness', 'surveys', 'cases'],
  };
  for (final entry in newlyConnectedRoutes.entries) {
    for (final route in entry.value) {
      testWidgets('${entry.key.name}: $route is connected in live mode', (
        tester,
      ) async {
        await _pumpConsole(tester, entry.key, phone, authenticated: true);
        final item = _itemsFor(
          entry.key,
        ).singleWhere((candidate) => candidate.id == route);
        await _openMenuItem(tester, item, compact: true);

        expect(find.text('Интеграция ещё не подключена'), findsNothing);
        expect(find.textContaining('LIVE API'), findsNothing);
        expect(find.textContaining('backend'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
