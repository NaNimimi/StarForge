import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 760);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _host(Widget child) {
  final settings = AppSettings();
  return SettingsScope(
    settings: settings,
    child: AppScope(
      store: AppStore.seed(SfRole.ceo),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sfMaterialTheme(settings.colors, dark: false),
        home: SfTheme(colors: settings.colors, child: child),
      ),
    ),
  );
}

Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  _usePhone(tester);
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 900));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'oversight row opens searchable read-only transcript with metadata at 320px',
    (tester) async {
      await _pumpPhone(tester, ChatsAdminPage(colors: SfColors.light));

      await tester.tap(
        find.byKey(const ValueKey('oversight-thread-0')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('oversight-chat-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('oversight-read-only-banner')),
        findsOneWidget,
      );
      expect(find.text('Метаданные разговора'), findsOneWidget);
      expect(find.text('Nigora Karimova'), findsWidgets);
      expect(find.text('Akbarova Dilnoza'), findsWidgets);
      expect(find.text('O‘quvchi · guruh'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);

      // The only editable control is transcript search: there is no composer,
      // send button or destructive message action on this oversight route.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.text('Изменить'), findsNothing);
      expect(find.text('Удалить'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('oversight-chat-search')),
        'nazorat',
      );
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget);
      expect(
        find.text('Ertaga nazorat ishi bo‘ladi. Daftarini olib kelsin.'),
        findsOneWidget,
      );
      expect(
        find.text('Rahmat, uyda ham mashqlarni davom ettiramiz.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permission detail mirrors role menu routes and scopes at 320px',
    (tester) async {
      await _pumpPhone(tester, PermissionsAdminPage(colors: SfColors.light));

      expect(find.byKey(const ValueKey('permission-role-ceo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('permission-role-manager')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('permission-role-audit')),
        findsOneWidget,
      );
      expect(find.text('Metodist'), findsNothing);
      expect(find.text('O‘qituvchi'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('permission-role-manager')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('permission-matrix-manager')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-payments')),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-payments')),
        findsOneWidget,
      );
      expect(
        navigationRoutesFor(SfRole.manager),
        isNot(contains('permissions')),
      );
      expect(navigationRoutesFor(SfRole.manager), isNot(contains('anomalies')));
      expect(find.textContaining('Просмотр операций'), findsOneWidget);
      expect(find.textContaining('Yunusobod'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-role-ceo')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-permissions')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-permissions')),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-role-audit')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('permission-route-cases')),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('permission-route-cases')),
        findsOneWidget,
      );
      expect(navigationRoutesFor(SfRole.audit), isNot(contains('payments')));
      expect(tester.takeException(), isNull);
    },
  );
}
