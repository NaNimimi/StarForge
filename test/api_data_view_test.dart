import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/api_data_view.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/theme.dart';

Widget _host(Widget child, {SfLang lang = SfLang.ru}) => SettingsScope(
  settings: AppSettings(lang: lang),
  child: MaterialApp(
    home: SfTheme(
      colors: SfColors.light,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  test('API field names and scalar values are human-readable', () {
    expect(apiHumanLabel('student_name'), 'Ученик');
    expect(apiHumanLabel('createdAt'), 'Дата создания');
    expect(apiHumanText('paid', fieldKey: 'status'), 'Оплачен');
    expect(
      apiHumanText('2026-07-31T10:15:00Z', fieldKey: 'created_at'),
      contains('31.07.2026'),
    );
  });

  testWidgets('nested maps and lists render as fields, never as JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ApiDataCard(
          title: 'Информация об оплате',
          value: {
            'student_name': 'Анна Каримова',
            'payment_status': 'paid',
            'group': {'name': 'IELTS 18:00', 'is_active': true},
            'payments': [
              {'amount': 450000, 'method': 'cash'},
            ],
          },
        ),
      ),
    );

    expect(find.text('Ученик'), findsOneWidget);
    expect(find.text('Анна Каримова'), findsOneWidget);
    expect(find.text('Статус платежа'), findsOneWidget);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(find.text('Группа'), findsOneWidget);
    expect(find.text('IELTS 18:00'), findsWidgets);
    expect(find.text('Платежи'), findsOneWidget);
    expect(find.textContaining('"student_name"'), findsNothing);
    expect(find.textContaining('{"'), findsNothing);
    expect(find.textContaining('[{'), findsNothing);
  });

  testWidgets('empty API collections show a clear empty state', (tester) async {
    await tester.pumpWidget(
      _host(const ApiDataCard(title: 'История', value: <Object?>[])),
    );

    expect(find.text('Нет записей'), findsOneWidget);
    expect(find.text('0 записей'), findsOneWidget);
  });

  testWidgets('encoded JSON is decoded, sensitive fields are masked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ApiDataCard(
          title: 'Профиль',
          value:
              '{"full_name":"Алишер Турсунов","token":"secret-value",'
              '"meta":"{\\"payment_status\\":\\"paid\\"}"}',
        ),
      ),
    );

    expect(find.text('Алишер Турсунов'), findsOneWidget);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.textContaining('secret-value'), findsNothing);
    expect(find.textContaining('{"'), findsNothing);
  });

  testWidgets('renderer follows Uzbek and English language settings', (
    tester,
  ) async {
    const value = {'student_name': 'Nodira', 'payment_status': 'paid'};

    await tester.pumpWidget(
      _host(
        const ApiDataCard(title: 'Ma’lumot', value: value),
        lang: SfLang.uz,
      ),
    );
    expect(find.text('O‘quvchi'), findsOneWidget);
    expect(find.text('To‘langan'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const ApiDataCard(title: 'Information', value: value),
        lang: SfLang.en,
      ),
    );
    expect(find.text('Student Name'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('renderer fits a 320px phone without raw JSON', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const ApiDataCard(
          title: 'Данные платежа',
          value: {
            'operation_number': 'SF-2026-000123456789',
            'amount': '350000.00',
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('350'), findsWidgets);
    expect(find.textContaining('{"'), findsNothing);
  });
}
