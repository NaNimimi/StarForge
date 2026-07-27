import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _dashboardHost(AppStore store) => SettingsScope(
  settings: AppSettings(),
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
}
