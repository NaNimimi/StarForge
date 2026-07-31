import 'package:ceo_manager/api_catalog.dart';
import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_operations_page.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OperationsClient extends StarforgeApiClient {
  _OperationsClient() {
    configure(token: 'operations-session');
  }

  final calls = <({String method, String path, Object? body})>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add((method: method, path: path, body: body));
    return {'accepted': true, 'path': path};
  }
}

Widget _host(ApiSession session, SfRole role, {Widget? child}) {
  final settings = AppSettings();
  return ApiScope(
    session: session,
    child: SettingsScope(
      settings: settings,
      child: AppScope(
        store: AppStore.seed(role),
        child: MaterialApp(
          theme: sfMaterialTheme(SfColors.light, dark: false),
          home: SfTheme(
            colors: SfColors.light,
            child: child ?? LiveApiOperationsPage(role: role),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('CEO executes a previously unexposed checkout endpoint', (
    tester,
  ) async {
    final client = _OperationsClient();
    final session = ApiSession(client: client)
      ..me = {
        'role': 'ceo',
        'permissions': ['*'],
      };
    addTearDown(session.dispose);
    final operation = kPublishedApiOperations.singleWhere(
      (item) =>
          item.method == 'POST' && item.path == '/api/v1/payments/checkout/',
    );

    await tester.pumpWidget(_host(session, SfRole.ceo));
    await tester.enterText(
      find.byKey(const ValueKey('api-operation-search')),
      operation.operationId,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('api-operation-${operation.key}')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('api-operation-${operation.operationId}-body')),
      '{"student_id": 7, "amount": 350000}',
    );
    await tester.tap(
      find
          .byKey(ValueKey('api-operation-${operation.operationId}-submit'))
          .hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(client.calls.single.method, 'POST');
    expect(client.calls.single.path, '/api/v1/payments/checkout/');
    expect(client.calls.single.body, {'student_id': 7, 'amount': 350000});
    expect(find.text('POST выполнен'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Audit API centre remains strictly read-only', (tester) async {
    final session = ApiSession(client: _OperationsClient())
      ..me = {
        'role': 'audit',
        'permissions': ['*'],
      };
    addTearDown(session.dispose);

    await tester.pumpWidget(_host(session, SfRole.audit));
    await tester.pumpAndSettle();

    expect(find.text('DELETE'), findsNothing);
    expect(find.text('POST'), findsNothing);
    expect(find.text('PUT'), findsNothing);
    expect(find.text('PATCH'), findsNothing);
    expect(find.text('GET'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Audit record details never expose mutation controls', (
    tester,
  ) async {
    final session = ApiSession(client: _OperationsClient())
      ..me = {
        'role': 'audit',
        'permissions': ['*'],
      };
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _host(
        session,
        SfRole.audit,
        child: const LiveRecordDetailPage(
          resource: 'forms',
          initial: {'id': 5, 'title': 'Audit survey'},
          title: 'Survey',
          colors: SfColors.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Изменить'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
    expect(find.text('Опубликовать'), findsNothing);
    expect(find.text('Добавить поле'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
