import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'server chat history is restored immediately for the same account',
    () async {
      final first = AppStore.empty(SfRole.ceo);
      addTearDown(first.dispose);
      await first.bindProfileIdentity('tenant.staff.10');
      first.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread(
              'Aziz Rustamov',
              'Student',
              'Second message',
              '15:53',
              serverId: '1209',
              participantIds: ['10', '11'],
            ),
            [
              ChatMsg(
                'First message',
                mine: false,
                serverId: '19290',
                createdAt: DateTime.utc(2026, 8, 13, 10, 0),
              ),
              ChatMsg(
                '',
                mine: true,
                kind: ChatMessageKind.voice,
                serverId: '19292',
                createdAt: DateTime.utc(2026, 8, 13, 10, 1),
                attachmentKeys: const [
                  'starforge/messaging/messages/19292/voice.m4a',
                ],
              ),
            ],
          ),
        ],
      );
      await first.flushChatHistory();

      final restored = AppStore.empty(SfRole.ceo);
      addTearDown(restored.dispose);
      await restored.bindProfileIdentity('tenant.staff.10');

      expect(restored.threads, hasLength(1));
      expect(restored.threads.single.meta.serverId, '1209');
      expect(restored.threads.single.messages, hasLength(2));
      expect(restored.threads.single.messages.last.kind, ChatMessageKind.voice);
      expect(
        restored.threads.single.messages.last.attachmentKeys.single,
        contains('19292'),
      );
    },
  );

  test(
    'cached transcript survives a lightweight thread-list refresh',
    () async {
      final store = AppStore.empty(SfRole.ceo);
      addTearDown(store.dispose);
      await store.bindProfileIdentity('tenant.staff.10');
      store.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread(
              'Aziz',
              'Student',
              'Cached',
              '15:50',
              serverId: '1209',
            ),
            [
              ChatMsg(
                'Cached',
                mine: false,
                serverId: '1',
                createdAt: DateTime.utc(2026, 8, 13, 9, 0),
              ),
            ],
          ),
        ],
      );
      store.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread(
              'Aziz Rustamov',
              'Student',
              'New',
              '15:55',
              serverId: '1209',
            ),
            [
              ChatMsg(
                'New',
                mine: true,
                serverId: '2',
                createdAt: DateTime.utc(2026, 8, 13, 10, 0),
              ),
            ],
          ),
        ],
      );

      expect(store.threads.single.meta.name, 'Aziz Rustamov');
      expect(store.threads.single.messages.map((message) => message.serverId), [
        '1',
        '2',
      ]);
    },
  );

  test('switching account clears the previous in-memory transcript', () async {
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(store.dispose);
    await store.bindProfileIdentity('tenant.staff.10');
    store.replaceServerSnapshot(
      threads: [
        ChatThread(
          const Thread('Private A', 'Student', '', '', serverId: '1209'),
          [ChatMsg('Only account A', mine: false, serverId: '1')],
        ),
      ],
    );
    await store.flushChatHistory();

    await store.bindProfileIdentity('tenant.staff.2005');

    expect(store.threads, isEmpty);
  });

  test(
    'accepted server message replaces matching optimistic cached message',
    () async {
      final store = AppStore.empty(SfRole.ceo);
      addTearDown(store.dispose);
      await store.bindProfileIdentity('tenant.staff.10');
      final sentAt = DateTime.utc(2026, 8, 13, 10, 0);
      store.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Aziz', 'Student', '', '', serverId: '1209'),
            [
              ChatMsg(
                '',
                mine: true,
                kind: ChatMessageKind.voice,
                path: '/local/voice.m4a',
                createdAt: sentAt,
                delivery: ChatDeliveryState.failed,
              ),
            ],
          ),
        ],
      );
      store.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Aziz', 'Student', '', '', serverId: '1209'),
            [
              ChatMsg(
                '',
                mine: true,
                kind: ChatMessageKind.voice,
                serverId: '19292',
                createdAt: sentAt.add(const Duration(seconds: 3)),
                attachmentKeys: const ['server/voice.m4a'],
              ),
            ],
          ),
        ],
      );

      expect(store.threads.single.messages, hasLength(1));
      expect(store.threads.single.messages.single.serverId, '19292');
    },
  );

  test(
    'draft, failed delivery, reactions and tombstones survive restart',
    () async {
      final first = AppStore.empty(SfRole.ceo);
      addTearDown(first.dispose);
      await first.bindProfileIdentity('api.tenant.user.10');
      final pending = ChatMsg(
        'Retry me',
        mine: true,
        delivery: ChatDeliveryState.sending,
      );
      final reacted = ChatMsg(
        'Reacted',
        mine: false,
        serverId: '22',
        reaction: '👍',
        reactions: const {'👍': 2},
      );
      final deleted = ChatMsg('Deleted', mine: true, serverId: '23');
      first.replaceServerSnapshot(
        threads: [
          ChatThread(
            const Thread('Cached', 'Student', '', '', serverId: '77'),
            [pending, reacted, deleted],
          ),
        ],
      );
      first.saveThreadDraft(0, 'Per-thread draft');
      first.removeChatMessage(0, deleted.localId, tombstone: true);
      await first.flushChatHistory();

      final restored = AppStore.empty(SfRole.ceo);
      addTearDown(restored.dispose);
      await restored.bindProfileIdentity('api.tenant.user.10');

      expect(restored.draftForThread(0), 'Per-thread draft');
      expect(restored.threads.single.messages, hasLength(2));
      expect(
        restored.threads.single.messages.first.delivery,
        ChatDeliveryState.failed,
      );
      expect(restored.threads.single.messages.last.reactions, {'👍': 2});
      expect(restored.deletedMessageIds, contains('23'));

      restored.mergeThreadMessages(0, [deleted]);
      expect(
        restored.threads.single.messages.where(
          (message) => message.serverId == '23',
        ),
        isEmpty,
      );
    },
  );

  test(
    'polling merge updates a server message without creating duplicates',
    () {
      final store = AppStore.empty(SfRole.ceo);
      addTearDown(store.dispose);
      store.replaceServerSnapshot(
        threads: [
          ChatThread(const Thread('Chat', 'Student', '', '', serverId: '77'), [
            ChatMsg('Before', mine: false, serverId: '5'),
          ]),
        ],
      );

      store.mergeThreadMessages(0, [
        ChatMsg(
          'After',
          mine: false,
          serverId: '5',
          edited: true,
          reactions: const {'❤': 3},
        ),
      ]);
      store.mergeThreadMessages(0, [
        ChatMsg(
          'After',
          mine: false,
          serverId: '5',
          edited: true,
          reactions: const {'❤': 3},
        ),
      ]);

      expect(store.threads.single.messages, hasLength(1));
      expect(store.threads.single.messages.single.text, 'After');
      expect(store.threads.single.messages.single.edited, isTrue);
      expect(store.threads.single.messages.single.reactions, {'❤': 3});

      store.mergeThreadMessages(0, [
        ChatMsg('', mine: false, serverId: '5', deleted: true),
      ]);
      expect(store.threads.single.messages, isEmpty);
      expect(store.deletedMessageIds, contains('5'));
    },
  );
}
