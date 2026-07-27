import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: sfMaterialTheme(SfColors.light, dark: false),
  home: SfTheme(colors: SfColors.light, child: child),
);

Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_host(child));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('legacy student row opens a complete record inspector', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      const StudentsAdminPage(colors: SfColors.light, ceo: true),
    );

    await tester.scrollUntilVisible(
      find.text('Akbarov Akmal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Akbarov Akmal'));
    await tester.pumpAndSettle();

    expect(find.text('Davomat'), findsWidgets);
    expect(find.text('96%'), findsWidgets);
    expect(find.text('Mas’ul'), findsOneWidget);
    expect(find.text('Akbarova D.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approval decision changes state and can be undone', (
    tester,
  ) async {
    await _pumpPhone(tester, const ApprovalsAdminPage(colors: SfColors.light));

    final approve = find.byKey(
      const ValueKey('approval-approve-To‘lov qaytarish'),
    );
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approval-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Tasdiqlandi'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsOneWidget);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Tasdiqlandi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enrollment test validates, scores and saves a candidate', (
    tester,
  ) async {
    await _pumpPhone(tester, const EnrollAdminPage(colors: SfColors.light));

    await tester.tap(find.text('Yangi nomzod · test boshlash'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('enroll-name')),
      'Malika Karimova',
    );
    await tester.enterText(
      find.byKey(const ValueKey('enroll-phone')),
      '+998 90 123 45 67',
    );
    await tester.tap(find.text('Testni boshlash'));
    await tester.pumpAndSettle();

    for (final answer in ['She goes to school.', 'taught', '96', '32']) {
      await tester.scrollUntilVisible(
        find.text(answer),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(answer));
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      find.text('Natijani hisoblash'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Natijani hisoblash'));
    await tester.pumpAndSettle();

    expect(find.text('Malika Karimova · 100%'), findsOneWidget);
    await tester.tap(find.text('Natijani saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Oxirgi natijalar'), findsOneWidget);
    expect(find.text('Malika Karimova'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
