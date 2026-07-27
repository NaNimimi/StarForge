import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppSettings settings) => SettingsScope(
  settings: settings,
  child: AppScope(
    store: AppStore.seed(SfRole.ceo),
    child: MaterialApp(
      theme: sfMaterialTheme(settings.colors, dark: settings.dark),
      home: Console(cfg: kRoleConfigs[SfRole.ceo]!, onSwitchRole: () {}),
    ),
  ),
);

void _surface(WidgetTester tester, Size logicalSize) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test('dark Material controls use the StarForge surface foreground', () {
    final colors = SfColors.dark;
    final theme = sfMaterialTheme(colors, dark: true);
    final states = <WidgetState>{};
    expect(
      theme.filledButtonTheme.style!.foregroundColor!.resolve(states),
      colors.surface,
    );
    expect(
      theme.elevatedButtonTheme.style!.backgroundColor!.resolve(states),
      colors.primary,
    );
    expect(theme.inputDecorationTheme.fillColor, colors.surface);
  });

  testWidgets('tablet uses the persistent navigation sidebar', (tester) async {
    _surface(tester, const Size(920, 1000));
    await tester.pumpWidget(_host(AppSettings()));
    await tester.pump();
    expect(find.byTooltip('Boshqaruv paneli'), findsOneWidget);
  });

  testWidgets('wide legacy topbar preference keeps the navigation sidebar', (
    tester,
  ) async {
    _surface(tester, const Size(1200, 1000));
    await tester.pumpWidget(_host(AppSettings(layout: 2)));
    await tester.pump();
    expect(find.byTooltip('Boshqaruv paneli'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
  });
}
