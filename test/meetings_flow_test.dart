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
  testWidgets('meetings give a manager agenda, RSVP and reminder actions', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.manager);
    await tester.pumpWidget(
      _host(store, MeetingsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jamoa ritmi nazorat ostida'), findsOneWidget);
    expect(find.text('Haftalik filial yig‘ilishi'), findsOneWidget);
    expect(find.text('12/16 tasdiqladi · Butun filial · 16'), findsOneWidget);

    await tester.tap(find.text('Haftalik filial yig‘ilishi'));
    await tester.pumpAndSettle();
    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    expect(find.text('KUN TARTIBI'), findsOneWidget);
    expect(find.text('Davomat va to‘lovlar bo‘yicha yakun'), findsOneWidget);

    await tester.tap(find.text('Подготовить напоминание'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('meeting-reminder-draft')),
      findsOneWidget,
    );
    expect(
      find.textContaining('отправка не выполняется автоматически'),
      findsOneWidget,
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(find.text('Черновик готов'), findsOneWidget);
    expect(store.activities.first.title, 'Yig‘ilish eslatmasi tayyorlandi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('meetings filters completed work without horizontal scrolling', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await tester.pumpWidget(
      _host(store, MeetingsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yakunlangan'));
    await tester.pumpAndSettle();

    expect(find.text('Yangi o‘qituvchilar treningi'), findsOneWidget);
    expect(find.text('Haftalik filial yig‘ilishi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meeting form refuses an incomplete schedule', (tester) async {
    final store = AppStore.seed(SfRole.manager);
    await tester.pumpWidget(
      _host(store, MeetingsWorkspaceScreen(colors: SfColors.light)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MeetingCreateScreen), findsOneWidget);

    await tester.tap(find.text('Schedule and notify'));
    await tester.pump();
    expect(find.text('Majburiy maydon'), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
