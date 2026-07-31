// Smoke test: the real app boots to the login screen without throwing.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ceo_manager/api_connection.dart';
import 'package:ceo_manager/main.dart';

void main() {
  testWidgets('app boots to login', (tester) async {
    await tester.pumpWidget(const CeoManagerApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ApiLoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('api-login-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-login-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-login-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-login-server-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('api-login-endpoint')), findsNothing);
    expect(find.text('Сервер API'), findsNothing);
    expect(
      find.byKey(const ValueKey('api-login-forgot-password')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
