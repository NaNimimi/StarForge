import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingLogoutClient extends StarforgeApiClient {
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

  @override
  Future<void> logout() async {
    throw const ApiException(
      status: 503,
      message: 'Revoke unavailable',
      requestId: 'widget-logout-test',
    );
  }
}

Widget _host({
  required SfRole role,
  required ApiSession session,
  AppSettings? settings,
  VoidCallback? onSwitchRole,
}) {
  final appSettings = settings ?? AppSettings(lang: SfLang.ru);
  return SettingsScope(
    settings: appSettings,
    child: ApiScope(
      session: session,
      child: AppScope(
        store: AppStore.seed(role),
        child: MaterialApp(
          theme: sfMaterialTheme(appSettings.colors, dark: appSettings.dark),
          home: Console(
            cfg: kRoleConfigs[role]!,
            onSwitchRole: onSwitchRole ?? () {},
          ),
        ),
      ),
    ),
  );
}

void _surface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _phone(WidgetTester tester) => _surface(tester, const Size(390, 844));

Future<Finder> _openDrawer(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('console-open-navigation')).hitTestable(),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 420));
  return find.byKey(const ValueKey('console-navigation-drawer'));
}

void main() {
  for (final size in const [Size(320, 760), Size(390, 844)]) {
    testWidgets(
      'navigation opener is a left-side handle outside bottom tabs at ${size.width}px',
      (tester) async {
        _surface(tester, size);
        final session = ApiSession();
        addTearDown(session.dispose);
        await tester.pumpWidget(_host(role: SfRole.ceo, session: session));
        await tester.pumpAndSettle();

        final opener = find
            .byKey(const ValueKey('console-open-navigation'))
            .hitTestable();
        final bottomNavigation = find.byKey(
          const ValueKey('console-bottom-navigation'),
        );
        expect(opener, findsOneWidget);
        expect(bottomNavigation, findsOneWidget);

        final openerRect = tester.getRect(opener);
        final bottomRect = tester.getRect(bottomNavigation);
        expect(openerRect.left, 6);
        expect(openerRect.width, 32);
        expect(openerRect.height, 34);
        expect(openerRect.top, greaterThan(0));
        expect(openerRect.top, lessThan(size.height * .15));
        expect(openerRect.bottom, lessThan(bottomRect.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('840px keeps persistent sidebar without mobile opener', (
    tester,
  ) async {
    _surface(tester, const Size(840, 900));
    final session = ApiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_host(role: SfRole.ceo, session: session));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('console-navigation-persistent')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('console-open-navigation')), findsNothing);
    expect(
      find.byKey(const ValueKey('console-bottom-navigation')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI history and global navigation buttons do not overlap', (
    tester,
  ) async {
    _phone(tester);
    final session = ApiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_host(role: SfRole.ceo, session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).last);
    await tester.pumpAndSettle();

    final navigation = find
        .byKey(const ValueKey('console-open-navigation'))
        .hitTestable();
    final history = find.byTooltip('Suhbatlar tarixi').hitTestable();
    expect(navigation, findsOneWidget);
    expect(history, findsOneWidget);
    expect(
      tester.getRect(navigation).overlaps(tester.getRect(history)),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact CEO navigation opens from the left and searches routes',
    (tester) async {
      _phone(tester);
      final session = ApiSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(_host(role: SfRole.ceo, session: session));
      await tester.pumpAndSettle();

      final drawer = await _openDrawer(tester);
      expect(drawer, findsOneWidget);
      expect(
        find.descendant(of: drawer, matching: find.text('Сравнение филиалов')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.byKey(const ValueKey('sidebar-section-search')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.byKey(const ValueKey('sidebar-profile')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.byKey(const ValueKey('sidebar-settings')),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('sidebar-section-search')),
        'сравнение',
      );
      await tester.pump();
      expect(
        find.descendant(of: drawer, matching: find.text('Сравнение филиалов')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.text('Ученики')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('sidebar-section-search')),
        'несуществующий-раздел',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sidebar-search-empty')),
        findsOneWidget,
      );
      expect(find.text('Раздел не найден'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('drawer exposes only sections allowed for each role', (
    tester,
  ) async {
    _phone(tester);

    final managerSession = ApiSession();
    await tester.pumpWidget(
      _host(role: SfRole.manager, session: managerSession),
    );
    await tester.pump(const Duration(milliseconds: 900));
    var drawer = await _openDrawer(tester);
    await tester.enterText(
      find.byKey(const ValueKey('sidebar-section-search')),
      'approvals',
    );
    await tester.pump();
    expect(
      find.descendant(of: drawer, matching: find.text('Подтверждение')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Сравнение филиалов')),
      findsNothing,
    );

    final auditSession = ApiSession();
    await tester.pumpWidget(_host(role: SfRole.audit, session: auditSession));
    managerSession.dispose();
    await tester.pumpAndSettle();
    drawer = await _openDrawer(tester);
    await tester.enterText(
      find.byKey(const ValueKey('sidebar-section-search')),
      'fairness',
    );
    await tester.pump();
    expect(
      find.descendant(of: drawer, matching: find.text('Справедливость карт')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Ученики')),
      findsNothing,
    );
    auditSession.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile contains settings but no duplicate section hubs', (
    tester,
  ) async {
    _phone(tester);
    final session = ApiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_host(role: SfRole.ceo, session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Все разделы'), findsNothing);
    expect(find.text('Все модули'), findsNothing);
    expect(find.text('Настройки приложения'), findsOneWidget);
    expect(find.text('История активности'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.textContaining('фото', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    expect(find.text('Сменить роль'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.text('StarForge EDU · v$kAppDisplayVersion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile account destinations open inside the role shell', (
    tester,
  ) async {
    _phone(tester);
    final session = ApiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(_host(role: SfRole.manager, session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки приложения'));
    await tester.pumpAndSettle();

    expect(find.text('Настройка вида'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
    expect(find.textContaining('роли для менеджера'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live drawer uses backend scope and logout clears session', (
    tester,
  ) async {
    _phone(tester);
    var switched = false;
    final client = _FailingLogoutClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..me = {'branch_name': 'Chilonzor'};
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _host(
        role: SfRole.ceo,
        session: session,
        onSwitchRole: () => switched = true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final drawer = await _openDrawer(tester);
    expect(
      find.descendant(of: drawer, matching: find.text('Chilonzor')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: drawer,
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sidebar-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('Сменить роль'), findsNothing);
    expect(find.text('Выйти'), findsOneWidget);

    await tester.ensureVisible(find.text('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(switched, isTrue);
    expect(session.authenticated, isFalse);
    expect(session.me, isNull);
    expect(tester.takeException(), isNull);
  });
}
