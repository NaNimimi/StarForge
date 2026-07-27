import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/modules.dart';
import 'package:ceo_manager/theme.dart';

Widget _host(Widget child) => MaterialApp(
  home: SfTheme(colors: SfColors.light, child: child),
);

Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(child));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final finder = find.text(text);
  final target = last ? finder.last : finder.first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('payments validate, add, filter and open details at 320px', (
    tester,
  ) async {
    await _pumpPhone(tester, const PaymentsScreen(colors: SfColors.light));

    await _tapText(tester, "To'lov qabul qilish");
    await _tapText(tester, 'Qabul qilish');
    expect(find.text('Maydonni to‘ldiring'), findsNWidgets(2));
    expect(find.text('Musbat summa kiriting'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('payment-payer-field')),
      'Ali Valiyev',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payment-student-field')),
      'Valiyeva Lola',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-field')),
      '750000',
    );
    await _tapText(tester, 'Qabul qilish');

    expect(find.text('Ali Valiyev'), findsOneWidget);
    await _tapText(tester, 'Ali Valiyev');
    expect(find.byKey(const ValueKey('module-payment-detail')), findsOneWidget);
    expect(find.text("To'lov tafsilotlari"), findsOneWidget);
    expect(find.text('Valiyeva Lola'), findsOneWidget);

    Navigator.of(tester.element(find.text("To'lov tafsilotlari"))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('module-payment-detail')), findsNothing);
    await _tapText(tester, 'Click');
    expect(find.byKey(const ValueKey('module-payment-PAY-2404')), findsNothing);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('printing creates jobs and supports complete/cancel at 320px', (
    tester,
  ) async {
    await _pumpPhone(tester, const PrintingScreen(colors: SfColors.light));

    await _tapText(tester, 'Yangi bosib chiqarish ishi');
    await tester.enterText(
      find.byKey(const ValueKey('print-title-field')),
      'Parent meeting pack',
    );
    await tester.enterText(
      find.byKey(const ValueKey('print-owner-field')),
      'Madina A.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('print-pages-field')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('print-copies-field')),
      '12',
    );
    await _tapText(tester, 'Navbatga qo‘shish');

    expect(find.text('Parent meeting pack'), findsOneWidget);
    await _tapText(tester, 'Parent meeting pack');
    expect(find.byKey(const ValueKey('module-print-detail')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('module-print-detail')),
        matching: find.text('Tayyor'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('module-print-detail')), findsNothing);
    expect(find.text('Tayyor'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('module-print-PRINT-101')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('module-print-detail')),
        matching: find.text('Bekor qilish'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('module-print-detail')), findsNothing);
    final queuedFilter = find
        .ancestor(
          of: find.text('Navbatda'),
          matching: find.byType(GestureDetector),
        )
        .first;
    tester.widget<GestureDetector>(queuedFilter).onTap!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('module-print-PRINT-101')), findsNothing);
    expect(find.text('Parent meeting pack'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam session advances and saves a real score at 320px', (
    tester,
  ) async {
    await _pumpPhone(tester, const ExamsScreen(colors: SfColors.light));

    await tester.tap(find.byKey(const ValueKey('module-exam-start-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('module-exam-option-0-1')));
    await _tapText(tester, 'Keyingi savol');
    await tester.tap(find.byKey(const ValueKey('module-exam-option-1-2')));
    await _tapText(tester, 'Keyingi savol');
    await tester.tap(find.byKey(const ValueKey('module-exam-option-2-1')));
    await _tapText(tester, 'Yakunlash');

    expect(find.byKey(const ValueKey('module-exam-result')), findsOneWidget);
    expect(find.text('Natija: 3/3'), findsOneWidget);
    await _tapText(tester, 'Natijani saqlash');
    expect(find.textContaining('oxirgi natija 3/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HR adds candidate, opens details and changes stage at 320px', (
    tester,
  ) async {
    await _pumpPhone(tester, const HrScreen(colors: SfColors.light));

    await _tapText(tester, 'Yangi nomzod qo‘shish');
    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      'Diyor S.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('candidate-role-field')),
      'Fizika o‘qituvchisi',
    );
    await tester.enterText(
      find.byKey(const ValueKey('candidate-phone-field')),
      '+998 90 555 44 33',
    );
    await _tapText(tester, 'Nomzodni qo‘shish');

    expect(find.text('Diyor S.'), findsOneWidget);
    await _tapText(tester, 'Diyor S.');
    expect(
      find.byKey(const ValueKey('module-candidate-detail')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('candidate-stage-field')));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Suhbat', last: true);
    await _tapText(tester, 'Bosqichni saqlash');

    expect(find.text('Diyor S.'), findsOneWidget);
    expect(find.text('Suhbat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
