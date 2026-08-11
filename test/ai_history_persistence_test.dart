import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('AI history survives a new store for the same account', () async {
    final first = AppStore.empty(SfRole.ceo);
    addTearDown(first.dispose);
    await first.bindProfileIdentity('tenant.ceo.42');

    first.addAiUserTurn('Сравни доход филиалов');
    first.addAiAssistantTurn('Серверный ответ');
    first.renameConversation(0, 'Филиалы');
    first.newConversation();
    first.addAiUserTurn('Проверь задолженность');
    await first.flushAiHistory();

    final restored = AppStore.empty(SfRole.ceo);
    addTearDown(restored.dispose);
    await restored.bindProfileIdentity('tenant.ceo.42');

    expect(restored.conversations, hasLength(2));
    expect(restored.activeConv, 0);
    expect(restored.conversations[0].title, 'Проверь задолженность');
    expect(
      restored.conversations[0].turns.single.text,
      'Проверь задолженность',
    );
    expect(restored.conversations[1].title, 'Филиалы');
    expect(restored.conversations[1].turns, hasLength(2));
    expect(restored.conversations[1].turns.last.text, 'Серверный ответ');
  });

  test('AI history is isolated between signed-in accounts', () async {
    final ceo = AppStore.empty(SfRole.ceo);
    addTearDown(ceo.dispose);
    await ceo.bindProfileIdentity('tenant.ceo.42');
    ceo.addAiUserTurn('Секретный отчёт CEO');
    await ceo.flushAiHistory();

    final manager = AppStore.empty(SfRole.manager);
    addTearDown(manager.dispose);
    await manager.bindProfileIdentity('tenant.manager.7');

    expect(manager.conversations, hasLength(1));
    expect(manager.chat, isEmpty);

    manager.addAiUserTurn('Отчёт менеджера');
    await manager.flushAiHistory();

    final ceoRestored = AppStore.empty(SfRole.ceo);
    addTearDown(ceoRestored.dispose);
    await ceoRestored.bindProfileIdentity('tenant.ceo.42');
    expect(ceoRestored.chat.single.text, 'Секретный отчёт CEO');
  });

  test(
    'rename, select and delete persist without losing the active chat',
    () async {
      final first = AppStore.empty(SfRole.audit);
      addTearDown(first.dispose);
      await first.bindProfileIdentity('tenant.audit.9');
      first.addAiUserTurn('Первая проверка');
      first.newConversation();
      first.addAiUserTurn('Вторая проверка');
      first.renameConversation(1, 'Сохранённый аудит');
      first.selectConversation(1);
      first.deleteConversation(0);
      await first.flushAiHistory();

      final restored = AppStore.empty(SfRole.audit);
      addTearDown(restored.dispose);
      await restored.bindProfileIdentity('tenant.audit.9');

      expect(restored.conversations, hasLength(1));
      expect(restored.activeConv, 0);
      expect(restored.conversations.single.title, 'Сохранённый аудит');
      expect(restored.chat.single.text, 'Первая проверка');
    },
  );

  test('corrupt saved history falls back to a clean conversation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile.tenant.ceo.42.ai.v1': '{not json',
    });
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(store.dispose);

    await store.bindProfileIdentity('tenant.ceo.42');

    expect(store.conversations, hasLength(1));
    expect(store.chat, isEmpty);
  });
}
