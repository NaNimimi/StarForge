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
  'branches',
  'students',
  'groups',
  'teachers',
  'parents',
  'departments',
  'hr',
  'meetings',
  'payments',
  'payroll',
  'messages',
  'chats',
  'ai',
  'permissions',
  'leads',
  'enroll',
  'approvals',
  'schedule',
  'anomalies',
  'fairness',
  'finance',
  'logs',
  'aiusage',
  'surveys',
  'cases',
  'settings',
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
    await _smoke(
      t,
      store,
      LedgerEntryScreen(entry: store.ledger.first, colors: c),
    );
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
  testWidgets('Chat Design previews render on a phone screen', (t) async {
    await t.pumpWidget(_host(store, SettingsScreen(colors: c)));
    await t.pumpAndSettle();
    final scrollable = find.byType(ListView).first;
    for (
      int i = 0;
      i < 8 &&
          find.text('CHAT DIZAYNI', skipOffstage: false).evaluate().isEmpty;
      i++
    ) {
      await t.drag(scrollable, const Offset(0, -220));
      await t.pumpAndSettle();
    }
    expect(find.text('CHAT DIZAYNI', skipOffstage: false), findsOneWidget);
    expect(find.text('Telegram', skipOffstage: false), findsOneWidget);
    expect(find.text('Madina', skipOffstage: false), findsWidgets);
    for (
      int i = 0;
      i < 6 &&
          find.text('WhatsApp Pattern', skipOffstage: false).evaluate().isEmpty;
      i++
    ) {
      await t.drag(scrollable, const Offset(0, -220));
      await t.pumpAndSettle();
    }
    expect(find.text('WhatsApp Pattern', skipOffstage: false), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('StudentDetailScreen', (t) async {
    await _smoke(
      t,
      store,
      StudentDetailScreen(student: store.students.first, colors: c),
    );
  });
  testWidgets('ChatScreen', (t) async {
    await _smoke(t, store, ChatScreen(threadIdx: 0, colors: c));
  });
  testWidgets('NotificationsScreen', (t) async {
    await _smoke(t, store, NotificationsScreen(colors: c));
  });
  testWidgets('AnomalyDetailScreen', (t) async {
    await _smoke(
      t,
      store,
      AnomalyDetailScreen(a: store.anomalies.first, store: store, colors: c),
    );
  });
  testWidgets('CaseDetailScreen', (t) async {
    await _smoke(
      t,
      store,
      CaseDetailScreen(cs: store.cases.first, store: store, colors: c),
    );
  });
  testWidgets('StudentChatScreen', (t) async {
    await _smoke(
      t,
      store,
      StudentChatScreen(student: store.students.first, colors: c),
    );
  });
  testWidgets('EditProfileScreen', (t) async {
    await _smoke(
      t,
      store,
      EditProfileScreen(cfg: kRoleConfigs[SfRole.ceo]!, colors: c),
    );
  });
  testWidgets('GroupDetailScreen', (t) async {
    const g = GroupInfo(
      '9-B Algebra',
      'Yunusobod',
      'Intermediate',
      'Nigora Karimova',
      'Du·Cho·Ju · 10:00',
      8,
      90,
      2,
    );
    await _smoke(t, store, GroupDetailScreen(group: g, colors: c));
  });
  testWidgets(
    'BranchWorkspaceScreen opens and opens report without SfTheme error',
    (t) async {
      await _smoke(
        t,
        store,
        BranchWorkspaceScreen(branch: store.branches.first, colors: c),
      );
      await t.tap(find.byIcon(Icons.download_rounded));
      await t.pumpAndSettle();
      expect(find.text('Hisobot formati'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Student Flow number opens a category then a student profile', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        store,
        SfTheme(
          colors: c,
          child: const Scaffold(body: StudentsScreen()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Student Flow · period', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Left', skipOffstage: false), findsOneWidget);
    final leftCount = find.byKey(
      const ValueKey('student-flow-left'),
      skipOffstage: false,
    );
    await t.dragUntilVisible(
      leftCount,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await t.tap(leftCount);
    await t.pumpAndSettle();
    expect(find.byType(StudentCategoryScreen), findsOneWidget);
    expect(find.text('3 ta o‘quvchi'), findsOneWidget);
    await t.tap(find.text('Sobirov Mohir').last);
    await t.pumpAndSettle();
    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('MenuHub', (t) async {
    await _smoke(t, store, MenuHub(colors: c, role: SfRole.ceo));
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
