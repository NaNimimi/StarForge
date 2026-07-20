import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/console.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/theme.dart';

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
        home: Console(cfg: kRoleConfigs[SfRole.ceo]!, onSwitchRole: () {}),
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
    // The dashboard's top bar remains in AnimatedSwitcher while the profile
    // enters, so restrict the finder to an actually tappable icon.
    final notif = find.byIcon(Icons.notifications_none_rounded).hitTestable();
    if (notif.evaluate().isNotEmpty) {
      await t.tap(notif.first);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('chat header opens the contact personal cabinet', (t) async {
    final store = AppStore.seed(SfRole.ceo);
    await t.pumpWidget(
      _chatHost(store, ChatScreen(threadIdx: 0, colors: SfColors.light)),
    );
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('chat-profile-header')));
    await t.pumpAndSettle();
    expect(find.byType(ChatCabinetScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-cabinet')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('student chat header opens the student personal cabinet', (
    t,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await t.pumpWidget(
      _chatHost(
        store,
        StudentChatScreen(
          student: store.students.first,
          colors: SfColors.light,
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('student-chat-profile-header')));
    await t.pumpAndSettle();
    expect(find.byType(ChatCabinetScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

Widget _chatHost(AppStore store, Widget child) {
  final settings = AppSettings();
  return SettingsScope(
    settings: settings,
    child: AppScope(
      store: store,
      child: MaterialApp(home: child),
    ),
  );
}
