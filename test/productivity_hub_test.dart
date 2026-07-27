import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/productivity_hub.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required SfRole role,
  required AppStore store,
  ValueChanged<String>? onNavigate,
}) {
  final settings = AppSettings(dark: role == SfRole.audit);
  return SettingsScope(
    settings: settings,
    child: AppScope(
      store: store,
      child: MaterialApp(
        theme: sfMaterialTheme(settings.colors, dark: settings.dark),
        home: SfTheme(
          colors: settings.colors,
          child: ProductivityHub(role: role, onNavigate: onNavigate ?? (_) {}),
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

void main() {
  test('CEO and Manager each expose at least twenty permitted commands', () {
    final ceo = productivityCommandsFor(SfRole.ceo);
    final manager = productivityCommandsFor(SfRole.manager);

    expect(ceo.length, greaterThanOrEqualTo(20));
    expect(manager.length, greaterThanOrEqualTo(20));
    expect(
      [...ceo, ...manager].map((command) => command.item.id),
      everyElement(
        anyOf(
          isIn(navigationRoutesFor(SfRole.ceo)),
          isIn(navigationRoutesFor(SfRole.manager)),
        ),
      ),
    );
  });

  testWidgets('Audit never exposes business or RBAC destinations', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.audit);
    // Even stale/hostile local state must not surface a forbidden route.
    store.favoriteCommandRoutes.addAll({
      'students',
      'payments',
      'permissions',
      'cases',
    });
    store.recentCommandRoutes.addAll(['branches', 'students', 'logs']);

    await tester.pumpWidget(_host(role: SfRole.audit, store: store));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('productivity-command-favorite-students')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('productivity-command-favorite-payments')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('productivity-command-favorite-permissions')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('productivity-command-favorite-cases')),
      findsOneWidget,
    );
    expect(
      productivityCommandsFor(SfRole.audit).map((command) => command.item.id),
      isNot(anyOf(contains('students'), contains('payments'))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters commands by label and route', (tester) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    await tester.pumpWidget(_host(role: SfRole.manager, store: store));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('productivity-search'));
    await tester.enterText(search, 'payments');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('productivity-command-all-payments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('productivity-command-all-students')),
      findsNothing,
    );
  });

  testWidgets('favorite is stored and rendered in the quick section', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    await tester.pumpWidget(_host(role: SfRole.manager, store: store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('productivity-command-all-payments')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('productivity-favorite-payments-all')),
    );
    await tester.pump();

    expect(store.favoriteCommandRoutes, contains('payments'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('productivity-command-favorite-payments')),
      -260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('productivity-command-favorite-payments')),
      findsOneWidget,
    );
  });

  testWidgets('command opens through callback and updates recent routes', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.seed(SfRole.manager);
    String? opened;
    await tester.pumpWidget(
      _host(
        role: SfRole.manager,
        store: store,
        onNavigate: (route) => opened = route,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('productivity-command-all-students')),
    );
    await tester.pump();

    expect(opened, 'students');
    expect(store.recentCommandRoutes.first, 'students');
  });
}
