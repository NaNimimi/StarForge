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
      debugShowCheckedModeBanner: false,
      home: SfTheme(colors: SfColors.light, child: child),
    ),
  ),
);

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpNarrow(
  WidgetTester tester,
  AppStore store,
  Widget child,
) async {
  _useNarrowPhone(tester);
  await tester.pumpWidget(_host(store, child));
  await tester.pump(const Duration(milliseconds: 900));
  expect(
    tester.takeException(),
    isNull,
    reason: '${child.runtimeType} must render at 320 logical pixels',
  );
}

void main() {
  testWidgets('chat top bar and reaction chooser fit 320px', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      ChatScreen(threadIdx: 0, colors: SfColors.light),
    );

    expect(find.byKey(const ValueKey('chat-profile-header')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    final firstMessage = store.threads.first.messages.first.text;
    final bubbleText = find.text(firstMessage).hitTestable();
    expect(bubbleText, findsOneWidget);
    await tester.longPress(bubbleText);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.text('😮'), findsOneWidget);
    expect(find.text('😢'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat attachment chooser exposes all requested sources', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      ChatScreen(threadIdx: 0, colors: SfColors.light),
    );
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Фото'), findsOneWidget);
    expect(find.text('Видео'), findsOneWidget);
    expect(find.text('Камера'), findsWidgets);
    expect(find.text('Документ'), findsOneWidget);
    expect(find.text('Файл'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat profile contains the complete requested information', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      ChatScreen(threadIdx: 0, colors: SfColors.light),
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-profile-header')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatCabinetScreen), findsOneWidget);
    for (final label in const [
      'Full name',
      'Phone number',
      'Department',
      'Должность',
      'Дата регистрации',
      'Написать',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Статистика'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group detail and CEO analytics fit 320px', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    final student = store.students.first;
    final profile = studentProfile(student);
    final group = GroupInfo(
      student.group,
      profile.branch,
      profile.level,
      studentTeacher(student),
      'Du·Cho·Ju · 10:00',
      store.students.where((item) => item.group == student.group).length,
      student.attendance,
      1,
    );
    await _pumpNarrow(
      tester,
      store,
      GroupDetailScreen(group: group, colors: SfColors.light),
    );

    expect(find.text('CEO ANALITIKA', skipOffstage: false), findsOneWidget);
    expect(find.text('Guruh daromadi', skipOffstage: false), findsOneWidget);
    expect(find.text('O‘zlashtirish', skipOffstage: false), findsOneWidget);
    expect(find.text('Davomat', skipOffstage: false), findsWidgets);
    expect(find.text('To‘lov', skipOffstage: false), findsOneWidget);
    expect(find.text('Imtihon', skipOffstage: false), findsOneWidget);
    expect(find.text('Tarix', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher, parent, department and payments pages fit 320px', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    final pages = <Widget>[
      TeachersWorkspaceScreen(colors: SfColors.light),
      ParentsWorkspaceScreen(colors: SfColors.light),
      DepartmentsWorkspaceScreen(colors: SfColors.light),
      const WebPaymentsPage(),
    ];
    for (final page in pages) {
      await tester.pumpWidget(_host(store, page));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.takeException(),
        isNull,
        reason: '${page.runtimeType} overflowed at 320px',
      );
    }
  });

  testWidgets('teacher page has groups and no teacher rating', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      TeachersWorkspaceScreen(colors: SfColors.light),
    );

    expect(find.textContaining('Faol guruhlar'), findsOneWidget);
    expect(find.textContaining('reyting', findRichText: true), findsNothing);
    final teacher = store.staff.firstWhere(
      (member) => teacherGroupsFor(store, member).isNotEmpty,
    );
    final teacherName = find.text(teacher.fullName);
    await tester.ensureVisible(teacherName.first);
    await tester.pumpAndSettle();
    await tester.tap(teacherName.hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.byType(StaffDetailScreen), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -760));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('GURUHLARI', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent card includes required child relationship facts', (
    tester,
  ) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      ParentsWorkspaceScreen(colors: SfColors.light),
    );
    final student = store.students.first;
    final profile = studentProfile(student);
    expect(find.text(profile.fatherName), findsWidgets);
    expect(find.text(studentTeacher(student)), findsWidgets);
    expect(find.textContaining('Boshlagan: ${profile.enrolled}'), findsWidgets);
    expect(find.text('Подробнее'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('department form exposes every requested field', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      DepartmentCreateScreen(colors: SfColors.light),
    );
    for (final label in const [
      'Название департамента',
      'Filial',
      'Статус',
      'Руководитель',
      'Ответственный',
      'Дата создания',
      'Описание',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment detail exposes every requested field', (tester) async {
    final store = AppStore.seed(SfRole.ceo);
    await _pumpNarrow(
      tester,
      store,
      LedgerEntryScreen(entry: store.ledger.first, colors: SfColors.light),
    );
    for (final label in const [
      'Sana',
      'Сумма',
      'Способ оплаты',
      'Кто оплатил',
      'За ученика',
      'Группа',
      'Преподаватель',
      'Филиал',
      'Номер операции',
      'Комментарий',
      'Статус платежа',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
