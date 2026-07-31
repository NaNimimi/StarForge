import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/reference_ui.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/web_mobile_pages.dart';
import 'package:ceo_manager/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppSettings settings, AppStore store, Widget child) =>
    SettingsScope(
      settings: settings,
      child: AppScope(
        store: store,
        child: MaterialApp(
          theme: sfMaterialTheme(SfColors.light, dark: false),
          home: SfTheme(colors: SfColors.light, child: child),
        ),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('shared donut selects a segment and centre resets the total', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SfTheme(
          colors: SfColors.light,
          child: Scaffold(
            body: Center(
              child: Donut(
                key: const ValueKey('test-donut'),
                size: 100,
                thickness: 18,
                segments: const [
                  DonutSegment(6, Colors.green, label: 'Good', display: '6'),
                  DonutSegment(4, Colors.orange, label: 'Risk', display: '4'),
                ],
                center: const Text('Total'),
              ),
            ),
          ),
        ),
      ),
    );

    final donut = find.byKey(const ValueKey('test-donut'));
    final center = tester.getCenter(donut);
    await tester.tapAt(center + const Offset(42, 0));
    await tester.pumpAndSettle();
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('6 · 60%'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Good'), findsNothing);
  });

  testWidgets('branch donut exposes localised segment details', (tester) async {
    _phone(tester);
    final settings = AppSettings(lang: SfLang.ru);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(
        settings,
        store,
        BranchWorkspaceScreen(branch: kBranches.first, colors: SfColors.light),
      ),
    );
    await tester.pumpAndSettle();

    final donut = find.byKey(const ValueKey('branch-attendance-donut'));
    await tester.scrollUntilVisible(
      donut,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final center = tester.getCenter(donut);
    await tester.tapAt(center + const Offset(38, 0));
    await tester.pumpAndSettle();
    expect(find.text('Хорошо'), findsOneWidget);
    expect(find.text('72%'), findsWidgets);

    settings.setLang(SfLang.en);
    await tester.pumpAndSettle();
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Attendance · group health'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student attendance graph selects a week and switches language', (
    tester,
  ) async {
    _phone(tester);
    final settings = AppSettings(lang: SfLang.ru);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(
        settings,
        store,
        StudentDetailScreen(
          student: store.students.first,
          colors: SfColors.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = find.byKey(const ValueKey('student-attendance-trend'));
    await tester.scrollUntilVisible(
      chart,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Неделя 8'), findsWidgets);

    final rect = tester.getRect(chart);
    await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('Неделя 1'), findsWidgets);

    settings.setLang(SfLang.en);
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 1'), findsWidgets);
    expect(find.text('ATTENDANCE'), findsWidgets);

    settings.setLang(SfLang.uz);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hafta 1'), findsWidgets);
    expect(find.text('DAVOMAT'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups and payments rebuild all primary labels with language', (
    tester,
  ) async {
    _phone(tester);
    final settings = AppSettings(lang: SfLang.ru);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(settings, store, const Scaffold(body: WebPaymentsPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Платежи'), findsOneWidget);
    expect(find.text('Способы оплаты'), findsOneWidget);
    expect(find.text('Поступления'), findsWidgets);

    settings.setLang(SfLang.en);
    await tester.pumpAndSettle();
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Платежи'), findsNothing);

    settings.setLang(SfLang.uz);
    await tester.pumpAndSettle();
    expect(find.text('To‘lovlar'), findsOneWidget);
    expect(find.text('To‘lov usullari'), findsOneWidget);
    expect(find.text('Tushum'), findsWidgets);

    await tester.pumpWidget(
      _host(settings, store, const Scaffold(body: WebGroupsPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guruhlar'), findsWidgets);
    expect(find.text('Faol guruhlar'), findsOneWidget);

    settings.setLang(SfLang.ru);
    await tester.pumpAndSettle();
    expect(find.text('Группы'), findsWidgets);
    expect(find.text('Активные группы'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('groups-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить'), findsOneWidget);

    settings.setLang(SfLang.en);
    await tester.pumpAndSettle();
    expect(find.text('Groups'), findsWidgets);
    expect(find.text('Active groups'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone navigation labels follow the selected language', (
    tester,
  ) async {
    _phone(tester);
    final settings = AppSettings(lang: SfLang.ru);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(
        settings,
        store,
        Console(cfg: kRoleConfigs[SfRole.ceo]!, onSwitchRole: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('console-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.text('Панель'), findsWidgets);
    expect(find.text('Группы'), findsWidgets);
    expect(find.text('Ученики'), findsWidgets);
    expect(find.text('Профиль'), findsWidgets);

    settings.setLang(SfLang.en);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Panel'), findsWidgets);
    expect(find.text('Groups'), findsWidgets);
    expect(find.text('Students'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive three-card grid uses a full-width final card', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: SfTheme(
          colors: SfColors.light,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(18),
              child: RefAdaptiveGrid(
                children: [
                  Container(
                    key: const ValueKey('grid-first'),
                    height: 50,
                    color: Colors.red,
                  ),
                  Container(
                    key: const ValueKey('grid-second'),
                    height: 50,
                    color: Colors.green,
                  ),
                  Container(
                    key: const ValueKey('grid-third'),
                    height: 50,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final first = tester.getSize(find.byKey(const ValueKey('grid-first')));
    final second = tester.getSize(find.byKey(const ValueKey('grid-second')));
    final third = tester.getSize(find.byKey(const ValueKey('grid-third')));
    expect(first.width, closeTo(second.width, 1));
    expect(third.width, greaterThan(first.width * 1.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('students expose a working education start date filter', (
    tester,
  ) async {
    _phone(tester);
    final settings = AppSettings(lang: SfLang.ru);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(settings, store, const Scaffold(body: StudentsScreen())),
    );
    await tester.pumpAndSettle();

    final calendar = find.byKey(const ValueKey('students-enrolled-date-range'));
    expect(calendar, findsOneWidget);
    expect(find.text('Начало обучения: от — до'), findsOneWidget);
    await tester.tap(calendar);
    await tester.pumpAndSettle();
    expect(find.text('Дата начала обучения'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
