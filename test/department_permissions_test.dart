import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppStore store, Widget child) => SettingsScope(
  settings: AppSettings(),
  child: AppScope(
    store: store,
    child: MaterialApp(
      home: SfTheme(colors: SfColors.light, child: child),
    ),
  ),
);

void main() {
  test(
    'department transfer, manager appointment and dismissal use one store',
    () {
      final store = AppStore.seed(SfRole.ceo);
      final mathematics = store.departments.first;
      final english = store.departments.firstWhere(
        (item) => item.name == 'English',
      );
      final nigora = store.staff.firstWhere(
        (member) => member.fullName == 'Nigora Karimova',
      );

      store.transferStaff(nigora, english);
      expect(store.staffForDepartment(mathematics), isEmpty);
      expect(
        store.staffForDepartment(english).map((member) => member.fullName),
        contains('Nigora Karimova'),
      );
      expect(mathematics.history.first.title, 'Xodim ko‘chirildi');
      expect(english.history.first.title, 'Xodim qabul qilindi');

      store.appointDepartmentManager(english, nigora);
      expect(english.manager, 'Nigora Karimova');
      expect(english.history.first.title, 'Yangi rahbar tayinlandi');

      final transferred = store.staff.firstWhere(
        (member) => member.username == nigora.username,
      );
      store.dismissStaff(transferred);
      expect(
        store.staff.where((member) => member.username == nigora.username),
        isEmpty,
      );
      expect(english.manager, 'Tayinlanmagan');
      expect(english.history.first.title, 'Xodim ishdan bo‘shatildi');
    },
  );

  testWidgets('CEO attendance is analytics-only', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(store, AttendanceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('CEO ko‘rinishi · faqat tahlil va hisobotlar'),
      findsOneWidget,
    );
    expect(find.text('Davomat hisoboti'), findsOneWidget);
    expect(find.text('Saqlash'), findsNothing);

    await tester.dragUntilVisible(
      find.text(store.students.first.name),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.tap(find.text(store.students.first.name));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('revenue chart safely switches from a selected 12 month point', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(
        store,
        const Scaffold(
          body: DashboardScreen(
            cfg: RoleConfig(
              role: SfRole.ceo,
              label: 'CEO',
              who: 'CEO',
              roleTitle: 'CEO',
              scope: 'All',
              dark: false,
              tabs: [],
            ),
            go: _ignoreTab,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = find.byType(LineChart).first;
    await tester.dragUntilVisible(
      chart,
      find.byType(Scrollable).first,
      const Offset(0, -350),
    );
    await tester.tapAt(tester.getTopRight(chart) - const Offset(10, -50));
    await tester.pump();
    await tester.ensureVisible(find.text('6 oy').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 oy').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _ignoreTab(String _) {}
