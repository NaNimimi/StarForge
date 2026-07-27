import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI usage audit page fits a 320px phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = AppSettings(dark: true);
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: AppScope(
          store: AppStore.seed(SfRole.audit),
          child: MaterialApp(
            theme: sfMaterialTheme(settings.colors, dark: true),
            home: AiUsageAdminPage(colors: settings.colors),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('AI monitoring'), findsWidgets);
  });
}
