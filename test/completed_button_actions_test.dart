import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/web_mobile_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(AppStore store, Widget child, {AppSettings? settings}) =>
    SettingsScope(
      settings: settings ?? AppSettings(lang: SfLang.ru),
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
  testWidgets('manager payment intake creates ledger entry and opens details', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(store.dispose);
    final before = store.ledger.length;

    await tester.pumpWidget(
      _host(store, const Scaffold(body: WebPaymentsPage())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'payments list');

    await tester.tap(find.byTooltip('Принять платёж'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'payment form');
    expect(find.text('Принять платёж'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('payment-intake-amount')),
      '725000',
    );
    await tester.tap(find.text('Сохранить платёж'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'payment detail');

    expect(store.ledger, hasLength(before + 1));
    expect(store.ledger.first.amount, 725000);
    expect(find.byType(LedgerEntryScreen), findsOneWidget);
    expect(find.text('Номер операции'), findsOneWidget);
  });

  testWidgets('offline notification history never invents server events', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seed(SfRole.manager);
    final settings = AppSettings(lang: SfLang.ru);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(
        store,
        const Scaffold(body: NotificationsScreen(colors: SfColors.light)),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Непрочитанных уведомлений нет'), findsOneWidget);
    expect(store.readLocalNotificationIds, isEmpty);
    expect(find.text('Открыть историю'), findsOneWidget);
    await tester.tap(find.text('Открыть историю'));
    await tester.pumpAndSettle();
    expect(find.text('Уведомлений нет'), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
    await settings.saveNotificationState();

    final restored = await AppSettings.load();
    expect(restored.readNotificationKeys, isEmpty);
    expect(restored.hiddenNotificationKeys, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline notification callback is not called without API rows', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seed(SfRole.manager);
    final settings = AppSettings(lang: SfLang.ru);
    addTearDown(store.dispose);
    String? destination;

    await tester.pumpWidget(
      _host(
        store,
        Scaffold(
          body: NotificationsScreen(
            colors: SfColors.light,
            onNavigate: (route) => destination = route,
          ),
        ),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);
    expect(destination, isNull);
    expect(store.readLocalNotificationIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance save and reminder create real session records', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(
        store,
        const Scaffold(body: AttendanceScreen(colors: SfColors.light)),
      ),
    );
    await tester.pumpAndSettle();

    final firstStudent = store.students.first;
    await tester.scrollUntilVisible(
      find.text(firstStudent.name),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(firstStudent.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Черновики (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Черновики напоминаний'), findsOneWidget);
    expect(find.textContaining('Ничего не отправляется'), findsOneWidget);
    await tester.tap(find.textContaining('Сохранить черновики'));
    await tester.pumpAndSettle();
    expect(
      store.activities.first.title,
      'Напоминания о посещаемости подготовлены',
    );

    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(store.activities.first.title, 'Посещаемость сохранена');
    expect(tester.takeException(), isNull);
  });

  testWidgets('branch transfer changes staff branch after confirmation', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(store.dispose);
    final member = store.staff.first;
    final target = store.branches.firstWhere(
      (branch) => branch.name != member.branch,
    );

    await tester.pumpWidget(
      _host(
        store,
        BranchConfigureScreen(
          branch: store.branches.first,
          colors: SfColors.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xodimni o‘tkazish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перевести'));
    await tester.pumpAndSettle();

    expect(
      store.staff.firstWhere((item) => item.username == member.username).branch,
      target.name,
    );
    expect(find.text('Перевод выполнен'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
