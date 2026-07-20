import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppStore store, Widget child) => SettingsScope(
  settings: AppSettings(),
  child: AppScope(
    store: store,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SfTheme(colors: SfColors.light, child: child),
    ),
  ),
);

void main() {
  testWidgets('every role tab opens without a rendering exception', (
    tester,
  ) async {
    for (final role in SfRole.values) {
      final store = AppStore.seed(role);
      await tester.pumpWidget(
        _host(store, Console(cfg: kRoleConfigs[role]!, onSwitchRole: () {})),
      );
      await tester.pump(const Duration(seconds: 1));

      for (final tab in kRoleConfigs[role]!.tabs) {
        final navigationIcon = find.byIcon(tab.icon).last;
        await tester.tap(navigationIcon);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.takeException(),
          isNull,
          reason: '${role.name}/${tab.id}',
        );
      }
    }
  });

  testWidgets('Department buttons appoint a leader and transfer an employee', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(store, DepartmentsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Matematika').first);
    await tester.pumpAndSettle();
    expect(find.byType(DepartmentDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.manage_accounts_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aziz Tursunov').last);
    await tester.pumpAndSettle();
    expect(store.departments.first.manager, 'Aziz Tursunov');
    expect(
      store.staff
          .firstWhere((member) => member.fullName == 'Aziz Tursunov')
          .department,
      'Matematika',
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshqa bo‘limga ko‘chirish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(
      store.staff
          .firstWhere((member) => member.fullName == 'Nigora Karimova')
          .department,
      'English',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('student search accepts an ID and Top Students opens a profile', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    final student = store.students.first;
    final id = studentProfile(student).studentId;
    await tester.pumpWidget(
      _host(store, const Scaffold(body: StudentsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, id);
    await tester.pumpAndSettle();
    expect(find.text(student.name), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(store, TopStudentsScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azizova Madina').last);
    await tester.pumpAndSettle();
    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager can mark attendance and save it', (tester) async {
    final store = AppStore.seed(SfRole.manager);
    await tester.pumpWidget(
      _host(store, AttendanceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text(store.students.first.name),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.tap(find.text(store.students.first.name));
    await tester.pumpAndSettle();
    expect(find.text("Yo'q"), findsAtLeastNWidgets(2));
    await tester.tap(find.text('Saqlash'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
