import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AiClient extends StarforgeApiClient {
  _AiClient(this.response);

  final Object response;
  String? method;
  String? path;
  Object? body;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    return response;
  }
}

Widget _host(AppStore store, Widget child, {ApiSession? api}) {
  final settings = AppSettings();
  return ApiScope(
    session: api ?? ApiSession(),
    child: SettingsScope(
      settings: settings,
      child: AppScope(
        store: store,
        child: MaterialApp(
          home: SfTheme(
            colors: SfColors.light,
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AI honesty and backend contract', () {
    test(
      'connected AI fails honestly when prompt POST is not published',
      () async {
        final client = _AiClient({'answer': 'Server tahlili'});
        client.configure(token: 'test-session');
        final session = ApiSession(client: client);
        addTearDown(session.dispose);

        await expectLater(
          session.requestAi('Daromadni tahlil qil'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.status, 'status', 501)
                .having(
                  (error) => error.code,
                  'code',
                  'ai_prompt_endpoint_not_published',
                ),
          ),
        );
        expect(client.method, isNull);
        expect(client.path, isNull);
        expect(client.body, isNull);
      },
    );

    test('offline store never invents an AI answer', () {
      final store = AppStore.seed(SfRole.ceo);
      addTearDown(store.dispose);

      store.sendChat('Daromad prognozi');

      expect(store.chat, hasLength(2));
      expect(store.chat.last.text, contains('AI ещё не подключен'));
      expect(store.chat.last.text, isNot(contains('1.34')));
    });

    testWidgets('offline AI UI submits and explains that AI is not connected', (
      tester,
    ) async {
      final store = AppStore.seed(SfRole.ceo);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        _host(store, AiScreen(cfg: kRoleConfigs[SfRole.ceo]!)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Тестовый вопрос');
      await tester.tap(find.byKey(const ValueKey('ai-send-button')));
      await tester.pumpAndSettle();

      // The prompt appears in the conversation and as its generated history
      // title, which is the intended post-send state.
      expect(find.text('Тестовый вопрос'), findsWidgets);
      expect(find.textContaining('AI ещё не подключен'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('group productivity state', () {
    test('notes, exams, reminders and pins persist in the shared store', () {
      final store = AppStore.seed(SfRole.ceo);
      addTearDown(store.dispose);

      store.addGroupNote('Ingliz B2', 'Ota-onalar yig‘ilishi');
      store.addGroupExam('Ingliz B2', 'Speaking mock', DateTime(2026, 8, 2));
      store.saveGroupDebtReminder('Ingliz B2');
      store.togglePinnedGroup('Ingliz B2');

      expect(
        store.notesForGroup('Ingliz B2').single.text,
        contains('yig‘ilishi'),
      );
      expect(store.examsForGroup('Ingliz B2').single.title, 'Speaking mock');
      expect(store.groupDebtReminders, contains('Ingliz B2'));
      expect(store.pinnedGroups, contains('Ingliz B2'));
    });

    testWidgets('group status summary has four working filters', (
      tester,
    ) async {
      final store = AppStore.seed(SfRole.ceo);
      addTearDown(store.dispose);
      store.extraGroups.add(
        const ManagedGroup(
          name: 'Pauzadagi guruh',
          branch: 'Yunusobod',
          teacher: 'Nigora Karimova',
          schedule: 'Du · 10:00',
          level: 'B1',
          status: 'paused',
        ),
      );
      store.extraGroups.add(
        const ManagedGroup(
          name: 'Yopilgan guruh',
          branch: 'Chilonzor',
          teacher: 'Madina Halimova',
          schedule: 'Se · 14:00',
          level: 'A2',
          status: 'closed',
        ),
      );

      await tester.pumpWidget(_host(store, const GroupsScreen()));
      await tester.pumpAndSettle();

      for (final label in const ['Jami', 'Faol', 'Pauzada', 'Yopilgan']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Pauzada'));
      await tester.pump();
      expect(find.text('Pauzadagi guruh'), findsOneWidget);
      expect(find.text('Yopilgan guruh'), findsNothing);

      await tester.tap(find.text('Yopilgan'));
      await tester.pump();
      expect(find.text('Yopilgan guruh'), findsOneWidget);
      expect(find.text('Pauzadagi guruh'), findsNothing);

      await tester.tap(find.text('Faol'));
      await tester.pump();
      expect(find.text('Yopilgan guruh'), findsNothing);
      expect(find.text('Pauzadagi guruh'), findsNothing);

      await tester.tap(find.text('Jami'));
      await tester.pump();
      expect(find.text('Pauzadagi guruh'), findsOneWidget);
      expect(find.text('Yopilgan guruh'), findsOneWidget);
    });

    testWidgets('group detail exposes report formats and date presets', (
      tester,
    ) async {
      final store = AppStore.seed(SfRole.ceo);
      addTearDown(store.dispose);
      final student = store.students.first;
      final group = GroupInfo(
        student.group,
        studentProfile(student).branch,
        studentProfile(student).level,
        studentTeacher(student),
        'Du·Cho·Ju · 10:00',
        store.studentsForGroup(student.group).length,
        student.attendance,
        0,
      );

      await tester.pumpWidget(
        _host(store, GroupDetailScreen(group: group, colors: SfColors.light)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('group-report-export')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-report-export')));
      await tester.pumpAndSettle();
      expect(find.text('CSV hisobot'), findsOneWidget);
      expect(find.text('HTML hisobot'), findsOneWidget);
      await tester.tapAt(const Offset(10, 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tezkor davr'));
      await tester.pumpAndSettle();
      expect(find.text('Oxirgi 7 kun'), findsOneWidget);
      expect(find.text('Oxirgi 30 kun'), findsOneWidget);
      expect(find.text('Oxirgi 90 kun'), findsOneWidget);
    });
  });
}
