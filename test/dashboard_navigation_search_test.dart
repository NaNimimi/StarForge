import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DashboardClient extends StarforgeApiClient {
  _DashboardClient() {
    configure(baseUrl: 'https://api.test', token: 'dashboard-session');
  }
}

Widget _dashboardHost(
  AppStore store, {
  AppSettings? settings,
  ApiSession? session,
}) {
  final appSettings = settings ?? AppSettings();
  final content = SettingsScope(
    settings: appSettings,
    child: AppScope(
      store: store,
      child: MaterialApp(
        theme: sfMaterialTheme(SfColors.light, dark: false),
        home: SfTheme(
          colors: SfColors.light,
          child: Scaffold(
            body: DashboardScreen(cfg: kRoleConfigs[SfRole.ceo]!, go: (_) {}),
          ),
        ),
      ),
    ),
  );
  return session == null ? content : ApiScope(session: session, child: content);
}

Widget _consoleHost(AppStore store) => SettingsScope(
  settings: AppSettings(layout: 2),
  child: AppScope(
    store: store,
    child: MaterialApp(
      theme: sfMaterialTheme(SfColors.light, dark: false),
      home: Console(cfg: kRoleConfigs[SfRole.ceo]!, onSwitchRole: () {}),
    ),
  ),
);

void _surface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('tablet restores the full persistent left navigation', (
    tester,
  ) async {
    _surface(tester, const Size(840, 1000));
    await tester.pumpWidget(_consoleHost(AppStore.seed(SfRole.ceo)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Boshqaruv paneli'), findsOneWidget);
    expect(find.byTooltip('O‘quvchilar'), findsOneWidget);
    expect(find.byTooltip('Ish maydonini almashtirish'), findsNothing);
    expect(find.text('Panel'), findsNothing);
  });

  testWidgets('phone keeps compact bottom navigation', (tester) async {
    _surface(tester, const Size(320, 720));
    await tester.pumpWidget(_consoleHost(AppStore.seed(SfRole.ceo)));
    await tester.pumpAndSettle();

    expect(find.text('Panel'), findsOneWidget);
    expect(find.byTooltip('Boshqaruv paneli').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard global search filters real data and opens detail', (
    tester,
  ) async {
    _surface(tester, const Size(430, 900));
    final store = AppStore.seed(SfRole.ceo);
    final student = store.students.first;
    await tester.pumpWidget(_dashboardHost(store));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('dashboard-global-search'));
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();

    expect(find.text('TEZKOR BUYRUQLAR'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('dashboard-search-input')),
      'mavjud-emas-999',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dashboard-search-empty')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-search-clear')));
    await tester.pump();
    expect(find.text('TEZKOR BUYRUQLAR'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('dashboard-search-input')),
      student.name,
    );
    await tester.pump();
    expect(find.text('O‘QUVCHILAR'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('dashboard-search-result-students-${student.name}')),
    );
    await tester.pumpAndSettle();

    expect(find.text(student.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revenue period changes point count and displayed total', (
    tester,
  ) async {
    _surface(tester, const Size(430, 1000));
    await tester.pumpWidget(_dashboardHost(AppStore.seed(SfRole.ceo)));
    await tester.pumpAndSettle();

    final totalFinder = find.byKey(
      const ValueKey('dashboard-revenue-period-total'),
    );
    await tester.dragUntilVisible(
      totalFinder,
      find.byType(Scrollable).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    final total12 = tester.widget<Text>(totalFinder).data;
    final chartFinder = find.byType(LineChart).first;
    final chart12 = tester.widget<LineChart>(chartFinder);
    expect(chart12.data.lineBarsData.first.spots, hasLength(12));

    await tester.tapAt(tester.getTopRight(chartFinder) - const Offset(18, -45));
    await tester.pump();
    await tester.tap(find.text('6 oy').first);
    await tester.pumpAndSettle();

    final total6 = tester.widget<Text>(totalFinder).data;
    final chart6 = tester.widget<LineChart>(chartFinder);
    expect(total6, isNot(total12));
    expect(chart6.data.lineBarsData.first.spots, hasLength(6));
    expect(find.text('Tanlangan 6 oy jami'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'authenticated Russian dashboard hides Live control and keeps empty attendance still',
    (tester) async {
      _surface(tester, const Size(430, 1000));
      final session = ApiSession(client: _DashboardClient())
        ..me = const {'id': 1, 'role': 'ceo', 'full_name': 'CEO'};
      addTearDown(session.dispose);
      await tester.pumpWidget(
        _dashboardHost(
          AppStore.seed(SfRole.ceo),
          settings: AppSettings(lang: SfLang.ru),
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('LIVE'), findsNothing);
      expect(find.textContaining('Live'), findsNothing);
      expect(find.text('СЕГОДНЯ / ЦЕНТР УПРАВЛЕНИЯ'), findsOneWidget);

      final attendance = find.byKey(
        const ValueKey('dashboard-attendance-health'),
      );
      for (var index = 0; index < 8 && attendance.evaluate().isEmpty; index++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(attendance, findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('dashboard-attendance-progress')),
      );
      expect(progress.value, 0);
      expect(find.text('Данных о посещаемости пока нет'), findsOneWidget);
      expect(find.text('Рейтинг преподавателей'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live dashboard shows newest backend activity in plain language',
    (tester) async {
      _surface(tester, const Size(430, 1000));
      final store = AppStore.empty(SfRole.ceo)
        ..activities.addAll(const [
          ActivityEvent(
            icon: Icons.person_rounded,
            title: 'login',
            detail: 'ceo · users.User #10',
            time: '13:10',
            kind: 'users.User',
          ),
          ActivityEvent(
            icon: Icons.policy_outlined,
            title: 'update',
            detail: 'ceo · org.StaffProfile #10',
            time: '13:09',
            kind: 'org.StaffProfile',
          ),
        ]);
      final session = ApiSession(client: _DashboardClient())
        ..me = const {
          'id': 1,
          'role': 'ceo',
          'full_name': 'CEO',
          'permissions': ['audit:read'],
        };
      addTearDown(store.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _dashboardHost(
          store,
          settings: AppSettings(lang: SfLang.ru),
          session: session,
        ),
      );
      await tester.pump();

      final activity = find.byKey(const ValueKey('dashboard-recent-activity'));
      await tester.dragUntilVisible(
        activity,
        find.byType(Scrollable).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(activity, findsOneWidget);
      expect(find.text('Последние события'), findsOneWidget);
      expect(find.text('Из журнала backend'), findsOneWidget);
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.text('Данные изменены'), findsOneWidget);
      expect(find.text('ceo · users.User #10 · 13:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
