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
}
