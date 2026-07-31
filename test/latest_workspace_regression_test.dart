import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/reference_ui.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/web_mobile_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppStore store, Widget child) => SettingsScope(
  settings: AppSettings(lang: SfLang.ru),
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
  testWidgets('group metrics use 2+1 layout and all drilldowns work', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(store, const Scaffold(body: WebGroupsPage())),
    );
    await tester.pumpAndSettle();

    final active = find.byKey(const ValueKey('groups-active-metric'));
    final students = find.byKey(const ValueKey('groups-students-metric'));
    final debt = find.byKey(const ValueKey('groups-debt-metric'));
    expect(active, findsOneWidget);
    expect(students, findsOneWidget);
    expect(debt, findsOneWidget);
    expect(
      tester.getSize(active).width,
      closeTo(tester.getSize(students).width, 1),
    );
    expect(
      tester.getSize(debt).width,
      greaterThan(tester.getSize(active).width * 1.8),
    );

    await tester.tap(students);
    await tester.pumpAndSettle();
    expect(find.text('Ученики выбранных групп'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    await tester.tap(debt);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('groups-open-filters')), findsOneWidget);
    expect(find.byKey(const ValueKey('groups-date-range')), findsOneWidget);
    expect(find.text('От — до'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('groups-open-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('groups-reset-filters')), findsOneWidget);
    expect(find.text('Статус'), findsOneWidget);
    expect(find.text('Филиал'), findsOneWidget);
    expect(find.text('Преподаватель'), findsOneWidget);
    expect(find.text('Уровень'), findsOneWidget);
    expect(find.text('Посещаемость'), findsOneWidget);
    expect(find.text('Задолженность'), findsOneWidget);
    expect(find.byType(RefPaginationBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('groups-reset-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groups-apply-filters')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('parents and teachers metrics are actionable without paging', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(store, ParentsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();
    final parentAll = find.byKey(const ValueKey('parents-all-metric'));
    final parentCall = find.byKey(const ValueKey('parents-callback-metric'));
    final parentDebt = find.byKey(const ValueKey('parents-debt-metric'));
    expect(
      tester.getSize(parentAll).width,
      closeTo(tester.getSize(parentCall).width, 1),
    );
    expect(
      tester.getSize(parentDebt).width,
      greaterThan(tester.getSize(parentAll).width * 1.8),
    );
    await tester.tap(parentCall);
    await tester.pumpAndSettle();
    await tester.tap(parentDebt);
    await tester.pumpAndSettle();
    await tester.tap(parentAll);
    await tester.pumpAndSettle();
    expect(find.byType(RefPaginationBar), findsNothing);
    expect(find.text('OFFLINE DEMO'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(store, TeachersWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('teachers-groups-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('teachers-all-metric')));
    await tester.pumpAndSettle();
    expect(find.byType(RefPaginationBar), findsNothing);
    expect(find.text('OFFLINE DEMO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payments expose date range and an interactive segmented donut', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(store, const Scaffold(body: WebPaymentsPage())),
    );
    await tester.pumpAndSettle();

    final donut = find.byKey(const ValueKey('payment-channel-donut'));
    expect(donut, findsOneWidget);
    expect(find.text('Всего'), findsOneWidget);
    await tester.tapAt(tester.getCenter(donut) + const Offset(34, 0));
    await tester.pumpAndSettle();
    expect(find.text('Всего'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('payments-date-range')));
    await tester.pumpAndSettle();
    expect(find.text('Период'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(RefPaginationBar), findsNothing);
  });

  testWidgets('payroll actions and every employee row open full calculations', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(store, const PayrollAdminPage(colors: SfColors.light, ceo: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payroll-period')), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-recalculate')), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-approve')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payroll-recalculate')));
    await tester.pumpAndSettle();
    expect(find.text('Проверка расчёта'), findsOneWidget);
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nigora Karimova'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nigora Karimova'));
    await tester.pumpAndSettle();
    expect(find.text('Итого начислено'), findsOneWidget);
    expect(find.text('Способ выплаты'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('department pages contain no rating concept', (tester) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _host(store, DepartmentsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('reyting', findRichText: true), findsNothing);
    expect(find.textContaining('рейтинг', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
