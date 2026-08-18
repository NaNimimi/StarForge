import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/web_mobile_pages.dart';
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
  _ChatRecordingClient({this.holdThreadCreation, this.messagingUser}) {
    configure(token: 'chat-test-session');
  }

  final Completer<void>? holdThreadCreation;
  final Map<String, dynamic>? messagingUser;
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
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    calls.add((method: 'GET', path: path, body: query));
    if ((path == '/api/v1/users/' || path == '/api/v1/messaging/contacts/') &&
        messagingUser != null) {
      return ApiPage(items: [messagingUser!]);
    }
    return const ApiPage(items: []);
  }
}

class _ReliableChatClient extends StarforgeApiClient {
  _ReliableChatClient({this.sendGate}) {
    configure(token: 'reliable-chat-session');
  }

  final Completer<void>? sendGate;
  int sendCount = 0;
  int editCount = 0;
  int deleteCount = 0;
  int addReactionCount = 0;
  int removeReactionCount = 0;
  bool failNextSend = false;
  bool failDelete = false;
  bool failEdit = false;
  bool failReaction = false;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (method == 'POST' && path == '/api/v1/messaging/threads/77/messages/') {
      sendCount += 1;
      await sendGate?.future;
      if (failNextSend) {
        failNextSend = false;
        throw const ApiException(
          status: 0,
          message: 'offline',
          requestId: 'send-offline',
        );
      }
      final payload = Map<String, dynamic>.from(body! as Map);
      return <String, dynamic>{
        'id': 900 + sendCount,
        'body': payload['body'],
        'attachments': payload['attachments'],
        'sender': const {'id': 1},
        'created_at': '2026-08-15T10:00:00Z',
      };
    }
    if (method == 'PATCH' && path == '/api/v1/messaging/messages/17/') {
      editCount += 1;
      if (failEdit) {
        throw const ApiException(
          status: 503,
          message: 'edit failed',
          requestId: 'edit-503',
        );
      }
      final payload = Map<String, dynamic>.from(body! as Map);
      return <String, dynamic>{
        'id': 17,
        'body': payload['body'],
        'attachments': const <String>[],
        'sender': const {'id': 1},
        'created_at': '2026-08-15T10:00:00Z',
        'edited_at': '2026-08-15T10:01:00Z',
      };
    }
    if (method == 'DELETE' && path == '/api/v1/messaging/messages/17/') {
      deleteCount += 1;
      if (failDelete) {
        throw const ApiException(
          status: 503,
          message: 'delete failed',
          requestId: 'delete-503',
        );
      }
      return null;
    }
    if (method == 'POST' &&
        path == '/api/v1/messaging/messages/17/reactions/') {
      addReactionCount += 1;
      if (failReaction) {
        throw const ApiException(
          status: 503,
          message: 'reaction failed',
          requestId: 'reaction-503',
        );
      }
      return <String, dynamic>{};
    }
    if (method == 'DELETE' && path.contains('/reactions/')) {
      removeReactionCount += 1;
      return null;
    }
    return <String, dynamic>{};
  }

  @override
  Future<ApiPage> listPage(
    String path, {
    int page = 1,
    int pageSize = 100,
    Map<String, Object?>? query,
  }) {
    throw const ApiException(
      status: 0,
      message: 'refresh offline',
      requestId: 'refresh-offline',
    );
  }
}

class _PaginatedChatClient extends StarforgeApiClient {
  _PaginatedChatClient() {
    configure(token: 'paged-chat-session');
  }

  final List<int> requestedPages = <int>[];

