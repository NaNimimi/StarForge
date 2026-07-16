import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/console.dart';

// Same ancestor stack as main.dart, but parametrised over role / language /
// theme and pinned to a PHONE-sized surface — exactly the conditions the
// founder runs on. Driven via `flutter drive --profile` (asserts stripped).
Widget _app(AppStore store, AppSettings settings) => SettingsScope(
      settings: settings,
      child: AppScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Console(cfg: kRoleConfigs[store.role]!, onSwitchRole: () {}),
        ),
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Pin a realistic phone surface (≈ Pixel: 411 x 891 dp at dpr 2.625).
  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  for (final role in SfRole.values) {
    for (final lang in SfLang.values) {
      for (final dark in [false, true]) {
        final tag = '${role.name}/${lang.name}/${dark ? "dark" : "light"}';

        testWidgets('edit-profile renders · $tag', (t) async {
          await phone(t);
          await t.pumpWidget(_app(AppStore.seed(role), AppSettings(lang: lang, dark: dark)));
          await t.pumpAndSettle();
          // Profile tab.
          await t.tap(find.byIcon(Icons.person_rounded).last);
          await t.pumpAndSettle();
          // Open edit (pencil on the profile card).
          await t.tap(find.byIcon(Icons.edit_rounded).first);
          await t.pumpAndSettle();
          // The page must actually render its form, not a blank/error box.
          expect(find.byType(EditProfileScreen), findsOneWidget, reason: tag);
          expect(find.byType(TextField), findsAtLeastNWidgets(2), reason: '$tag — name/title fields missing (blank page)');
          expect(t.takeException(), isNull, reason: tag);
        });

        testWidgets('report renders · $tag', (t) async {
          await phone(t);
          await t.pumpWidget(_app(AppStore.seed(role), AppSettings(lang: lang, dark: dark)));
          await t.pumpAndSettle();
          final report = find.byIcon(Icons.download_rounded);
          // CEO/Audit dashboards expose a report button; managers may differ.
          if (report.evaluate().isEmpty) return;
          await t.tap(report.first);
          await t.pumpAndSettle();
          expect(find.byType(ReportScreen), findsOneWidget, reason: tag);
          // The export button at the bottom proves the body built fully.
          expect(find.byIcon(Icons.download_rounded), findsWidgets, reason: '$tag — report body blank');
          expect(t.takeException(), isNull, reason: tag);
        });
      }
    }
  }
}
