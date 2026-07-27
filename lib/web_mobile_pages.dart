import 'package:flutter/material.dart';

import 'data.dart';
import 'reference_ui.dart';
import 'screens.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Mobile compositions of the React console pages.  These pages only project
/// the existing [AppStore] state: their filters, mutation callbacks and detail
/// routes deliberately stay in the original Flutter feature layer.

class WebGroupsPage extends StatefulWidget {
  const WebGroupsPage({super.key});

  @override
  State<WebGroupsPage> createState() => _WebGroupsPageState();
}

class _WebGroupsPageState extends State<WebGroupsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _status = 0;
  int _page = 1;
  int _pageSize = 5;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final groups = _groupRows(store);
    final filtered = groups.where((group) {
      final q = _query.toLowerCase();
      final statusOk = switch (_status) {
        1 => group.status == 'active',
        2 => group.status == 'paused',
        3 => group.debtors > 0,
        _ => true,
      };
      return statusOk &&
          (q.isEmpty ||
              '${group.name} ${group.teacher} ${group.branch}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final active = groups.where((group) => group.status == 'active').length;
    final seats = groups.fold<int>(0, (sum, group) => sum + group.count);
    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visible = filtered
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Material(
      color: c.bg,
      child: Column(
        children: [
          RefLargeHeader(
            eyebrow: '${groups.length} GURUH',
            title: 'Guruhlar',
            subtitle: 'Jadval, sig‘im va o‘quv jarayonini boshqaring',
            actions: [
              RefIconAction(
                icon: Icons.add_rounded,
                tooltip: 'Yangi guruh',
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(GroupCreateScreen(colors: c))),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              children: [
                RefAdaptiveGrid(
                  minCellWidth: 132,
                  children: [
                    RefMetricCard(
                      label: 'Faol guruhlar',
                      value: '$active',
                      icon: Icons.workspaces_rounded,
                      tone: RefMetricTone.primary,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: 'O‘quvchilar',
                      value: '$seats',
                      icon: Icons.groups_rounded,
                      tone: RefMetricTone.success,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: 'Qarzli guruhlar',
                      value: '${groups.where((g) => g.debtors > 0).length}',
                      icon: Icons.flag_rounded,
                      tone: RefMetricTone.warning,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RefSearchField(
                  controller: _search,
                  hint: 'Guruh yoki o‘qituvchi qidirish',
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 1;
                  }),
                  suffix: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                            _page = 1;
                          }),
                          icon: Icon(Icons.close_rounded, color: c.muted),
                        ),
                ),
                const SizedBox(height: 10),
                RefSegmentedControl<int>(
                  values: const [0, 1, 2, 3],
                  selected: _status,
                  labelOf: (value) =>
                      const ['Hammasi', 'Faol', 'Pauzada', 'Qarzdor'][value],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 1;
                  }),
                ),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: 'Guruhlar ro‘yxati',
                  subtitle: '${filtered.length} ta mos natija',
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  _WebEmpty(
                    icon: Icons.workspaces_outline,
                    text: 'Guruh topilmadi',
                  )
                else
                  for (var index = 0; index < visible.length; index++) ...[
                    RefStaggeredReveal(
                      order: index,
                      child: _WebGroupCard(group: visible[index]),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (filtered.isNotEmpty)
                  RefPaginationBar(
                    page: currentPage,
                    pages: pageCount,
                    total: filtered.length,
                    pageSize: _pageSize,
                    onPageChanged: (value) => setState(() => _page = value),
                    onPageSizeChanged: (value) => setState(() {
                      _pageSize = value;
                      _page = 1;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<GroupInfo> _groupRows(AppStore store) {
  final buckets = <String, List<Student>>{};
  for (final student in store.students) {
    buckets.putIfAbsent(student.group, () => []).add(student);
  }
  final groups = <GroupInfo>[];
  var position = 0;
  for (final entry in buckets.entries) {
    final students = entry.value;
    final first = students.first;
    final profile = studentProfile(first);
    final attendance =
        (students.fold<int>(0, (sum, item) => sum + item.attendance) /
                students.length)
            .round();
    const schedules = [
      'Du · Cho · Ju · 10:00',
      'Se · Pa · Sha · 14:00',
      'Du · Cho · Ju · 16:00',
    ];
    groups.add(
      GroupInfo(
        entry.key,
        profile.branch,
        profile.level,
        studentTeacher(first),
        schedules[position++ % schedules.length],
        students.length,
        attendance,
        students.where((student) => student.debt > 0).length,
      ),
    );
  }
  for (final group in store.extraGroups) {
    groups.add(
      GroupInfo.withStatus(
        group.name,
        group.branch,
        group.level,
        group.teacher,
        group.schedule,
        0,
        100,
        0,
        group.status,
      ),
    );
  }
  return groups;
}

class _WebGroupCard extends StatelessWidget {
  const _WebGroupCard({required this.group});

  final GroupInfo group;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final capacity = (group.count / 20 * 100).clamp(4, 100).toDouble();
    final attendanceTone = group.avgAtt >= 92
        ? RefPillTone.success
        : group.avgAtt >= 85
        ? RefPillTone.warning
        : RefPillTone.danger;
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(GroupDetailScreen(group: group, colors: c))),
      borderRadius: RefRadius.lg,
      semanticLabel: group.name,
      child: RefSurfaceCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
        elevated: true,
        child: Column(
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: RefRadius.md,
                  ),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.workspaces_rounded,
                      color: c.primary,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 13.5,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.teacher} · ${group.branch}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 10, color: c.muted),
                      ),
                    ],
                  ),
                ),
                RefPill(label: '${group.avgAtt}%', tone: attendanceTone),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: capacity / 100,
                      backgroundColor: c.surface2,
                      valueColor: AlwaysStoppedAnimation(
                        capacity > 90 ? c.warn : c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${group.count}/20 · ${group.schedule}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.mono(
                      size: 9,
                      weight: FontWeight.w700,
                      color: c.muted,
                    ),
                  ),
                ),
                if (group.debtors > 0) ...[
                  const SizedBox(width: 7),
                  RefPill(
                    label: '${group.debtors} qarz',
                    tone: RefPillTone.danger,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebPaymentsPage extends StatefulWidget {
  const WebPaymentsPage({super.key});

  @override
  State<WebPaymentsPage> createState() => _WebPaymentsPageState();
}

class _WebPaymentsPageState extends State<WebPaymentsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  int _page = 1;
  int _pageSize = 5;

  Future<void> _acceptPayment(AppStore store, SfColors colors) async {
    final entry = await showModalBottomSheet<LedgerEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: colors,
        child: _PaymentIntakeSheet(
          students: store.students,
          onSave:
              ({
                required student,
                required payer,
                required amount,
                required channel,
                required operationNumber,
                comment,
              }) => store.recordPayment(
                student: student,
                payer: payer,
                amount: amount,
                channel: channel,
                operationNumber: operationNumber,
                comment: comment,
              ),
        ),
      ),
    );
    if (entry == null || !mounted) return;
    setState(() {
      _page = 1;
      _filter = 1;
      _query = '';
      _search.clear();
    });
    await Navigator.of(
      context,
    ).push(sfPageRoute(LedgerEntryScreen(entry: entry, colors: colors)));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final entries = store.ledger.where((entry) {
      final q = _query.toLowerCase();
      final filterOk =
          _filter == 0 || (_filter == 1 ? entry.inflow : !entry.inflow);
      return filterOk &&
          (q.isEmpty ||
              '${entry.title} ${entry.who} ${entry.channel}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final pageCount = entries.isEmpty
        ? 1
        : ((entries.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visibleEntries = entries
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Material(
      color: c.bg,
      child: Column(
        children: [
          RefLargeHeader(
            eyebrow: 'MOLIYA · JORIY OY',
            title: 'To‘lovlar',
            subtitle: 'Tushum, xarajat va qarzdorlik nazorati',
            actions: [
              if (store.role == SfRole.manager)
                RefIconAction(
                  icon: Icons.add_card_rounded,
                  tooltip: 'Принять платёж',
                  onPressed: () => _acceptPayment(store, c),
                ),
              RefIconAction(
                icon: Icons.file_download_outlined,
                tooltip: 'Hisobot',
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(ReportScreen(colors: c, role: store.role))),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              children: [
                RefAdaptiveGrid(
                  minCellWidth: 132,
                  children: [
                    RefMetricCard(
                      label: 'Tushum',
                      value: fmtMoneyMln(store.inflowTotal),
                      icon: Icons.south_west_rounded,
                      tone: RefMetricTone.success,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: 'Xarajat',
                      value: fmtMoneyMln(store.outflowTotal),
                      icon: Icons.north_east_rounded,
                      tone: RefMetricTone.danger,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: 'Balans',
                      value: fmtMoneyMln(store.balance),
                      icon: Icons.account_balance_wallet_rounded,
                      tone: RefMetricTone.primary,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PaymentChannels(entries: store.ledger),
                const SizedBox(height: 16),
                RefSearchField(
                  controller: _search,
                  hint: 'To‘lov yoki mijoz qidirish',
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 1;
                  }),
                ),
                const SizedBox(height: 10),
                RefSegmentedControl<int>(
                  values: const [0, 1, 2],
                  selected: _filter,
                  labelOf: (value) =>
                      const ['Hammasi', 'Tushum', 'Xarajat'][value],
                  onChanged: (value) => setState(() {
                    _filter = value;
                    _page = 1;
                  }),
                ),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: 'Operatsiyalar',
                  subtitle: '${entries.length} ta yozuv',
                ),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  _WebEmpty(
                    icon: Icons.payments_outlined,
                    text: 'Operatsiya topilmadi',
                  )
                else
                  for (
                    var index = 0;
                    index < visibleEntries.length;
                    index++
                  ) ...[
                    RefStaggeredReveal(
                      order: index,
                      child: _PaymentEntry(entry: visibleEntries[index]),
                    ),
                    const SizedBox(height: 9),
                  ],
                if (entries.isNotEmpty)
                  RefPaginationBar(
                    page: currentPage,
                    pages: pageCount,
                    total: entries.length,
                    pageSize: _pageSize,
                    onPageChanged: (value) => setState(() => _page = value),
                    onPageSizeChanged: (value) => setState(() {
                      _pageSize = value;
                      _page = 1;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SavePayment =
    LedgerEntry Function({
      required Student student,
      required String payer,
      required num amount,
      required String channel,
      required String operationNumber,
      String? comment,
    });

class _PaymentIntakeSheet extends StatefulWidget {
  const _PaymentIntakeSheet({required this.students, required this.onSave});

  final List<Student> students;
  final _SavePayment onSave;

  @override
  State<_PaymentIntakeSheet> createState() => _PaymentIntakeSheetState();
}

class _PaymentIntakeSheetState extends State<_PaymentIntakeSheet> {
  final _form = GlobalKey<FormState>();
  final _payer = TextEditingController();
  final _amount = TextEditingController();
  final _operation = TextEditingController(
    text: 'MAN-${DateTime.now().millisecondsSinceEpoch % 100000000}',
  );
  final _comment = TextEditingController();
  Student? _student;
  String _channel = 'Naqd';

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _selectStudent(widget.students.first);
    }
  }

  void _selectStudent(Student student) {
    _student = student;
    _payer.text = studentProfile(student).fatherName;
  }

  @override
  void dispose() {
    _payer.dispose();
    _amount.dispose();
    _operation.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false) || _student == null) return;
    final normalized = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = num.parse(normalized);
    final entry = widget.onSave(
      student: _student!,
      payer: _payer.text,
      amount: amount,
      channel: _channel,
      operationNumber: _operation.text,
      comment: _comment.text,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderStrong,
                      borderRadius: RefRadius.pill,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const RefSectionHeader(
                  title: 'Принять платёж',
                  subtitle: 'Операция попадёт в ledger и откроется в деталях',
                ),
                const SizedBox(height: 14),
                if (widget.students.isEmpty)
                  RefStatusTile(
                    icon: Icons.person_search_outlined,
                    title: 'Нет доступных учеников',
                    subtitle: 'Сначала добавьте ученика',
                    tone: RefMetricTone.warning,
                  )
                else ...[
                  DropdownButtonFormField<Student>(
                    key: const ValueKey('payment-intake-student'),
                    initialValue: _student,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ученик',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [
                      for (final student in widget.students)
                        DropdownMenuItem(
                          value: student,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selectedItemBuilder: (_) => [
                      for (final student in widget.students)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (student) {
                      if (student == null) return;
                      setState(() => _selectStudent(student));
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-intake-payer'),
                    controller: _payer,
                    decoration: const InputDecoration(
                      labelText: 'Кто оплатил',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Укажите плательщика'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-intake-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: 'UZS',
                    ),
                    validator: (value) {
                      final amount = num.tryParse(
                        (value ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
                      );
                      return amount == null || amount <= 0
                          ? 'Введите сумму больше нуля'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _channel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Способ оплаты',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Naqd', child: Text('Наличные')),
                      DropdownMenuItem(value: 'Click', child: Text('Click')),
                      DropdownMenuItem(value: 'Payme', child: Text('Payme')),
                      DropdownMenuItem(value: 'Uzum', child: Text('Uzum')),
                      DropdownMenuItem(
                        value: 'Bank',
                        child: Text('Банковский перевод'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _channel = value ?? _channel),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _operation,
                    decoration: const InputDecoration(
                      labelText: 'Номер операции',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Укажите номер операции'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RefButton(
                    label: 'Сохранить платёж',
                    leading: Icons.check_circle_rounded,
                    block: true,
                    onPressed: _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentChannels extends StatelessWidget {
  const _PaymentChannels({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final totals = <String, num>{};
    for (final entry in entries.where((entry) => entry.inflow)) {
      final channel = entry.channel.trim().isEmpty ? 'Boshqa' : entry.channel;
      totals[channel] = (totals[channel] ?? 0) + entry.amount;
    }
    final grandTotal = totals.values.fold<num>(0, (sum, value) => sum + value);
    final channels = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = channels.take(3).toList(growable: false);
    final palette = [c.primary, c.accent, c.success];
    return RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: CircularProgressIndicator(
              value: entries.isEmpty ? 0 : 1,
              strokeWidth: 10,
              backgroundColor: c.surface2,
              valueColor: AlwaysStoppedAnimation(c.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To‘lov usullari',
                  style: RefType.ui(
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Text(
                    'Tasdiqlangan tushum yo‘q',
                    style: RefType.ui(size: 11, color: c.muted),
                  )
                else
                  for (var index = 0; index < visible.length; index++)
                    _channel(
                      context,
                      palette[index],
                      visible[index].key,
                      grandTotal == 0
                          ? '0%'
                          : '${(visible[index].value / grandTotal * 100).round()}%',
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channel(
    BuildContext context,
    Color color,
    String name,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            name,
            style: RefType.ui(size: 11, color: SfTheme.of(context).ink2),
          ),
        ),
        Text(
          value,
          style: RefType.mono(
            size: 11,
            weight: FontWeight.w700,
            color: SfTheme.of(context).ink,
          ),
        ),
      ],
    ),
  );
}

class _PaymentEntry extends StatelessWidget {
  const _PaymentEntry({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final tone = entry.inflow ? RefMetricTone.success : RefMetricTone.danger;
    return Semantics(
      key: ValueKey('offline-payment-${entry.id}'),
      button: true,
      label: '${entry.title}. To‘lov tafsilotini ochish',
      child: RefStatusTile(
        icon: entry.inflow
            ? Icons.south_west_rounded
            : Icons.north_east_rounded,
        title: entry.title,
        subtitle: '${entry.who} · ${entry.channel} · ${entry.time}',
        tone: tone,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.inflow ? '+' : '-'}${fmtMoneyShort(entry.amount)}',
              style: RefType.mono(
                size: 12.5,
                weight: FontWeight.w800,
                color: entry.inflow ? c.success : c.danger,
              ),
            ),
            const SizedBox(height: 4),
            RefPill(
              label: entry.kind,
              tone: entry.inflow ? RefPillTone.success : RefPillTone.danger,
            ),
          ],
        ),
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(LedgerEntryScreen(entry: entry, colors: c))),
      ),
    );
  }
}

class WebMessagesPage extends StatefulWidget {
  const WebMessagesPage({super.key});

  @override
  State<WebMessagesPage> createState() => _WebMessagesPageState();
}

class _WebMessagesPageState extends State<WebMessagesPage> {
  final _search = TextEditingController();
  String _query = '';
  int _folder = 0;
  int _page = 1;
  int _pageSize = 5;

  Future<void> _openConversationPicker(AppStore store) async {
    final c = SfTheme.of(context);
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: DraggableScrollableSheet(
          initialChildSize: .68,
          minChildSize: .4,
          maxChildSize: .9,
          expand: false,
          builder: (context, controller) => DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: RefRadius.pill,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: RefSectionHeader(
                      title: 'Начать разговор',
                      subtitle: '${store.threads.length} доступных контактов',
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: store.threads.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final thread = store.threads[index].meta;
                        return RefStatusTile(
                          icon: thread.isGroup
                              ? Icons.groups_rounded
                              : Icons.person_outline_rounded,
                          title: thread.name,
                          subtitle: thread.group,
                          tone: RefMetricTone.neutral,
                          onTap: () => Navigator.of(sheetContext).pop(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (index == null || !mounted) return;
    await Navigator.of(
      context,
    ).push(sfPageRoute(ChatScreen(threadIdx: index, colors: c)));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final indices = <int>[];
    for (var i = 0; i < store.threads.length; i++) {
      final thread = store.threads[i].meta;
      final archived = store.archived.contains(i);
      final inFolder = switch (_folder) {
        1 => !thread.isGroup && !archived,
        2 => thread.isGroup && !archived,
        3 => thread.unread > 0 && !archived,
        4 => archived,
        _ => !archived,
      };
      if (inFolder &&
          (_query.isEmpty ||
              '${thread.name} ${thread.last}'.toLowerCase().contains(
                _query.toLowerCase(),
              ))) {
        indices.add(i);
      }
    }
    final pageCount = indices.isEmpty
        ? 1
        : ((indices.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visibleIndices = indices
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: 'JAMOA ALOQASI',
          title: 'Xabarlar',
          subtitle: 'Muloqotlar va ichki kanallar',
          actions: [
            RefIconAction(
              icon: Icons.edit_outlined,
              tooltip: 'Yangi xabar',
              onPressed: () => _openConversationPicker(store),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefSearchField(
                controller: _search,
                hint: 'Suhbat qidirish',
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 10),
              RefSegmentedControl<int>(
                values: const [0, 1, 2, 3, 4],
                selected: _folder,
                labelOf: (value) => const [
                  'Hammasi',
                  'Shaxsiy',
                  'Guruhlar',
                  'O‘qilmagan',
                  'Arxiv',
                ][value],
                onChanged: (value) => setState(() {
                  _folder = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'Suhbatlar',
                subtitle: '${indices.length} ta suhbat',
              ),
              const SizedBox(height: 8),
              if (indices.isEmpty)
                _WebEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: 'Suhbat topilmadi',
                )
              else
                for (var order = 0; order < visibleIndices.length; order++) ...[
                  RefStaggeredReveal(
                    order: order,
                    child: _MessageThreadCard(index: visibleIndices[order]),
                  ),
                  const SizedBox(height: 9),
                ],
              if (indices.isNotEmpty)
                RefPaginationBar(
                  page: currentPage,
                  pages: pageCount,
                  total: indices.length,
                  pageSize: _pageSize,
                  onPageChanged: (value) => setState(() => _page = value),
                  onPageSizeChanged: (value) => setState(() {
                    _pageSize = value;
                    _page = 1;
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final thread = store.threads[index].meta;
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(ChatScreen(threadIdx: index, colors: c))),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(13),
        elevated: true,
        child: Row(
          children: [
            thread.isGroup
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: RefRadius.md,
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.groups_rounded, color: c.surface),
                    ),
                  )
                : SfAvatar(name: thread.name, size: 44),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RefType.ui(
                            size: 13.5,
                            weight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                      ),
                      Text(
                        thread.time,
                        style: RefType.mono(size: 9.5, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 10.5, color: c.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 11.5, color: c.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (store.pinned.contains(index))
                  Icon(Icons.push_pin_rounded, size: 14, color: c.muted),
                if (thread.unread > 0) ...[
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: RefRadius.pill,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        '${thread.unread}',
                        style: RefType.mono(
                          size: 9,
                          weight: FontWeight.w800,
                          color: c.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebHrPage extends StatefulWidget {
  const WebHrPage({super.key});

  @override
  State<WebHrPage> createState() => _WebHrPageState();
}

class _WebHrPageState extends State<WebHrPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  int _page = 1;
  int _pageSize = 5;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final staff = store.staff.where((member) {
      final q = _query.toLowerCase();
      final typeOk =
          _filter == 0 ||
          (_filter == 1
              ? member.subject.toLowerCase() != 'operations'
              : member.subject.toLowerCase() == 'operations');
      return typeOk &&
          (q.isEmpty ||
              '${member.fullName} ${member.department} ${member.subject}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final pageCount = staff.isEmpty
        ? 1
        : ((staff.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visibleStaff = staff
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: '${store.staff.length} XODIM',
          title: 'HR · Xodimlar',
          subtitle: 'Jamoa, ishga qabul va lavozimlar',
          actions: [
            RefIconAction(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: 'Xodim qo‘shish',
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefAdaptiveGrid(
                minCellWidth: 150,
                children: [
                  RefMetricCard(
                    label: 'Jami xodim',
                    value: '${store.staff.length}',
                    icon: Icons.badge_rounded,
                    tone: RefMetricTone.primary,
                  ),
                  RefMetricCard(
                    label: 'O‘qituvchilar',
                    value:
                        '${store.staff.where((s) => s.subject.toLowerCase() != 'operations').length}',
                    icon: Icons.school_rounded,
                    tone: RefMetricTone.success,
                  ),
                  RefMetricCard(
                    label: 'Bo‘limlar',
                    value: '${store.departments.length}',
                    icon: Icons.account_balance_outlined,
                    tone: RefMetricTone.accent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RefSearchField(
                controller: _search,
                hint: 'Xodim yoki bo‘lim qidirish',
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 10),
              RefSegmentedControl<int>(
                values: const [0, 1, 2],
                selected: _filter,
                labelOf: (value) =>
                    const ['Hammasi', 'O‘qituvchi', 'Ma’muriy'][value],
                onChanged: (value) => setState(() {
                  _filter = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'Jamoa ro‘yxati',
                subtitle: '${staff.length} ta mos natija',
              ),
              const SizedBox(height: 8),
              if (staff.isEmpty)
                _WebEmpty(icon: Icons.badge_outlined, text: 'Xodim topilmadi')
              else
                for (var index = 0; index < visibleStaff.length; index++) ...[
                  RefStaggeredReveal(
                    order: index,
                    child: _StaffCard(member: visibleStaff[index]),
                  ),
                  const SizedBox(height: 9),
                ],
              if (staff.isNotEmpty)
                RefPaginationBar(
                  page: currentPage,
                  pages: pageCount,
                  total: staff.length,
                  pageSize: _pageSize,
                  onPageChanged: (value) => setState(() => _page = value),
                  onPageSizeChanged: (value) => setState(() {
                    _pageSize = value;
                    _page = 1;
                  }),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: RefButton(
                label: 'Xodim qo‘shish',
                leading: Icons.person_add_alt_1_rounded,
                block: true,
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(StaffCreateScreen(colors: c))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});
  final StaffMember member;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(StaffDetailScreen(member: member, colors: c))),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Row(
          children: [
            SfAvatar(name: member.fullName, size: 46),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: RefType.ui(
                      size: 14,
                      weight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${member.subject} · ${member.department}',
                    style: RefType.ui(size: 11, color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      RefPill(
                        label: member.salaryType,
                        tone: RefPillTone.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.branch,
                        style: RefType.mono(size: 10, color: c.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class WebApprovalsPage extends StatefulWidget {
  const WebApprovalsPage({super.key});
  @override
  State<WebApprovalsPage> createState() => _WebApprovalsPageState();
}

class _WebApprovalsPageState extends State<WebApprovalsPage> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final approvals = store.approvals
        .where(
          (item) =>
              _filter == 0 ||
              (_filter == 1 ? item.amount > 0 : item.amount == 0),
        )
        .toList();
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: 'BOSHQARUV NAVBATI',
          title: 'Tasdiqlar',
          subtitle: 'So‘rovlarni ko‘rib chiqing va qaror qabul qiling',
          actions: [
            RefIconAction(
              icon: Icons.history_rounded,
              tooltip: 'Tarix',
              onPressed: () => _showInfo(
                context,
                'Tasdiqlar tarixi',
                'Tasdiqlangan pul operatsiyalari Payments ekranida ko‘rinadi.',
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefAdaptiveGrid(
                minCellWidth: 150,
                children: [
                  RefMetricCard(
                    label: 'Kutilmoqda',
                    value: '${store.approvals.length}',
                    icon: Icons.pending_actions_rounded,
                    tone: RefMetricTone.warning,
                  ),
                  RefMetricCard(
                    label: 'Moliyaviy',
                    value:
                        '${store.approvals.where((a) => a.amount > 0).length}',
                    icon: Icons.payments_rounded,
                    tone: RefMetricTone.danger,
                  ),
                  RefMetricCard(
                    label: 'Bugun',
                    value:
                        '${store.activities.where((a) => a.kind == 'payment').length}',
                    icon: Icons.task_alt_rounded,
                    tone: RefMetricTone.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RefSegmentedControl<int>(
                values: const [0, 1, 2],
                selected: _filter,
                labelOf: (value) =>
                    const ['Hammasi', 'Moliyaviy', 'Operatsion'][value],
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'So‘rovlar',
                subtitle: '${approvals.length} ta kutilmoqda',
              ),
              const SizedBox(height: 8),
              if (approvals.isEmpty)
                _WebEmpty(
                  icon: Icons.task_alt_rounded,
                  text: 'Kutilayotgan so‘rov yo‘q',
                )
              else
                for (var index = 0; index < approvals.length; index++) ...[
                  RefStaggeredReveal(
                    order: index,
                    child: _ApprovalCard(approval: approvals[index]),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.approval});
  final Approval approval;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    return RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: approval.rail.withValues(alpha: .13),
                  borderRadius: RefRadius.md,
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    approval.amount > 0
                        ? Icons.payments_rounded
                        : Icons.assignment_rounded,
                    color: approval.rail,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.title,
                      style: RefType.ui(
                        size: 13.5,
                        weight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${approval.who} · ${approval.sub}',
                      style: RefType.ui(size: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
              if (approval.amount > 0)
                Text(
                  fmtMoneyShort(approval.amount),
                  style: RefType.mono(
                    size: 12,
                    weight: FontWeight.w800,
                    color: c.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: RefButton(
                  label: 'Rad etish',
                  kind: RefButtonKind.ghost,
                  leading: Icons.close_rounded,
                  onPressed: () => store.resolve(approval, approved: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RefButton(
                  label: 'Tasdiqlash',
                  kind: RefButtonKind.primary,
                  leading: Icons.check_rounded,
                  onPressed: () => store.resolve(approval, approved: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebEmpty extends StatelessWidget {
  const _WebEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 30, color: c.muted),
          const SizedBox(height: 10),
          Text(
            text,
            style: RefType.ui(size: 13, weight: FontWeight.w700, color: c.ink2),
          ),
        ],
      ),
    );
  }
}

void _showInfo(BuildContext context, String title, String message) {
  final c = SfTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: RefSurfaceCard(
          padding: const EdgeInsets.all(18),
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RefType.ui(
                  size: 18,
                  weight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: RefType.ui(size: 13, color: c.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: RefButton(
                  label: 'Yopish',
                  kind: RefButtonKind.soft,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
