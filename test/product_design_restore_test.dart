import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_data_view.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  ApiSession session,
  AppStore store,
  Widget child, {
  SfLang lang = SfLang.uz,
}) {
  final settings = AppSettings(lang: lang);
  return SettingsScope(
    settings: settings,
    child: ApiScope(
      session: session,
      child: AppScope(
        store: store,
        child: MaterialApp(
          theme: sfMaterialTheme(SfColors.light, dark: false),
          home: SfTheme(colors: SfColors.light, child: child),
        ),
      ),
    ),
  );
}

void _surface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1100);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

void main() {
  testWidgets('API student opens the full product profile, never raw JSON', (
    tester,
  ) async {
    _surface(tester);
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['students'] = [
        {
          'id': 81,
          'name': 'API Product Student',
          'phone': '+998900000081',
          'is_active': true,
          'created_at': '2026-07-01T08:00:00Z',
        },
      ]
      ..collections['branches'] = [
        {'id': 1, 'name': 'API Product Branch'},
      ]
      ..collections['groups'] = <Map<String, dynamic>>[]
      ..collections['parents'] = <Map<String, dynamic>>[];
    final store = AppStore.empty(SfRole.ceo);
    syncProductStoreFromApi(session, store);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(session, store, const Scaffold(body: StudentsScreen())),
    );
    await tester.pumpAndSettle();
    final student = find.text('API Product Student', skipOffstage: false).last;
    await tester.scrollUntilVisible(
      student,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(student);
    await tester.pumpAndSettle();

    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(find.byType(InteractiveSparkline), findsOneWidget);
    expect(find.byType(ApiDataCard), findsNothing);
    expect(find.text('Дополнительная информация'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'branch comparison keeps selectors, rows and chart with API data',
    (tester) async {
      _surface(tester);
      final client = StarforgeApiClient()..configure(token: 'test-session');
      final session = ApiSession(client: client)
        ..collections['branches'] = [
          {'id': 1, 'name': 'API Branch Alpha', 'attendance_rate': .94},
          {'id': 2, 'name': 'API Branch Beta', 'attendance_rate': .87},
        ]
        ..collections['students'] = <Map<String, dynamic>>[]
        ..collections['payments'] = <Map<String, dynamic>>[];
      final store = AppStore.empty(SfRole.ceo);
      syncProductStoreFromApi(session, store);
      addTearDown(session.dispose);
      addTearDown(store.dispose);

      await tester.pumpWidget(
        _host(session, store, BranchComparisonScreen(colors: SfColors.light)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Branch A'), findsOneWidget);
      expect(find.text('Branch B'), findsOneWidget);
      expect(find.text('API Branch Alpha'), findsWidgets);
      expect(find.text('API Branch Beta'), findsWidgets);
      expect(find.byType(AreaChart), findsOneWidget);
      expect(find.byType(ApiDataCard), findsNothing);
      expect(find.text('results'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty branch and event surfaces stay visible and honest', (
    tester,
  ) async {
    _surface(tester);
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client);
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(
        session,
        store,
        const Scaffold(body: BranchesScreen()),
        lang: SfLang.ru,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пока ничего нет'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        session,
        store,
        ActivityHistoryScreen(colors: SfColors.light),
        lang: SfLang.ru,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пока ничего нет'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        session,
        store,
        BranchComparisonScreen(colors: SfColors.light),
        lang: SfLang.ru,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пока ничего нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one branch explains the minimum comparison requirement', (
    tester,
  ) async {
    _surface(tester);
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['branches'] = [
        {'id': 1, 'name': 'Only Branch'},
      ];
    final store = AppStore.empty(SfRole.ceo);
    syncProductStoreFromApi(session, store);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      _host(
        session,
        store,
        BranchComparisonScreen(colors: SfColors.light),
        lang: SfLang.ru,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Для сравнения нужны минимум 2 филиала'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'every live app role opens editable profile with immutable role',
    (tester) async {
      _surface(tester);
      for (final role in SfRole.values) {
        final client = StarforgeApiClient()..configure(token: 'test-session');
        final session = ApiSession(client: client)
          ..me = {
            'id': '${role.name}-5',
            'username': '${role.name}.user',
            'first_name': 'Codex',
            'last_name': role.name,
            'full_name': 'Codex ${role.name}',
            'role': role.name,
            'permission_codes': <String>[],
          };
        final store = AppStore.empty(role);

        await tester.pumpWidget(
          _host(
            session,
            store,
            Scaffold(
              body: ProfileScreen(
                cfg: kRoleConfigs[role]!,
                onSwitchRole: () {},
              ),
            ),
            lang: SfLang.ru,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();

        expect(
          find.byType(EditProfileScreen),
          findsOneWidget,
          reason: role.name,
        );
        expect(
          find.byType(LiveRecordDetailPage),
          findsNothing,
          reason: role.name,
        );
        expect(
          find.byKey(const ValueKey('profile-role-readonly')),
          findsOneWidget,
          reason: role.name,
        );
        expect(find.textContaining('Роль:'), findsOneWidget, reason: role.name);
        expect(find.text('ИМЯ'), findsOneWidget, reason: role.name);
        expect(find.text('ТЕЛЕФОН'), findsOneWidget, reason: role.name);
        expect(tester.takeException(), isNull, reason: role.name);

        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        store.dispose();
      }
    },
  );
}
