// Smoke test: the real app boots to the login screen without throwing.
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/main.dart';

void main() {
  testWidgets('app boots to login', (tester) async {
    await tester.pumpWidget(const CeoManagerApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
