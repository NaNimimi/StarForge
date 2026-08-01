import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/live_pages.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/web_mobile_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PaymentClient extends StarforgeApiClient {
  _PaymentClient(this.payment);

  final Map<String, dynamic> payment;

  @override
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    return ApiPage(
      items: path == kApiResources['payments']
          ? [payment]
          : const <Map<String, dynamic>>[],
      pagination: {
        'page': 1,
        'page_size': 20,
        'total': path == kApiResources['payments'] ? 1 : 0,
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
  }) async {
    if (path == '${kApiResources['payments']}P-42/') return payment;
    return const <String, dynamic>{};
  }
}

Widget _offlineHost(AppStore store) {
  final settings = AppSettings(lang: SfLang.ru);
  return SettingsScope(
    settings: settings,
    child: AppScope(
      store: store,
      child: MaterialApp(
        theme: sfMaterialTheme(SfColors.light, dark: false),
        home: const SfTheme(
          colors: SfColors.light,
          child: Scaffold(body: WebPaymentsPage()),
        ),
      ),
    ),
  );
}

Widget _liveHost(ApiSession session) {
  final settings = AppSettings(lang: SfLang.uz);
  return ApiScope(
    session: session,
    child: SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: sfMaterialTheme(SfColors.light, dark: false),
        home: const SfTheme(
          colors: SfColors.light,
          child: Scaffold(body: LiveRevenueReportPage()),
        ),
      ),
    ),
  );
}

void _useNarrowPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 820);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  test('ApiPaymentDetails tolerates compact and nested payment schemas', () {
    const details = ApiPaymentDetails({
      'id': 'P-42',
      'payment': {
        'amount_paid': '625 000 UZS',
        'payment_method_display': 'Payme',
        'payer_full_name': 'Azizov Anvar',
        'student': {'full_name': 'Azizova Madina'},
        'group_title': '9-B Algebra',
        'teacher_full_name': 'Nigora Karimova',
        'branch_title': 'Yunusobod',
        'transaction_code': 'PAYME-42',
        'comments': 'Iyul oyi',
        'status_display': 'Оплачен',
        'processed_at': '2026-07-24T10:15:00Z',
      },
    });

    expect(details.amount, 625000);
    expect(details.method, 'Payme');
    expect(details.payer, 'Azizov Anvar');
    expect(details.student, 'Azizova Madina');
    expect(details.group, '9-B Algebra');
    expect(details.teacher, 'Nigora Karimova');
    expect(details.branch, 'Yunusobod');
    expect(details.operationNumber, 'PAYME-42');
    expect(details.comment, 'Iyul oyi');
    expect(details.status, 'Оплачен');
    expect(details.date, '2026-07-24');
    expect(details.time, '10:15');
  });

  testWidgets('manager offline payment opens complete detail at 320px', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final store = AppStore.seed(SfRole.manager);
    addTearDown(store.dispose);

    await tester.pumpWidget(_offlineHost(store));
    await tester.pump(const Duration(milliseconds: 900));

    final payment = find.byKey(
      ValueKey('offline-payment-${store.ledger.first.id}'),
    );
    await _scrollTo(tester, payment);
    await tester.tap(payment);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(LedgerEntryScreen), findsOneWidget);
    for (final label in const [
      'Sana',
      'Время',
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
    expect(find.text(store.ledger.first.payerName), findsOneWidget);
    expect(find.text(store.ledger.first.transactionNumber), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager live payment opens detail route at 320px', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final now = DateTime.now();
    final payment = <String, dynamic>{
      'id': 'P-42',
      'name': 'Iyul uchun to‘lov',
      'amount': 625000,
      'payment_method': 'Payme',
      'payer': {'full_name': 'Azizov Anvar'},
      'student': {'full_name': 'Azizova Madina'},
      'group': {'name': '9-B Algebra'},
      'teacher': {'full_name': 'Nigora Karimova'},
      'branch': {'name': 'Yunusobod'},
      'transaction_code': 'PAYME-42',
      'comment': 'Iyul oyi',
      'status': 'accepted',
      'paid_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    };
    final session = ApiSession(client: _PaymentClient(payment))
      ..collections['payments'] = [payment];
    addTearDown(session.dispose);

    await tester.pumpWidget(_liveHost(session));
    await tester.pumpAndSettle();

    final paymentCard = find.byKey(const ValueKey('live-payments-P-42'));
    await _scrollTo(tester, paymentCard);
    await tester.tap(paymentCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(LiveRecordDetailPage), findsOneWidget);
    expect(find.text('To‘lov tafsiloti'), findsOneWidget);
    expect(find.text('Sana'), findsOneWidget);
    expect(find.text('Vaqt'), findsOneWidget);
    expect(find.text('Summa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
