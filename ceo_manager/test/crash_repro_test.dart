import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/modules.dart';
import 'package:ceo_manager/pages.dart';
import 'package:ceo_manager/data.dart';

// Pump a pushed-route widget with NO SfTheme ancestor — exactly how
// Navigator.push presents these screens in the real app.
Widget _host(AppStore store, Widget child) => SettingsScope(
      settings: AppSettings(),
      child: AppScope(
        store: store,
        child: MaterialApp(home: Builder(builder: (_) => child)),
      ),
    );

Future<void> _smoke(WidgetTester tester, AppStore store, Widget child) async {
  await tester.pumpWidget(_host(store, child));
  await tester.pump(const Duration(seconds: 1)); // let entrance animations fire
  expect(tester.takeException(), isNull);
}

// How ModulesHub presents module pages in the real app: wrapped in SfTheme so
// the pushed route's build context has an ambient theme.
Widget _wrap(Widget w) => SfTheme(colors: SfColors.light, child: w);

// Every menu id routed by buildAdminPage().
const _adminIds = [
  'branches', 'students', 'groups', 'teachers', 'parents', 'departments',
  'hr', 'meetings', 'payments', 'payroll', 'messages', 'chats', 'ai',
  'permissions', 'leads', 'enroll', 'approvals', 'schedule', 'anomalies',
  'fairness', 'finance', 'logs', 'aiusage', 'surveys', 'cases', 'settings',
];

void main() {
  final c = SfColors.light;

  for (final role in SfRole.values) {
    final store = AppStore.seed(role);

    testWidgets('ReportScreen $role', (t) async {
      await _smoke(t, store, ReportScreen(colors: c, role: role));
    });

    testWidgets('admin pages $role', (t) async {
      for (final id in _adminIds) {
        final page = buildAdminPage(id, c, role);
        if (page != null) await _smoke(t, store, page);
      }
    });
  }

  final store = AppStore.seed(SfRole.ceo);

  testWidgets('LedgerEntryScreen', (t) async {
    await _smoke(t, store, LedgerEntryScreen(entry: store.ledger.first, colors: c));
  });
  testWidgets('LedgerScreen', (t) async {
    await _smoke(t, store, LedgerScreen(colors: c));
  });
  testWidgets('AttendanceScreen', (t) async {
    await _smoke(t, store, _wrap(AttendanceScreen(colors: c)));
  });
  testWidgets('ModulesHub', (t) async {
    await _smoke(t, store, ModulesHub(colors: c));
  });
  testWidgets('AvatarPickerScreen', (t) async {
    await _smoke(t, store, AvatarPickerScreen(colors: c));
  });
  testWidgets('SettingsScreen', (t) async {
    await _smoke(t, store, SettingsScreen(colors: c));
  });
  testWidgets('StudentDetailScreen', (t) async {
    await _smoke(t, store, StudentDetailScreen(student: store.students.first, colors: c));
  });
  testWidgets('ChatScreen', (t) async {
    await _smoke(t, store, ChatScreen(threadIdx: 0, colors: c));
  });
  testWidgets('module screens', (t) async {
    for (final m in [
      PaymentsScreen(colors: c),
      PrintingScreen(colors: c),
      ExamsScreen(colors: c),
      SpeakingScreen(colors: c),
      CameraScreen(colors: c),
      RewardsScreen(colors: c),
      HrScreen(colors: c),
      RuleBookScreen(colors: c),
    ]) {
      await _smoke(t, store, _wrap(m));
    }
  });
}