  @override
  Future<ApiPage> listPage(
    String path, {
    int page = 1,
    int pageSize = 100,
    Map<String, Object?>? query,
  }) async {
    requestedPages.add(page);
    final count = page == 1 ? 2 : 50;
    return ApiPage(
      items: List<Map<String, dynamic>>.generate(count, (index) {
        final id = page == 1 ? 900 + index : 1000 + index;
        return <String, dynamic>{
          'id': id,
          'body': 'Message $id',
          'sender': const {'id': 2},
          'created_at':
              '2026-08-15T${(index % 24).toString().padLeft(2, '0')}:00:00Z',
        };
      }),
      pagination: <String, dynamic>{
        'page': page,
        'page_size': 50,
        'pages': 2,
        'total': 52,
        'has_next': page == 1,
      },
    );
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async => <String, dynamic>{};
}

void main() {
  testWidgets(
    'manager contact picker creates a direct teacher chat with first message',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = AppStore.empty(SfRole.manager);
      final client = _ChatRecordingClient(
        messagingUser: const {
          'id': 4,
          'user_id': 4,
          'principal_kind': 'teacher',
          'principal_id': 2,
          'username': 'bodring',
          'display_name': 'Bodring Bording Bording',
        },
      );
      final session = ApiSession(client: client)
        ..messagingSelfUserId = 2004
        ..messagingContacts = const [
          {
            'id': 4,
            'user_id': 4,
            'principal_kind': 'teacher',
            'principal_id': 2,
            'username': 'bodring',
            'display_name': 'Bodring Bording Bording',
          },
        ]
        ..collections['threads'] = const [];
      addTearDown(store.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _liveHost(store, session, const Scaffold(body: WebMessagesPage())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('messages-new-conversation')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('messaging-contact-4')), findsOneWidget);
      expect(find.text('Bodring Bording Bording'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('messaging-contact-4')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('direct-message-draft')),
        'Hello teacher',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('direct-message-create')));
      await tester.pumpAndSettle();

      final create = client.calls.singleWhere(
        (call) =>
            call.method == 'POST' && call.path == '/api/v1/messaging/threads/',
      );
      expect(create.body, {
        'participant_ids': [4],
        'subject': 'Bodring Bording Bording',
        'first_body': 'Hello teacher',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manager teacher chat exposes text voice emoji and reactions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.manager)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread(
              'Bodring Bording Bording',
              'Teacher',
              'Teacher reply',
              '12:00',
              serverId: '77',
              participantIds: ['2004', '4'],
            ),
            [
              ChatMsg(
                'Teacher reply',
                mine: false,
                serverId: '17',
                createdAt: DateTime(2026, 8, 18, 12),
              ),
            ],
          ),
        ],
      );
    final client = _ReliableChatClient();
    final session = ApiSession(client: client)..messagingSelfUserId = 2004;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('chat-emoji-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-voice-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-emoji-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('😀'), findsOneWidget);
    await tester.longPress(find.text('Teacher reply'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('👍'), findsWidgets);
    expect(find.text('❤️'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('Android mp42 voice container uses its signature MIME for upload', () {
    Uint8List mp4Brand(String brand) => Uint8List.fromList([
      0,
      0,
      0,
      24,
      ...'ftyp'.codeUnits,
      ...brand.codeUnits,
      0,
      0,
      0,
      0,
    ]);

    expect(chatContentTypeForBytes('voice.m4a', mp4Brand('mp42')), 'video/mp4');
    expect(chatContentTypeForBytes('voice.m4a', mp4Brand('isom')), 'video/mp4');
    expect(chatContentTypeForBytes('voice.m4a', mp4Brand('M4A ')), 'audio/mp4');
  });

  test(
    'Android voice container is normalized to the M4A audio brand',
    () async {
      final directory = await Directory.systemTemp.createTemp('voice-brand-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/voice.m4a');
      await file.writeAsBytes([
        0,
        0,
        0,
        24,
        ...'ftyp'.codeUnits,
        ...'mp42'.codeUnits,
        0,
        0,
        0,
        0,
      ]);

      expect(await normalizeRecordedM4aBrand(file.path), isTrue);
      final bytes = await file.readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'M4A ');
      expect(chatContentTypeForBytes(file.path, bytes), 'audio/mp4');
    },
  );

  test('isom voice is normalized while an unknown brand is rejected', () async {
    final directory = await Directory.systemTemp.createTemp('voice-brands-');
    addTearDown(() => directory.delete(recursive: true));

    Future<File> recording(String name, String brand) async {
      final file = File('${directory.path}/$name.m4a');
      await file.writeAsBytes([
        0,
        0,
        0,
        24,
        ...'ftyp'.codeUnits,
        ...brand.codeUnits,
        0,
        0,
        0,
        0,
      ]);
      return file;
    }

    final isom = await recording('isom', 'isom');
    expect(await normalizeRecordedM4aBrand(isom.path), isTrue);
    expect(
      String.fromCharCodes((await isom.readAsBytes()).sublist(8, 12)),
      'M4A ',
    );

    final unknown = await recording('unknown', 'qt  ');
    expect(await normalizeRecordedM4aBrand(unknown.path), isFalse);
    expect(
      String.fromCharCodes((await unknown.readAsBytes()).sublist(8, 12)),
      'qt  ',
    );
  });

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
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-send-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-send-action')));
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
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-action')));
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
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-send-action')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-send-action')));
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

  testWidgets(
    'ordinary message is posted once and refresh failure cannot duplicate it',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = AppStore.empty(SfRole.ceo)
        ..replaceServerSnapshot(
          threads: [
            ChatThread(
              const Thread('Student', 'Student', '', '', serverId: '77'),
              [],
            ),
          ],
        );
      final gate = Completer<void>();
      final client = _ReliableChatClient(sendGate: gate);
      final session = ApiSession(client: client)..messagingSelfUserId = 1;
      addTearDown(store.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _liveHost(
          store,
          session,
          ChatScreen(threadIdx: 0, colors: SfColors.light),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const ValueKey('editable-chat-text-field')),
        'Exactly once',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send-action')));
      await tester.tap(find.byKey(const ValueKey('chat-send-action')));
      await tester.pump();

      expect(client.sendCount, 1);
      expect(store.threads.single.messages, hasLength(1));
      expect(
        store.threads.single.messages.single.delivery,
        ChatDeliveryState.sending,
      );

      gate.complete();
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.sendCount, 1);
      expect(store.threads.single.messages, hasLength(1));
      expect(store.threads.single.messages.single.serverId, '901');
      expect(
        store.threads.single.messages.single.delivery,
        ChatDeliveryState.sent,
      );
    },
  );

  testWidgets('offline chat immediately shows cached history and notice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [ChatMsg('Saved while online', mine: false, serverId: '16')],
          ),
        ],
      );
    final client = _ReliableChatClient();
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Saved while online'), findsOneWidget);
    expect(
      find.text('Нет соединения. Показаны сохранённые сообщения'),
      findsOneWidget,
    );
  });

  testWidgets('failed message keeps one row and retry reuses it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [],
          ),
        ],
      );
    final client = _ReliableChatClient()..failNextSend = true;
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Retry once',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-action')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.threads.single.messages, hasLength(1));
    expect(
      store.threads.single.messages.single.delivery,
      ChatDeliveryState.failed,
    );
    await tester.tap(find.byTooltip('Повторить отправку'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.sendCount, 2);
    expect(store.threads.single.messages, hasLength(1));
    expect(
      store.threads.single.messages.single.delivery,
      ChatDeliveryState.sent,
    );
  });

  testWidgets('live edit, reaction toggle and delete mutate one cached row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final original = ChatMsg(
      'Original server text',
      mine: true,
      serverId: '17',
      createdAt: DateTime.utc(2026, 8, 15, 10),
    );
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [original],
          ),
        ],
      );
    final client = _ReliableChatClient();
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    await tester.longPress(find.text('Original server text'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Изменить'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Edited server text',
    );
    await tester.tap(find.byKey(const ValueKey('chat-send-action')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(client.editCount, 1);
    expect(store.threads.single.messages, hasLength(1));
    expect(store.threads.single.messages.single.text, 'Edited server text');
    expect(store.threads.single.messages.single.edited, isTrue);

    await tester.longPress(find.text('Edited server text'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('👍').last);
    await tester.pump(const Duration(milliseconds: 150));
    expect(client.addReactionCount, 1);
    expect(store.threads.single.messages.single.reaction, '👍');
    expect(store.threads.single.messages.single.reactions, {'👍': 1});

    await tester.longPress(find.text('Edited server text'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('👍').last);
    await tester.pump(const Duration(milliseconds: 150));
    expect(client.removeReactionCount, 1);
    expect(store.threads.single.messages.single.reaction, isNull);
    expect(store.threads.single.messages.single.reactions, isEmpty);

    await tester.longPress(find.text('Edited server text'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Удалить'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(client.deleteCount, 1);
    expect(store.threads.single.messages, isEmpty);
    expect(store.deletedMessageIds, contains('17'));
  });

  testWidgets('older pages load only after the user scrolls to the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [],
          ),
        ],
      );
    final client = _PaginatedChatClient();
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(client.requestedPages, [1, 2]);

    final list = find.byKey(const ValueKey('chat-message-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scrollable);
    expect(scrollState.position.pixels, greaterThan(1000));
    scrollState.position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.requestedPages, [1, 2, 1]);
    expect(store.threads.single.messages, hasLength(52));
  });

  testWidgets('failed server delete restores the cached message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [ChatMsg('Keep on failure', mine: true, serverId: '17')],
          ),
        ],
      );
    final client = _ReliableChatClient()..failDelete = true;
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.longPress(find.text('Keep on failure'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Удалить'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.deleteCount, 1);
    expect(store.threads.single.messages, hasLength(1));
    expect(store.threads.single.messages.single.text, 'Keep on failure');
    expect(store.deletedMessageIds, isNot(contains('17')));
  });

  testWidgets('failed edit and reaction roll back optimistic state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Student', 'Student', '', '', serverId: '77'),
            [ChatMsg('Stable text', mine: true, serverId: '17')],
          ),
        ],
      );
    final client = _ReliableChatClient()
      ..failEdit = true
      ..failReaction = true;
    final session = ApiSession(client: client)..messagingSelfUserId = 1;
    addTearDown(store.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _liveHost(
        store,
        session,
        ChatScreen(threadIdx: 0, colors: SfColors.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.longPress(find.text('Stable text').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Изменить'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Must roll back',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-action')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.threads.single.messages.single.text, 'Stable text');
    expect(store.threads.single.messages.single.edited, isFalse);

    await tester.longPress(find.text('Stable text').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('👍').last);
    await tester.pump(const Duration(milliseconds: 150));
    expect(store.threads.single.messages.single.reaction, isNull);
    expect(store.threads.single.messages.single.reactions, isEmpty);
  });

  testWidgets('student message never routes through a matching group thread', (
    tester,
  ) async {
    final store = AppStore.empty(SfRole.ceo)
      ..replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread(
              'Student support group',
              'Group',
              '',
              '',
              isGroup: true,
              serverId: '66',
              participantIds: ['1', '42', '50'],
            ),
            [],
          ),
          ChatThread(
            const Thread(
              'Existing Student',
              'Student',
              '',
              '',
              serverId: '77',
              participantIds: ['1', '42'],
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
      username: 'existing.student',
      serverUserId: '42',
      serverBacked: true,
    );
    final client = _ChatRecordingClient(
      messagingUser: const {
        'id': 900,
        'user_id': 42,
        'username': 'existing.student',
        'full_name': 'Existing Student',
      },
    );
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
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(
      find.byKey(const ValueKey('editable-chat-text-field')),
      'Private message',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 150));

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
            call.path == '/api/v1/messaging/threads/66/messages/',
      ),
      isEmpty,
    );
  });

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
      isEmpty,
    );
    final create = client.calls.singleWhere(
      (call) =>
          call.method == 'POST' && call.path == '/api/v1/messaging/threads/',
    );
    expect(create.body, {
      'participant_ids': [42],
      'subject': 'New Student',
      'first_body': 'Only once',
    });
  });

  testWidgets(
    'new student resolves a login stored as phone before creating direct chat',
    (tester) async {
      final client = _ChatRecordingClient(
        messagingUser: {
          'id': 42,
          'phone': 'new.student',
          'full_name': 'New Student',
          'is_active': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      final session = ApiSession(client: client)..messagingSelfUserId = 1;
      final store = AppStore.empty(SfRole.ceo);
      const student = Student(
        'New Student',
        'API Group',
        0,
        'paid',
        0,
        username: 'new.student',
        serverId: 'student-9',
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
      expect(find.text('onlayn'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('editable-chat-text-field')),
        'Hello account',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 150));

      final create = client.calls.singleWhere(
        (call) =>
            call.method == 'POST' && call.path == '/api/v1/messaging/threads/',
      );
      expect(create.body, {
        'participant_ids': [42],
        'subject': 'New Student',
        'first_body': 'Hello account',
      });
    },
  );
}
