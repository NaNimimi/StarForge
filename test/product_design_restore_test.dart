import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_data_view.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ApiSession session, AppStore store, Widget child) {
  final settings = AppSettings();
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
}
