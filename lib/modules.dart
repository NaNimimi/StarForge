import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';

// Shared section header inside a scrolling module body.
Widget _eyebrow(BuildContext context, String text) {
  final c = SfTheme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: SfType.ui,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: c.muted,
      ),
    ),
  );
}

const _mPad = EdgeInsets.fromLTRB(16, 14, 16, 24);

Widget _moduleStats(List<Widget> children) => LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth < 360 ? 1 : children.length;
    final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final child in children) SizedBox(width: width, child: child),
      ],
    );
  },
);

// ════════════════════════════════════════════════════════════════════════
// 1. Payments — Click / Payme / Uzum / Naqd
// ════════════════════════════════════════════════════════════════════════
class _Pay {
  final String id;
  final String who;
  final String student;
  final String group;
  final num amount;
  final String channel;
  final String time;
  final String comment;
  final bool ok; // ok | pending
  const _Pay({
    required this.id,
    required this.who,
    required this.student,
    required this.group,
    required this.amount,
    required this.channel,
    required this.time,
    this.comment = '',
    this.ok = true,
  });
}

const _payments = [
  _Pay(
    id: 'PAY-2401',
    who: 'Azizova Madina',
    student: 'Azizova Madina',
    group: 'IELTS B2',
    amount: 600000,
    channel: 'Payme',
    time: '09:14',
  ),
  _Pay(
    id: 'PAY-2402',
    who: 'Halimova Zilola',
    student: 'Halimova Zilola',
    group: 'Algebra 9-B',
    amount: 600000,
    channel: 'Click',
    time: '09:02',
  ),
  _Pay(
    id: 'PAY-2403',
    who: 'Ibragimov Anvar',
    student: 'Ibragimov Sardor',
    group: 'Fizika 10-V',
    amount: 600000,
    channel: 'Naqd',
    time: 'Kecha',
    comment: 'Kassa orqali qabul qilindi',
  ),
  _Pay(
    id: 'PAY-2404',
    who: "G'aniyev Jasur",
    student: "G'aniyev Jasur",
    group: 'CEFR B2',
    amount: 300000,
    channel: 'Uzum',
    time: 'Kecha',
    ok: false,
  ),
  _Pay(
    id: 'PAY-2405',
    who: 'Davronova Malika',
    student: 'Davronova Sevinch',
    group: 'IELTS B2',
    amount: 600000,
    channel: 'Payme',
    time: '2 kun',
  ),
];

class PaymentsScreen extends StatefulWidget {
  final SfColors colors;
  const PaymentsScreen({super.key, required this.colors});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _filters = ['Hammasi', 'Click', 'Payme', 'Uzum', 'Naqd'];
  late final List<_Pay> _items = List<_Pay>.of(_payments);
  int sel = 0;

