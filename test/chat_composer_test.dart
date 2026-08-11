import 'dart:async';

import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AppStore store, Widget child) => SettingsScope(
  settings: AppSettings(),
  child: AppScope(
    store: store,
    child: MaterialApp(
      home: SfTheme(colors: SfColors.light, child: child),
    ),
  ),
);

Widget _liveHost(AppStore store, ApiSession session, Widget child) =>
    SettingsScope(
      settings: AppSettings(),
      child: ApiScope(
        session: session,
        child: AppScope(
          store: store,
          child: MaterialApp(
            home: SfTheme(colors: SfColors.light, child: child),
          ),
        ),
      ),
    );

class _ChatRecordingClient extends StarforgeApiClient {
  _ChatRecordingClient({this.holdThreadCreation}) {
    configure(token: 'chat-test-session');
  }

  final Completer<void>? holdThreadCreation;
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
    if (method == 'POST' && path == '/api/v1/messaging/threads/') {
      await holdThreadCreation?.future;
      return {'id': 88};
    }
    return <String, dynamic>{'id': 501};
  }

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async =>
      const ApiPage(items: []);
}

void main() {
  testWidgets('chat composer exposes emoji and edits own text message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(store, ChatScreen(threadIdx: 0, colors: SfColors.light)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('chat-emoji-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editable-chat-text-field')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('chat-emoji-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('😀'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-emoji-button')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Первый текст',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Первый текст'), findsOneWidget);

    await tester.longPress(find.text('Первый текст'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Изменить'), findsOneWidget);
    await tester.tap(find.text('Изменить'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Редактирование'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Исправленный текст',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Первый текст'), findsNothing);
    expect(find.text('Исправленный текст'), findsOneWidget);
    expect(find.textContaining('изменено'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student composer has the same emoji and editable input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(
        store,
        StudentChatScreen(
          student: store.students.first,
          colors: SfColors.light,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.byKey(const ValueKey('student-chat-attachment')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-emoji-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editable-chat-text-field')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('chat-emoji-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('🔥'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing student thread sends through nested API without account id',
    (tester) async {
      final store = AppStore.empty(SfRole.ceo)
        ..replaceServerSnapshot(
          threads: [
            ChatThread(
              const Thread(
                'Existing Student',
                'Student',
                '',
                '',
                serverId: '77',
              ),
              [],
            ),
          ],
        );
      const student = Student(
        'Existing Student',
        'API Group',
        0,
        'paid',
        0,
        serverBacked: true,
      );
      final client = _ChatRecordingClient();
      final session = ApiSession(client: client)..messagingSelfUserId = 1;
      addTearDown(store.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _liveHost(
          store,
          session,
          const StudentChatScreen(student: student, colors: SfColors.light),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChatScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('editable-chat-text-field')),
        'Existing thread message',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        client.calls.where(
          (call) =>
              call.method == 'POST' &&
              call.path == '/api/v1/messaging/threads/77/messages/',
        ),
        hasLength(1),
      );
      expect(
        client.calls.where(
          (call) =>
              call.method == 'POST' &&
              call.path == '/api/v1/messaging/threads/',
        ),
        isEmpty,
      );
    },
  );

  testWidgets('double submit creates only one new student thread', (
    tester,
  ) async {
    final gate = Completer<void>();
    final client = _ChatRecordingClient(holdThreadCreation: gate);
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    final store = AppStore.empty(SfRole.ceo);
    const student = Student(
      'New Student',
      'API Group',
      0,
      'paid',
      0,
      serverId: 'student-9',
      serverUserId: '42',
      serverBacked: true,
    );
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        const StudentChatScreen(student: student, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Only once',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(
      client.calls.where(
        (call) =>
            call.method == 'POST' && call.path == '/api/v1/messaging/threads/',
      ),
      hasLength(1),
    );

    gate.complete();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      client.calls.where(
        (call) => call.method == 'POST' && call.path.endsWith('/messages/'),
      ),
      hasLength(1),
    );
  });
}
