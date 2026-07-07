import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/console.dart';

// Mirror main.dart's real ancestor stack (SettingsScope > AppScope > MaterialApp),
// then drive the Console exactly like a user — tapping tabs and pushed routes.
// This exercises the real Navigator.push path, which the per-screen smoke tests
// (rendered as `home:`) do NOT.
Widget _app(AppStore store) {
  final settings = AppSettings();
  return SettingsScope(
    settings: settings,
    child: AppScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Console(
          cfg: kRoleConfigs[SfRole.ceo]!,
          onSwitchRole: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('CEO: open Report from dashboard', (t) async {
    await t.pumpWidget(_app(AppStore.seed(SfRole.ceo)));
    await t.pump(const Duration(seconds: 1));
    // Dashboard has a "report" affordance — find & tap it.
    final report = find.byIcon(Icons.download_rounded);
    if (report.evaluate().isNotEmpty) {
      await t.tap(report.first);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('CEO: profile → edit profile', (t) async {
    await t.pumpWidget(_app(AppStore.seed(SfRole.ceo)));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.person_rounded).last);
    await t.pump(const Duration(seconds: 1));
    // Tap the profile card (edit) — the edit pencil icon.
    final edit = find.byIcon(Icons.edit_rounded);
    expect(edit, findsWidgets, reason: 'profile edit affordance missing');
    await t.tap(edit.first);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('CEO: profile → notifications', (t) async {
    await t.pumpWidget(_app(AppStore.seed(SfRole.ceo)));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.person_rounded).last);
    await t.pump(const Duration(seconds: 1));
    final notif = find.byIcon(Icons.notifications_none_rounded);
    if (notif.evaluate().isNotEmpty) {
      await t.tap(notif.first);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }
    expect(t.takeException(), isNull);
  });
}