  Future<void> _acceptPayment() async {
    final payment = await showModalBottomSheet<_Pay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          SfTheme(colors: widget.colors, child: const _PaymentFormSheet()),
    );
    if (payment == null || !mounted) return;
    setState(() {
      _items.insert(0, payment);
      sel = 0;
    });
    sfSnack(
      context,
      "✓ To'lov qabul qilindi · ${fmtMoneyShort(payment.amount)}",
      bg: widget.colors.success,
    );
  }

  void _openPayment(_Pay payment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: widget.colors,
        child: _PaymentDetailSheet(payment: payment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final list = sel == 0
        ? _items
        : _items.where((p) => p.channel == _filters[sel]).toList();
    final collected = _items
        .where((p) => p.ok)
        .fold<num>(0, (s, p) => s + p.amount);
    return SfScaffold(
      colors: c,
      title: "To'lovlar",
      body: ListView(
        padding: _mPad,
        children: [
          _moduleStats([
            SfStatTile('Bugun yig‘ildi', fmtMoneyShort(collected), c.success),
            SfStatTile('Qarzdorlik', '84m', c.danger),
            SfStatTile("To'lovlar", '${_items.length}', c.ink),
          ]),
          const SizedBox(height: 14),
          SfSelectChips(
            items: _filters,
            selected: sel,
            onSelect: (i) => setState(() => sel = i),
          ),
          const SizedBox(height: 12),
          SfCard(
            child: Column(
              children: [
                const SfCardHeader('So‘nggi to‘lovlar'),
                for (int i = 0; i < list.length; i++)
                  InkWell(
                    key: ValueKey('module-payment-${list[i].id}'),
                    onTap: () => _openPayment(list[i]),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: i < list.length - 1
                              ? BorderSide(color: c.border)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          SfAvatar(name: list[i].who, size: 34),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  list[i].who,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.surface2,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        list[i].channel,
                                        style: TextStyle(
                                          fontFamily: SfType.ui,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: c.ink2,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      list[i].time,
                                      style: TextStyle(
                                        fontFamily: SfType.ui,
                                        fontSize: 10,
                                        color: c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${fmtMoneyShort(list[i].amount)}',
                                style: TextStyle(
                                  fontFamily: SfType.mono,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.success,
                                ),
                              ),
                              Pill(
                                list[i].ok ? 'Qabul' : 'Kutilmoqda',
                                tone: list[i].ok
                                    ? PillTone.success
                                    : PillTone.warn,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.add_rounded,
          label: "To'lov qabul qilish",
          primary: true,
          onTap: _acceptPayment,
        ),
      ),
    );
  }
}

class _PaymentFormSheet extends StatefulWidget {
  const _PaymentFormSheet();

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final _form = GlobalKey<FormState>();
  final _payer = TextEditingController();
  final _student = TextEditingController();
  final _amount = TextEditingController();
  final _comment = TextEditingController();
  String _group = 'IELTS B2';
  String _channel = 'Click';

  @override
  void dispose() {
    _payer.dispose();
    _student.dispose();
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Maydonni to‘ldiring' : null;

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      _Pay(
        id: 'PAY-${now.microsecondsSinceEpoch}',
        who: _payer.text.trim(),
        student: _student.text.trim(),
        group: _group,
        amount: int.parse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')),
        channel: _channel,
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        comment: _comment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "To'lov qabul qilish",
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('payment-payer-field'),
                    controller: _payer,
                    decoration: const InputDecoration(labelText: 'Kim to‘ladi'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-student-field'),
                    controller: _student,
                    decoration: const InputDecoration(
                      labelText: 'Qaysi o‘quvchi uchun',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-amount-field'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Summa'),
                    validator: (value) {
                      final parsed = int.tryParse(
                        (value ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                      );
                      return parsed == null || parsed <= 0
                          ? 'Musbat summa kiriting'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _group,
                    decoration: const InputDecoration(labelText: 'Guruh'),
                    items: const ['IELTS B2', 'Algebra 9-B', 'Fizika 10-V']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _group = value!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('payment-channel-field'),
                    initialValue: _channel,
                    decoration: const InputDecoration(
                      labelText: 'To‘lov usuli',
                    ),
                    items: const ['Click', 'Payme', 'Uzum', 'Naqd']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _channel = value!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _comment,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Izoh · ixtiyoriy',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SfButton(
                    icon: Icons.check_rounded,
                    label: 'Qabul qilish',
                    primary: true,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailSheet extends StatelessWidget {
  const _PaymentDetailSheet({required this.payment});

  final _Pay payment;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final rows = <(String, String)>[
      ('Operatsiya', payment.id),
      ('Kim to‘ladi', payment.who),
      ('O‘quvchi', payment.student),
      ('Guruh', payment.group),
      ('Summa', fmtMoney(payment.amount)),
      ('Usul', payment.channel),
      ('Vaqt', payment.time),
      ('Holat', payment.ok ? 'Qabul qilindi' : 'Kutilmoqda'),
      ('Izoh', payment.comment.isEmpty ? '—' : payment.comment),
    ];
    return Material(
      key: const ValueKey('module-payment-detail'),
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "To'lov tafsilotlari",
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                _ModuleInfoRow(label: row.$1, value: row.$2),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared bottom action bar.
Widget _bottomBar(BuildContext context, SfColors c, Widget child) => Container(
  padding: EdgeInsets.fromLTRB(
    16,
    10,
    16,
    10 + MediaQuery.of(context).padding.bottom,
  ),
  decoration: BoxDecoration(
    color: c.surface,
    border: Border(top: BorderSide(color: c.border)),
  ),
  child: SizedBox(width: double.infinity, child: child),
);

// ════════════════════════════════════════════════════════════════════════
// 2. Printing — queue, layouts, paper accounting
// ════════════════════════════════════════════════════════════════════════
class _PrintJob {
  final String id;
  final String title;
  final String who;
  final int pages;
  final int copies;
  final String layout;
  final _PrintStatus status;
  const _PrintJob({
    required this.id,
    required this.title,
    required this.who,
    required this.pages,
    required this.copies,
    required this.layout,
    this.status = _PrintStatus.queued,
  });

  _PrintJob copyWith({_PrintStatus? status}) => _PrintJob(
    id: id,
    title: title,
    who: who,
    pages: pages,
    copies: copies,
    layout: layout,
    status: status ?? this.status,
  );
}

enum _PrintStatus { queued, completed, cancelled }

const _printJobs = [
  _PrintJob(
    id: 'PRINT-101',
    title: 'Grammar Unit 7',
    who: 'Nigora K.',
    pages: 4,
    copies: 18,
    layout: '2-up · duplex',
  ),
  _PrintJob(
    id: 'PRINT-102',
    title: 'IELTS Listening',
    who: 'Aziz T.',
    pages: 6,
    copies: 24,
    layout: 'duplex',
  ),
  _PrintJob(
    id: 'PRINT-103',
    title: 'Vocabulary set',
    who: 'Nigora K.',
    pages: 2,
    copies: 30,
    layout: '2-up',
  ),
  _PrintJob(
    id: 'PRINT-104',
    title: 'Mock test #3',
    who: 'Qabul',
    pages: 12,
    copies: 15,
    layout: 'duplex',
  ),
];

class PrintingScreen extends StatefulWidget {
  final SfColors colors;
  const PrintingScreen({super.key, required this.colors});

  @override
  State<PrintingScreen> createState() => _PrintingScreenState();
}

class _PrintingScreenState extends State<PrintingScreen> {
  late final List<_PrintJob> _jobs = List<_PrintJob>.of(_printJobs);
  int _filter = 0;

  Future<void> _createJob() async {
    final job = await showModalBottomSheet<_PrintJob>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SfTheme(colors: widget.colors, child: const _PrintJobFormSheet()),
    );
    if (job == null || !mounted) return;
    setState(() {
      _jobs.insert(0, job);
      _filter = 0;
    });
    sfSnack(
      context,
      '✓ "${job.title}" navbatga qo‘shildi',
      bg: widget.colors.success,
    );
  }

  Future<void> _openJob(_PrintJob job) async {
    final action = await showModalBottomSheet<_PrintStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: widget.colors,
        child: _PrintJobDetailSheet(job: job),
      ),
    );
    if (action == null || !mounted) return;
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index < 0) return;
    setState(() => _jobs[index] = _jobs[index].copyWith(status: action));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final visible = _jobs
        .where((job) {
          if (_filter == 1) return job.status == _PrintStatus.queued;
          if (_filter == 2) return job.status == _PrintStatus.completed;
          if (_filter == 3) return job.status == _PrintStatus.cancelled;
          return true;
        })
        .toList(growable: false);
    final completedPages = _jobs
        .where((job) => job.status == _PrintStatus.completed)
        .fold<int>(0, (sum, job) => sum + job.pages * job.copies);
    final queued = _jobs
        .where((job) => job.status == _PrintStatus.queued)
        .length;
    final totalPages = _jobs.fold<int>(0, (s, j) => s + j.pages * j.copies);
    return SfScaffold(
      colors: c,
      title: 'Bosib chiqarish',
      body: ListView(
        padding: _mPad,
        children: [
          _moduleStats([
            SfStatTile('Jami · varaq', '$totalPages', c.ink),
            SfStatTile('Bajarildi', '$completedPages', c.success),
            SfStatTile('Navbatda', '$queued', c.warn),
          ]),
          const SizedBox(height: 14),
          SfSelectChips(
            items: const ['Hammasi', 'Navbatda', 'Tayyor', 'Bekor'],
            selected: _filter,
            onSelect: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          _eyebrow(context, 'Bosib chiqarish navbati'),
          SfCard(
            child: Column(
              children: [
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Bu holatda ish topilmadi',
                      style: TextStyle(fontFamily: SfType.ui, color: c.muted),
                    ),
                  ),
                for (int i = 0; i < visible.length; i++)
                  Builder(
                    builder: (context) {
                      final j = visible[i];
                      final tone = switch (j.status) {
                        _PrintStatus.queued => PillTone.warn,
                        _PrintStatus.completed => PillTone.success,
                        _PrintStatus.cancelled => PillTone.danger,
                      };
                      final label = switch (j.status) {
                        _PrintStatus.queued => 'Navbatda',
                        _PrintStatus.completed => 'Tayyor',
                        _PrintStatus.cancelled => 'Bekor',
                      };
                      return InkWell(
                        key: ValueKey('module-print-${j.id}'),
                        onTap: () => _openJob(j),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: i < visible.length - 1
                                  ? BorderSide(color: c.border)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  size: 17,
                                  color: c.primary,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      j.title,
                                      style: TextStyle(
                                        fontFamily: SfType.ui,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                      ),
                                    ),
                                    Text(
                                      '${j.who} · ${j.layout}',
                                      style: TextStyle(
                                        fontFamily: SfType.ui,
                                        fontSize: 10.5,
                                        color: c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${j.pages * j.copies} v.',
                                    style: TextStyle(
                                      fontFamily: SfType.mono,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                    ),
                                  ),
                                  Pill(label, tone: tone),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Har bir ish xodimga biriktiriladi — qog‘oz sarfi ko‘rinadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 10.5,
              color: c.muted2,
            ),
          ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.add_rounded,
          label: 'Yangi bosib chiqarish ishi',
          primary: true,
          onTap: _createJob,
        ),
      ),
    );
  }
}

class _PrintJobFormSheet extends StatefulWidget {
  const _PrintJobFormSheet();

  @override
  State<_PrintJobFormSheet> createState() => _PrintJobFormSheetState();
}

class _PrintJobFormSheetState extends State<_PrintJobFormSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _who = TextEditingController();
  final _pages = TextEditingController(text: '1');
  final _copies = TextEditingController(text: '1');
  String _layout = 'simplex';

  @override
  void dispose() {
    _title.dispose();
    _who.dispose();
    _pages.dispose();
    _copies.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Maydonni to‘ldiring' : null;

  String? _positive(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < 1 ? '1 dan katta son kiriting' : null;
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      _PrintJob(
        id: 'PRINT-${now.microsecondsSinceEpoch}',
        title: _title.text.trim(),
        who: _who.text.trim(),
        pages: int.parse(_pages.text),
        copies: int.parse(_copies.text),
        layout: _layout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yangi bosib chiqarish ishi',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('print-title-field'),
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Hujjat nomi'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('print-owner-field'),
                    controller: _who,
                    decoration: const InputDecoration(
                      labelText: 'Mas’ul xodim',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('print-pages-field'),
                          controller: _pages,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sahifalar',
                          ),
                          validator: _positive,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('print-copies-field'),
                          controller: _copies,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nusxalar',
                          ),
                          validator: _positive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _layout,
                    decoration: const InputDecoration(labelText: 'Maket'),
                    items: const ['simplex', 'duplex', '2-up', '2-up · duplex']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _layout = value!),
                  ),
                  const SizedBox(height: 16),
                  SfButton(
                    icon: Icons.add_rounded,
                    label: 'Navbatga qo‘shish',
                    primary: true,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrintJobDetailSheet extends StatelessWidget {
  const _PrintJobDetailSheet({required this.job});

  final _PrintJob job;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      key: const ValueKey('module-print-detail'),
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 10),
              _ModuleInfoRow(label: 'ID', value: job.id),
              _ModuleInfoRow(label: 'Mas’ul', value: job.who),
              _ModuleInfoRow(label: 'Maket', value: job.layout),
              _ModuleInfoRow(label: 'Sahifalar', value: '${job.pages}'),
              _ModuleInfoRow(label: 'Nusxalar', value: '${job.copies}'),
              _ModuleInfoRow(
                label: 'Jami varaq',
                value: '${job.pages * job.copies}',
              ),
              if (job.status == _PrintStatus.queued) ...[
                const SizedBox(height: 14),
                Column(
                  children: [
                    SfButton(
                      icon: Icons.check_rounded,
                      label: 'Tayyor',
                      primary: true,
                      onTap: () =>
                          Navigator.of(context).pop(_PrintStatus.completed),
                    ),
                    const SizedBox(height: 8),
                    SfButton(
                      icon: Icons.close_rounded,
                      label: 'Bekor qilish',
                      primary: false,
                      onTap: () =>
                          Navigator.of(context).pop(_PrintStatus.cancelled),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleInfoRow extends StatelessWidget {
  const _ModuleInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontFamily: SfType.ui, color: c.muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 3. Mock exams — AI auto-scoring
// ════════════════════════════════════════════════════════════════════════
class _ExamQuestion {
  final String text;
  final List<String> options;
  final int correct;
  const _ExamQuestion(this.text, this.options, this.correct);
}

class _ExamDefinition {
  final String title;
  final String source;
  final String duration;
  final bool ai;
  final List<_ExamQuestion> questions;
  const _ExamDefinition(
    this.title,
    this.source,
    this.duration,
    this.ai,
    this.questions,
  );
}

const _moduleExams = <_ExamDefinition>[
  _ExamDefinition(
    'IELTS Academic · Full',
    'AI + rasmiy',
    '2 soat 45 daq',
    true,
    [
      _ExamQuestion('Choose the correct synonym for “essential”.', [
        'optional',
        'necessary',
        'ordinary',
        'temporary',
      ], 1),
      _ExamQuestion('Which sentence is grammatically correct?', [
        'She have finished.',
        'She has finish.',
        'She has finished.',
        'She finished has.',
      ], 2),
      _ExamQuestion('A strong IELTS introduction should first…', [
        'copy the prompt',
        'paraphrase the topic',
        'list every example',
        'add a quotation',
      ], 1),
    ],
  ),
  _ExamDefinition('CEFR B2 · Reading', 'AI generatsiya', '60 daqiqa', true, [
    _ExamQuestion('“Despite the rain” expresses…', [
      'cause',
      'contrast',
      'time',
      'purpose',
    ], 1),
    _ExamQuestion(
      'Choose the best heading: a text about reducing city traffic.',
      ['Urban mobility solutions', 'Ancient roads', 'Weather changes', 'Food'],
      0,
    ),
    _ExamQuestion('An inference is…', [
      'an exact quote',
      'a conclusion from evidence',
      'a title',
      'a translation',
    ], 1),
  ]),
  _ExamDefinition('IELTS Writing Task 2', 'AI baholash', '40 daqiqa', true, [
    _ExamQuestion('A thesis statement should…', [
      'state the writer’s position',
      'repeat the title',
      'contain every example',
      'be a question only',
    ], 0),
    _ExamQuestion('Which connector introduces contrast?', [
      'Furthermore',
      'However',
      'Therefore',
      'For example',
    ], 1),
    _ExamQuestion('A body paragraph needs a topic sentence and…', [
      'unrelated facts',
      'supporting evidence',
      'a new title',
      'no conclusion',
    ], 1),
  ]),
  _ExamDefinition('Listening · Set 4', 'Rasmiy', '30 daqiqa', false, [
    _ExamQuestion('Before listening, the learner should…', [
      'ignore the questions',
      'predict likely answers',
      'close the task',
      'translate every word',
    ], 1),
    _ExamQuestion('A distractor is…', [
      'the correct answer',
      'misleading information',
      'the audio title',
      'a pause',
    ], 1),
    _ExamQuestion('Answers should follow the stated…', [
      'word limit',
      'font',
      'page color',
      'accent',
    ], 0),
  ]),
];

class ExamsScreen extends StatefulWidget {
  final SfColors colors;
  const ExamsScreen({super.key, required this.colors});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final Map<int, int> _scores = <int, int>{};

  Future<void> _startExam(int index) async {
    final score = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SfTheme(
          colors: widget.colors,
          child: _ExamSessionScreen(
            exam: _moduleExams[index],
            colors: widget.colors,
          ),
        ),
      ),
    );
    if (score != null && mounted) setState(() => _scores[index] = score);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'Mock imtihonlar',
      body: ListView(
        padding: _mPad,
        children: [
          // AI auto-scoring showcase
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: c.aiBg,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: c.aiBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SfAiBadge('AI baholash'),
                    const SizedBox(height: 8),
                    Text(
                      'Band 7.0',
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.ai,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final b in const [
                  ('Task Response', '7.5'),
                  ('Coherence', '7.0'),
                  ('Lexical', '6.5'),
                  ('Grammar', '7.0'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.$1,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12,
                              color: c.ink2,
                            ),
                          ),
                        ),
                        Text(
                          b.$2,
                          style: TextStyle(
                            fontFamily: SfType.mono,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '“Kuchli argument, ammo ba’zi bog‘lovchilar takrorlangan…”',
                  style: TextStyle(
                    fontFamily: SfType.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 13.5,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _eyebrow(context, 'Mavjud imtihonlar'),
          for (int index = 0; index < _moduleExams.length; index++)
            Builder(
              builder: (context) {
                final e = _moduleExams[index];
                final score = _scores[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: (e.ai ? c.ai : c.muted).withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              e.ai
                                  ? Icons.auto_awesome_rounded
                                  : Icons.description_rounded,
                              size: 18,
                              color: e.ai ? c.ai : c.muted,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            e.title,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            score == null
                                ? '${e.source} · ${e.duration}'
                                : '${e.source} · oxirgi natija $score/${e.questions.length}',
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 10.5,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          key: ValueKey('module-exam-start-$index'),
                          onTap: () => _startExam(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              score == null ? 'Boshlash' : 'Qayta',
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ExamSessionScreen extends StatefulWidget {
  const _ExamSessionScreen({required this.exam, required this.colors});

  final _ExamDefinition exam;
  final SfColors colors;

  @override
  State<_ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<_ExamSessionScreen> {
  int _question = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  void _next() {
    if (_selected == null) return;
    if (_selected == widget.exam.questions[_question].correct) _score++;
    if (_question == widget.exam.questions.length - 1) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _question++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    if (_finished) {
      final percent = (_score / widget.exam.questions.length * 100).round();
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Imtihon natijasi')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              key: const ValueKey('module-exam-result'),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 52, color: c.ai),
                  const SizedBox(height: 12),
                  Text(
                    'Natija: $_score/${widget.exam.questions.length}',
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$percent% · ${percent >= 70 ? 'Muvaffaqiyatli' : 'Takrorlash tavsiya etiladi'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: SfType.ui, color: c.muted),
                  ),
                  const SizedBox(height: 18),
                  SfButton(
                    icon: Icons.check_rounded,
                    label: 'Natijani saqlash',
                    primary: true,
                    onTap: () => Navigator.of(context).pop(_score),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final item = widget.exam.questions[_question];
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(widget.exam.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          LinearProgressIndicator(
            value: (_question + 1) / widget.exam.questions.length,
            backgroundColor: c.surface2,
            color: c.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '${_question + 1}/${widget.exam.questions.length} savol',
            style: TextStyle(fontFamily: SfType.mono, color: c.muted),
          ),
          const SizedBox(height: 12),
          Text(
            item.text,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < item.options.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: ValueKey('module-exam-option-$_question-$index'),
                onTap: () => setState(() => _selected = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: _selected == index ? c.primarySoft : c.surface,
                    border: Border.all(
                      color: _selected == index ? c.primary : c.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selected == index
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: _selected == index ? c.primary : c.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.options[index])),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: _question == widget.exam.questions.length - 1
              ? Icons.flag_rounded
              : Icons.arrow_forward_rounded,
          label: _question == widget.exam.questions.length - 1
              ? 'Yakunlash'
              : 'Keyingi savol',
          primary: true,
          onTap: () {
            if (_selected != null) _next();
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 4. AI speaking partner — IELTS speaking simulator
// ════════════════════════════════════════════════════════════════════════
class SpeakingScreen extends StatefulWidget {
  final SfColors colors;
  const SpeakingScreen({super.key, required this.colors});
  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  bool started = false;
  static const _turns = [
    (false, 'Let’s talk about your hometown. Where are you from?'),
    (true, 'I’m from Namangan, a city in the east of Uzbekistan.'),
    (false, 'What do you like most about living there?'),
    (true, 'The people are very warm, and the food is amazing.'),
    (
      false,
      'Now, describe a skill you would like to learn. You have one minute.',
    ),
    (true, 'I’d like to learn how to edit videos, because…'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'AI suhbatdosh',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.record_voice_over_rounded,
                    size: 22,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IELTS Speaking simulyatori',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        '3 qism · 24/7 · darhol band baho',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!started) ...[
            for (final p in const [
              ('1-qism', 'Interview · tanishuv savollari'),
              ('2-qism', 'Cue card · 2 daqiqa monolog'),
              ('3-qism', 'Discussion · chuqurroq muhokama'),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      p.$1,
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            for (final t in _turns)
              Align(
                alignment: t.$1 ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: t.$1 ? null : LinearGradient(colors: c.aiBg),
                    color: t.$1 ? c.primary : null,
                    border: t.$1 ? null : Border.all(color: c.aiBorder),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontFamily: t.$1 ? SfType.ui : SfType.display,
                      fontStyle: t.$1 ? FontStyle.normal : FontStyle.italic,
                      fontSize: t.$1 ? 13 : 14,
                      height: 1.3,
                      color: t.$1 ? Colors.white : c.ink,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: c.aiBg,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: c.aiBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taxminiy band baho',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.ai,
                          ),
                        ),
                        Text(
                          'Fluency 6.5 · Lexical 7.0 · Grammar 6.5',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 11,
                            color: c.ink2,
                          ),
                        ),
                        Text(
                          'Talaffuz — taxminiy (keyin aniqroq)',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '6.5',
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: c.ai,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: started ? Icons.refresh_rounded : Icons.mic_rounded,
          label: started ? 'Qaytadan boshlash' : 'Testni boshlash',
          primary: true,
          onTap: () => setState(() => started = !started),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 5. Camera analysis — on-prem lesson insights
// ════════════════════════════════════════════════════════════════════════
class CameraScreen extends StatelessWidget {
  final SfColors colors;
  const CameraScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final rooms = [
      ('101-xona · Algebra', true, 'Tahlil tayyor'),
      ('102-xona · Ingliz', true, 'Tahlil tayyor'),
      ('203-xona · Fizika', false, 'Dars davom etmoqda'),
    ];
    return SfScaffold(
      colors: c,
      title: 'Kamera tahlili',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, size: 18, color: c.success),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "Edge-box binoda · ma'lumot tashqariga chiqmaydi (biometrik qonun)",
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Lesson analysis report
          SfCard(
            child: Column(
              children: [
                const SfCardHeader('Dars tahlili · 102-xona'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      _bar(
                        context,
                        'O‘z vaqtida boshlandi',
                        1.0,
                        c.success,
                        'Ha',
                      ),
                      _bar(context, 'Mavzu qamrovi', 0.86, c.success, '86%'),
                      _bar(context, 'O‘qituvchi faolligi', 0.74, c.warn, '74%'),
                      _bar(context, 'Ijobiy ohang', 0.92, c.success, '92%'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 15, color: c.muted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Audio → transkript → mahalliy LLM tahlili',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _eyebrow(context, 'Xonalar'),
          for (final r in rooms)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 20,
                    color: r.$2 ? c.success : c.muted,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
                  Pill(
                    r.$3,
                    tone: r.$2 ? PillTone.success : PillTone.neutral,
                    dot: true,
                  ),
                ],
              ),
            ),
          Text(
            'Kim ko‘rishini har markaz o‘zi sozlaydi · rozilik + ogohlantirish.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 10.5,
              color: c.muted2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    double v,
    Color color,
    String tag,
  ) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11.5,
                color: c.ink2,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 36,
            child: Text(
              tag,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 6. Rewards — points economy + redemption store
// ════════════════════════════════════════════════════════════════════════
class _Reward {
  final String name;
  final int cost;
  final IconData icon;
  const _Reward(this.name, this.cost, this.icon);
}

const _catalog = [
  _Reward('Ruchka · daftar', 150, Icons.edit_rounded),
  _Reward('Stiker to‘plami', 300, Icons.auto_awesome_rounded),
  _Reward('Termokружka', 1200, Icons.local_cafe_rounded),
  _Reward('CMF / Samsung Buds', 9000, Icons.headphones_rounded),
  _Reward('AirPods', 18000, Icons.headphones_rounded),
];

class RewardsScreen extends StatefulWidget {
  final SfColors colors;
  const RewardsScreen({super.key, required this.colors});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int points = 2450;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'Mukofotlar',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, c.primaryHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const SfStar(size: 30, color: Colors.white),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sizning ballaringiz',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _eyebrow(context, 'Reyting · bu hafta'),
          SfCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: HBars(
                rows: [
                  HBarRow('Madina', 3120, '3120', c.success),
                  HBarRow('Siz', 2450, '2450', c.primary),
                  HBarRow('Jasur', 1980, '1980', c.accent),
                  HBarRow('Sardor', 1600, '1600', c.muted2),
                ],
              ),
            ),
          ),
          _eyebrow(context, 'Do‘kon'),
          for (final r in _catalog)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(r.icon, size: 20, color: c.accentInk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          '${r.cost} ball',
                          style: TextStyle(
                            fontFamily: SfType.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _redeemBtn(context, c, r),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _redeemBtn(BuildContext context, SfColors c, _Reward r) {
    final can = points >= r.cost;
    return GestureDetector(
      onTap: can
          ? () {
              setState(() => points -= r.cost);
              sfSnack(
                context,
                '🎁 "${r.name}" almashtirildi! (-${r.cost} ball)',
                bg: const Color(0xFF4F7B3B),
              );
            }
          : () =>
                sfSnack(context, 'Ball yetarli emas · yana ${r.cost - points}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: can ? c.primary : c.surface2,
          border: can ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          'Almashtirish',
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: can ? c.surface : c.muted,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 7. HR — staff + hiring pipeline
// ════════════════════════════════════════════════════════════════════════
class _HrCandidate {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String note;
  final int stage;
  const _HrCandidate({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.note,
    required this.stage,
  });

  _HrCandidate copyWith({int? stage}) => _HrCandidate(
    id: id,
    name: name,
    role: role,
    phone: phone,
    note: note,
    stage: stage ?? this.stage,
  );
}

const _candidateStages = ['Ariza', 'Suhbat', 'Sinov kuni', 'Qabul qilindi'];

const _initialCandidates = <_HrCandidate>[
  _HrCandidate(
    id: 'HR-101',
    name: 'Kamola R.',
    role: 'Ingliz o‘qituvchisi',
    phone: '+998 90 123 45 67',
    note: 'CEFR C1 sertifikati bor',
    stage: 0,
  ),
  _HrCandidate(
    id: 'HR-102',
    name: 'Bekzod M.',
    role: 'Matematika o‘qituvchisi',
    phone: '+998 91 234 56 78',
    note: 'Suhbat 5-iyun kuni',
    stage: 1,
  ),
  _HrCandidate(
    id: 'HR-103',
    name: 'Sevara T.',
    role: 'Qabul administratori',
    phone: '+998 93 345 67 89',
    note: 'Sinov muddati boshlandi',
    stage: 3,
  ),
];

class HrScreen extends StatefulWidget {
  final SfColors colors;
  const HrScreen({super.key, required this.colors});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  late final List<_HrCandidate> _candidates = List.of(_initialCandidates);

  static const _staff = [
    ('Nigora Karimova', "O'qituvchi · Matematika", '4 yil shartnoma'),
    ('Aziz Tursunov', "O'qituvchi · Ingliz", '2 yil shartnoma'),
    ("Dilnoza Yo'ldosheva", 'Filial menejeri', '3 yil shartnoma'),
    ('Jasur Aliyev', 'Printer operatori', '1 yil shartnoma'),
  ];

  Future<void> _addCandidate() async {
    final candidate = await showModalBottomSheet<_HrCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SfTheme(colors: widget.colors, child: const _CandidateFormSheet()),
    );
    if (candidate == null || !mounted) return;
    setState(() => _candidates.insert(0, candidate));
    sfSnack(
      context,
      '✓ ${candidate.name} HR voronkasiga qo‘shildi',
      bg: widget.colors.success,
    );
  }

  Future<void> _openCandidate(_HrCandidate candidate) async {
    final stage = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: widget.colors,
        child: _CandidateDetailSheet(candidate: candidate),
      ),
    );
    if (stage == null || !mounted) return;
    final index = _candidates.indexWhere((item) => item.id == candidate.id);
    if (index < 0) return;
    setState(() => _candidates[index] = candidate.copyWith(stage: stage));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final interviews = _candidates.where((item) => item.stage == 1).length;
    return SfScaffold(
      colors: c,
      title: 'Xodimlar · HR',
      body: ListView(
        padding: _mPad,
        children: [
          _moduleStats([
            SfStatTile('Xodimlar', '${_staff.length}', c.ink),
            SfStatTile('Nomzodlar', '${_candidates.length}', c.warn),
            SfStatTile('Suhbat', '$interviews', c.primary),
          ]),
          const SizedBox(height: 16),
          _eyebrow(context, 'Ishga olish jarayoni'),
          SfCard(
            child: Column(
              children: [
                for (int i = 0; i < _candidates.length; i++)
                  InkWell(
                    key: ValueKey('module-candidate-${_candidates[i].id}'),
                    onTap: () => _openCandidate(_candidates[i]),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: i < _candidates.length - 1
                              ? BorderSide(color: c.border)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          SfAvatar(name: _candidates[i].name, size: 34),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _candidates[i].name,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                                Text(
                                  _candidates[i].role,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 10.5,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Pill(
                            _candidateStages[_candidates[i].stage],
                            tone: switch (_candidates[i].stage) {
                              0 => PillTone.neutral,
                              1 || 2 => PillTone.warn,
                              _ => PillTone.success,
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _eyebrow(context, 'Jamoa'),
          SfCard(
            child: Column(
              children: [
                for (int i = 0; i < _staff.length; i++)
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: i < _staff.length - 1
                            ? BorderSide(color: c.border)
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      children: [
                        SfAvatar(name: _staff[i].$1, size: 34),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _staff[i].$1,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                _staff[i].$2,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 10.5,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _staff[i].$3,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10,
                            color: c.muted2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.person_add_rounded,
          label: 'Yangi nomzod qo‘shish',
          primary: true,
          onTap: _addCandidate,
        ),
      ),
    );
  }
}

class _CandidateFormSheet extends StatefulWidget {
  const _CandidateFormSheet();

  @override
  State<_CandidateFormSheet> createState() => _CandidateFormSheetState();
}

class _CandidateFormSheetState extends State<_CandidateFormSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Maydonni to‘ldiring' : null;

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _HrCandidate(
        id: 'HR-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        role: _role.text.trim(),
        phone: _phone.text.trim(),
        note: _note.text.trim(),
        stage: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yangi nomzod',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('candidate-name-field'),
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'To‘liq ism'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('candidate-role-field'),
                    controller: _role,
                    decoration: const InputDecoration(labelText: 'Lavozim'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('candidate-phone-field'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Izoh · ixtiyoriy',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SfButton(
                    icon: Icons.person_add_rounded,
                    label: 'Nomzodni qo‘shish',
                    primary: true,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateDetailSheet extends StatefulWidget {
  const _CandidateDetailSheet({required this.candidate});

  final _HrCandidate candidate;

  @override
  State<_CandidateDetailSheet> createState() => _CandidateDetailSheetState();
}

class _CandidateDetailSheetState extends State<_CandidateDetailSheet> {
  late int _stage = widget.candidate.stage;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      key: const ValueKey('module-candidate-detail'),
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.candidate.name,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 10),
              _ModuleInfoRow(label: 'ID', value: widget.candidate.id),
              _ModuleInfoRow(label: 'Lavozim', value: widget.candidate.role),
              _ModuleInfoRow(label: 'Telefon', value: widget.candidate.phone),
              _ModuleInfoRow(
                label: 'Izoh',
                value: widget.candidate.note.isEmpty
                    ? '—'
                    : widget.candidate.note,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('candidate-stage-field'),
                initialValue: _stage,
                decoration: const InputDecoration(labelText: 'Bosqich'),
                items: [
                  for (int index = 0; index < _candidateStages.length; index++)
                    DropdownMenuItem(
                      value: index,
                      child: Text(_candidateStages[index]),
                    ),
                ],
                onChanged: (value) => setState(() => _stage = value!),
              ),
              const SizedBox(height: 16),
              SfButton(
                icon: Icons.save_rounded,
                label: 'Bosqichni saqlash',
                primary: true,
                onTap: () => Navigator.of(context).pop(_stage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 8. Rule book — role-filtered policy acknowledgment
// ════════════════════════════════════════════════════════════════════════
class RuleBookScreen extends StatefulWidget {
  final SfColors colors;
  const RuleBookScreen({super.key, required this.colors});
  @override
  State<RuleBookScreen> createState() => _RuleBookScreenState();
}

class _RuleBookScreenState extends State<RuleBookScreen> {
  bool accepted = false;
  static const _sections = [
    (
      '1. Umumiy qoidalar',
      'Markaz hududida hurmat va xavfsizlik. Har bir xodim va o‘quvchi ushbu qoidalarga amal qiladi.',
    ),
    (
      '2. Davomat',
      'Darsga o‘z vaqtida kelish. Kechikish va yo‘qlik tizimda qayd etiladi.',
    ),
    (
      '3. To‘lovlar',
      'To‘lov muddati har oyning boshida. Kechiktirish so‘rovini ilova orqali yuborish mumkin.',
    ),
    (
      '4. Xulq-atvor',
      'Haqorat, bullying va nojo‘ya xatti-harakatlar taqiqlanadi (o‘zbek/rus/ingliz).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'Qoidalar kitobi',
      body: ListView(
        padding: _mPad,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Text(
                'Versiya 2.1 · rolingiz uchun',
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in _sections)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$1,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.$2,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      height: 1.4,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
          if (accepted)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 20, color: c.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Qabul qilindi · audit jurnaliga yozildi',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: accepted ? Icons.check_circle_rounded : null,
          label: accepted ? 'Qabul qilingan' : 'O‘qib chiqdim va qabul qilaman',
          primary: !accepted,
          onTap: () {
            if (accepted) return;
            setState(() => accepted = true);
            sfSnack(
              context,
              '✓ Qoidalar qabul qilindi',
              bg: const Color(0xFF4F7B3B),
            );
          },
        ),
      ),
    );
  }
}
