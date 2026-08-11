import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AdmissionClient extends StarforgeApiClient {
  _AdmissionClient() {
    configure(token: 'test-session');
  }

  final students = <Map<String, dynamic>>[];
  final parents = <Map<String, dynamic>>[];
  final guardians = <Map<String, dynamic>>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final payload = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    if (method == 'POST' && path == '/api/v1/students/') {
      final record = <String, dynamic>{
        'id': 13,
        'student_id': 'SF-13',
        'full_name': '${payload['first_name']} ${payload['last_name']}',
        ...payload,
      };
      students.add(record);
      return record;
    }
    if (method == 'POST' && path == '/api/v1/parents/') {
      final record = <String, dynamic>{
        'id': 11,
        'full_name': '${payload['first_name']} ${payload['last_name']}',
        ...payload,
      };
      parents.add(record);
      return record;
    }
    if (method == 'POST' && path == '/api/v1/parents/guardians/') {
      final record = <String, dynamic>{'id': 21, ...payload};
      guardians.add(record);
      return record;
    }
    final rows = switch (path) {
      '/api/v1/students/' => students,
      '/api/v1/parents/' => parents,
      '/api/v1/parents/guardians/' => guardians,
      _ => <Map<String, dynamic>>[],
    };
    return {
      'data': rows,
      'pagination': {
        'page': 1,
        'page_size': 200,
        'total': rows.length,
        'pages': 1,
        'has_next': false,
      },
    };
  }
}

void main() {
  testWidgets('parent workspace shows linked and unlinked database parents', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['groups'] = [
        {'id': 7, 'name': 'API Group'},
      ]
      ..collections['students'] = [
        {'id': 13, 'full_name': 'API Student', 'current_cohort': 7},
      ]
      ..collections['parents'] = [
        {'id': 11, 'full_name': 'Linked Parent', 'phone': '+998901111111'},
        {'id': 12, 'full_name': 'Unlinked Parent', 'phone': '+998902222222'},
      ]
      ..collections['guardians'] = [
        {
          'id': 21,
          'parent': 11,
          'parent_name': 'Linked Parent',
          'student': 13,
          'student_name': 'API Student',
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    syncProductStoreFromApi(session, store);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      SettingsScope(
        settings: AppSettings(lang: SfLang.ru),
        child: AppScope(
          store: store,
          child: ApiScope(
            session: session,
            child: MaterialApp(
              theme: sfMaterialTheme(SfColors.light, dark: false),
              home: const ParentsWorkspaceScreen(colors: SfColors.light),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Linked Parent'), findsOneWidget);
    expect(find.text('Unlinked Parent'), findsOneWidget);
    expect(find.textContaining('1 farzand'), findsOneWidget);
    expect(find.textContaining('0 farzand'), findsOneWidget);

    await tester.tap(find.text('Unlinked Parent'));
    await tester.pumpAndSettle();
    expect(find.text('Ученик не привязан'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admission form persists student parent and guardian in API', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = _AdmissionClient();
    final session = ApiSession(client: client)
      ..collections['branches'] = [
        {'id': 5, 'name': 'API Branch'},
      ]
      ..collections['groups'] = <Map<String, dynamic>>[]
      ..collections['students'] = client.students
      ..collections['parents'] = client.parents
      ..collections['guardians'] = client.guardians;
    final store = AppStore.empty(SfRole.ceo);
    syncProductStoreFromApi(session, store);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      SettingsScope(
        settings: AppSettings(lang: SfLang.ru),
        child: AppScope(
          store: store,
          child: ApiScope(
            session: session,
            child: MaterialApp(
              theme: sfMaterialTheme(SfColors.light, dark: false),
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const AdmitStudentScreen(colors: SfColors.light),
                      ),
                    ),
                    child: const Text('Open admission'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open admission'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex');
    await tester.enterText(fields.at(1), 'Student');
    await tester.enterText(fields.at(3), '+998901234567');
    await tester.enterText(fields.at(5), 'Maria Parent');
    await tester.enterText(fields.at(6), '+998907654321');
    await tester.enterText(fields.at(8), 'alex.student');
    await tester.tap(find.text('O‘quvchini yaratish'));
    await tester.pumpAndSettle();

    expect(client.students.single['phone'], '+998901234567');
    expect(client.students.single['gender'], 'm');
    expect(client.parents.single['phone'], '+998907654321');
    expect(client.guardians.single['student'], 13);
    expect(client.guardians.single['parent'], 11);
    expect(session.records('students'), hasLength(1));
    expect(session.records('parents'), hasLength(1));
    expect(session.records('guardians'), hasLength(1));
    expect(find.text('Open admission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
