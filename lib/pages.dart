// pages.dart — Full set of console pages ported from the React web prototype
// (admin-core/core2/org/org2/audit). Reachable from the grouped MenuHub so the
// mobile app mirrors the web feature set for CEO / Manager / Audit.

import 'package:flutter/material.dart';
import 'api_client.dart';
import 'api_store_adapter.dart';
import 'theme.dart';
import 'data.dart';
import 'i18n.dart';
import 'store.dart';
import 'widgets.dart';
import 'screens.dart'
    show
        SettingsScreen,
        BranchesScreen,
        BranchWorkspaceScreen,
        StudentsWorkspaceScreen,
        GroupsWorkspaceScreen,
        HrWorkspaceScreen,
        TeachersWorkspaceScreen,
        BranchComparisonScreen,
        ActivityHistoryScreen,
        ParentsWorkspaceScreen,
        DepartmentsWorkspaceScreen,
        MeetingsWorkspaceScreen,
        PaymentsWorkspaceScreen,
        StudentSelfServiceScreen;

const Color _purple = Color(0xFF7A4A82);

// ── Small shared building blocks ────────────────────────────────────────
Widget _head(BuildContext context, String eyebrow, String title, String sub) =>
    SfHead(eyebrow: eyebrow, title: title, sub: sub);

class _Row extends StatelessWidget {
  final Widget? lead;
  final String title;
  final String? sub;
  final Widget? trail;
  final bool last;
  final VoidCallback? onTap;
  const _Row({
    super.key,
    this.lead,
    required this.title,
    this.sub,
    this.trail,
    this.last = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final row = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          if (lead != null) ...[lead!, const SizedBox(width: 11)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10.5,
                      color: c.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (trail != null) ...[const SizedBox(width: 8), trail!],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

Widget _listCard({
  String? title,
  String? link,
  VoidCallback? onLink,
  required List<Widget> rows,
}) => SfCard(
  child: Column(
    children: [
      if (title != null) SfCardHeader(title, link: link, onTap: onLink),
      ...rows,
    ],
  ),
);

Widget _dot(Color color) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);

Widget _mono(
  BuildContext context,
  String t, {
  double size = 13,
  Color? color,
  FontWeight w = FontWeight.w700,
}) => Text(
  t,
  style: TextStyle(
    fontFamily: SfType.mono,
    fontSize: size,
    fontWeight: w,
    color: color ?? SfTheme.of(context).ink,
  ),
);

Future<void> _showRecordDetails(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Map<String, String> fields,
}) {
  final c = SfTheme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SfTheme(
      colors: c,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: c.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: c.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yopish',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                  itemCount: fields.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: c.border),
                  itemBuilder: (_, index) {
                    final field = fields.entries.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 108,
                            child: Text(
                              field.key,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 11.5,
                                color: c.muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              field.value,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Scaffold wrapper for a pushed page: app-bar + scrollable body.
Widget _page(
  SfColors c,
  String title,
  List<Widget> children, {
  List<Widget>? actions,
}) => SfScaffold(
  colors: c,
  title: title,
  actions: actions,
  body: ListView(padding: EdgeInsets.zero, children: children),
);

EdgeInsets get _pad => const EdgeInsets.fromLTRB(16, 4, 16, 24);

/// Chips + a list that actually filters. [match] decides whether [item] passes
/// for the selected chip label (the first chip is always "all"; grouping/sort
/// chips can just return true to act as a no-op).
class _FilterList<T> extends StatefulWidget {
  final List<String> chips;
  final List<T> items;
  final bool Function(T item, String chip) match;
  final Widget Function(BuildContext context, T item, bool last) row;
  // When true rows are wrapped in a single list card (default); when false each
  // row is a standalone card stacked in a column (for custom card layouts).
  final bool card;
  const _FilterList({
    super.key,
    required this.chips,
    required this.items,
    required this.match,
    required this.row,
    this.card = true,
  });
  @override
  State<_FilterList<T>> createState() => _FilterListState<T>();
}

class _FilterListState<T> extends State<_FilterList<T>> {
  int sel = 0;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final chip = widget.chips[sel];
    final filtered = sel == 0
        ? widget.items
        : widget.items.where((it) => widget.match(it, chip)).toList();
    final rows = [
      for (int i = 0; i < filtered.length; i++)
        widget.row(context, filtered[i], i == filtered.length - 1),
    ];
    return Column(
      children: [
        SfChips(widget.chips, onChanged: (i) => setState(() => sel = i)),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          SfCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  'Natija topilmadi',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12.5,
                    color: c.muted,
                  ),
                ),
              ),
            ),
          )
        else if (widget.card)
          _listCard(rows: rows)
        else
          Column(children: rows),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// BRANCHES (CEO)
// ════════════════════════════════════════════════════════════════════════
class BranchesAdminPage extends StatelessWidget {
  final SfColors colors;
  const BranchesAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final branches = [
      (
        'Yunusobod',
        'Dilnoza Yo‘ldosheva',
        512,
        16,
        342000000,
        94,
        2.8,
        5.2,
        c.success,
        'active',
      ),
      (
        'Chilonzor',
        'Rustam Olimov',
        486,
        15,
        318000000,
        92,
        3.1,
        4.6,
        c.success,
        'active',
      ),
      (
        'Mirobod',
        'Gulnora Saidova',
        478,
        14,
        308000000,
        90,
        3.4,
        3.1,
        c.warn,
        'active',
      ),
      (
        'Sebzor',
        'Akmal Yusupov',
        366,
        9,
        216000000,
        87,
        6.2,
        -1.2,
        c.danger,
        'review',
      ),
      ('Olmazor', 'Tayinlanmagan', 0, 0, 0, 0, 0.0, 0.0, c.muted, 'opening'),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Filiallar', [
        _head(
          context,
          '5 filial · 1842 o‘quvchi',
          'Filiallar',
          'Boshqaruv va yangi filial ochish',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                const SfKpi(
                  label: 'Faol filiallar',
                  value: '4',
                  icon: Icons.public_rounded,
                ),
                SfKpi(
                  label: 'Ochilmoqda',
                  value: '1',
                  color: c.primary,
                  sub: 'Olmazor · iyun',
                ),
                SfKpi(
                  label: 'Jami daromad',
                  value: fmtMoneyMln(1184000000),
                  color: c.success,
                  trend: (up: true, v: '8.2%'),
                ),
                SfKpi(
                  label: 'Nazoratda',
                  value: '1',
                  color: c.warn,
                  sub: 'Sebzor · churn',
                ),
              ]),
              const SizedBox(height: 12),
              for (int i = 0; i < branches.length; i++)
                _branchCard(context, branches[i], i),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _branchCard(
    BuildContext context,
    (String, String, int, int, num, int, double, double, Color, String) b,
    int i,
  ) {
    final c = SfTheme.of(context);
    final opening = b.$10 == 'opening';
    final statusTone = b.$10 == 'active'
        ? PillTone.success
        : b.$10 == 'review'
        ? PillTone.warn
        : PillTone.primary;
    final statusLabel = b.$10 == 'active'
        ? 'Faol'
        : b.$10 == 'review'
        ? 'Nazoratda'
        : 'Ochilmoqda';
    return InkWell(
      onTap: opening
          ? null
          : () => Navigator.of(context).push(
              sfPageRoute(
                BranchWorkspaceScreen(
                  branch: Branch(b.$1, b.$5, b.$3, b.$6, b.$8, b.$9),
                  colors: c,
                ),
              ),
            ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: b.$9,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: SfStar(size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.$1,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                        Row(
                          children: [
                            if (!opening) SfAvatar(name: b.$2, size: 16),
                            if (!opening) const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                b.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 10.5,
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Pill(statusLabel, tone: statusTone, dot: true),
                ],
              ),
            ),
            if (opening)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: 0.65,
                        minHeight: 6,
                        backgroundColor: c.surface2,
                        valueColor: AlwaysStoppedAnimation(c.primary),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Tayyorlik 65% · menejer tayinlash kerak',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    _bstat(context, fmtMoneyShort(b.$5), 'daromad'),
                    _bstat(context, '${b.$3}', 'o‘quvchi', border: true),
                    _bstat(context, '${b.$4}', 'xodim'),
                    _bstat(
                      context,
                      '${b.$6}%',
                      'посещаемость',
                      color: b.$6 >= 92 ? c.success : c.warn,
                      border: true,
                    ),
                    _bstat(
                      context,
                      '${b.$7}%',
                      'churn',
                      color: b.$7 <= 3.5 ? c.success : c.danger,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bstat(
    BuildContext context,
    String v,
    String l, {
    Color? color,
    bool border = false,
  }) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: border ? BorderSide(color: c.border) : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            Text(
              v,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? c.ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              l.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// STUDENTS (rich, web)
// ════════════════════════════════════════════════════════════════════════
class StudentsAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const StudentsAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final students = [
      (
        'Akbarov Akmal',
        '9-B Algebra',
        'Yunusobod',
        96,
        'paid',
        0,
        'Akbarova D.',
      ),
      (
        'Azizova Madina',
        '9-B Algebra',
        'Yunusobod',
        98,
        'paid',
        0,
        'Azizov B.',
      ),
      (
        'Bakirov Sherzod',
        'Algebra Mid',
        'Chilonzor',
        88,
        'debt',
        600000,
        'Bakirova Z.',
      ),
      (
        'Davronova Sevinch',
        'Algebra Mid',
        'Yunusobod',
        92,
        'paid',
        0,
        'Davronov T.',
      ),
      (
        'Eshmatov Otabek',
        '9-B Algebra',
        'Mirobod',
        72,
        'debt',
        1200000,
        'Eshmatova G.',
      ),
      (
        'Fayzullayev Diyor',
        '10-V Geom',
        'Yunusobod',
        94,
        'paid',
        0,
        'Fayzullayev N.',
      ),
      (
        'G‘aniyev Jasur',
        '10-V Geom',
        'Sebzor',
        89,
        'partial',
        300000,
        'G‘aniyeva M.',
      ),
      (
        'Halimova Zilola',
        '9-B Algebra',
        'Chilonzor',
        95,
        'paid',
        0,
        'Halimov R.',
      ),
      (
        'Ibragimov Sardor',
        'Algebra Mid',
        'Yunusobod',
        91,
        'paid',
        0,
        'Ibragimova S.',
      ),
      (
        'Karimov Rustam',
        '10-V Geom',
        'Mirobod',
        84,
        'debt',
        600000,
        'Karimova D.',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'O‘quvchilar', [
        _head(
          context,
          ceo ? '4 filial' : 'Yunusobod filiali',
          'O‘quvchilar',
          ceo ? '1 842 o‘quvchi · 96 guruh' : '512 o‘quvchi · 28 guruh',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Jami',
                  value: ceo ? '1 842' : '512',
                  icon: Icons.groups_rounded,
                ),
                SfKpi(
                  label: 'Faol',
                  value: ceo ? '1 784' : '496',
                  color: c.success,
                ),
                SfKpi(
                  label: 'Qarzdor',
                  value: ceo ? '142' : '38',
                  color: c.danger,
                  sub: 'oila',
                ),
                SfKpi(
                  label: 'Riskli',
                  value: ceo ? '24' : '6',
                  color: c.warn,
                  sub: 'ketish ehtimoli',
                ),
              ]),
              const SizedBox(height: 12),
              _FilterList<(String, String, String, int, String, int, String)>(
                chips: [
                  'Hammasi',
                  'Faol',
                  'Qarzdor',
                  'Riskli',
                  if (ceo) 'Filial',
                  'Guruh',
                  'Посещаемость',
                ],
                items: students,
                match: (s, chip) {
                  switch (chip) {
                    case 'Faol':
                      return s.$4 >= 85;
                    case 'Qarzdor':
                      return s.$5 == 'debt' || s.$5 == 'partial';
                    case 'Riskli':
                      return s.$4 < 85;
                    default:
                      return true; // Filial / Guruh / Посещаемость are grouping chips
                  }
                },
                row: (context, s, last) {
                  final att = s.$4;
                  final aColor = att >= 92
                      ? c.success
                      : att >= 85
                      ? c.warn
                      : c.danger;
                  final payTone = s.$5 == 'paid'
                      ? PillTone.success
                      : s.$5 == 'debt'
                      ? PillTone.danger
                      : PillTone.warn;
                  final payLabel = s.$5 == 'paid'
                      ? 'To‘langan'
                      : s.$5 == 'debt'
                      ? 'Qarz'
                      : 'Qisman';
                  return _Row(
                    lead: SfAvatar(name: s.$1, size: 32),
                    title: s.$1,
                    sub: '${s.$2}${ceo ? ' · ${s.$3}' : ''} · $att%',
                    last: last,
                    onTap: () => _showRecordDetails(
                      context,
                      title: s.$1,
                      icon: Icons.school_rounded,
                      fields: {
                        'Guruh': s.$2,
                        'Filial': s.$3,
                        'Посещаемость': '$att%',
                        'To‘lov': payLabel,
                        'Qarzdorlik': s.$6 > 0 ? fmtMoney(s.$6) : 'Yo‘q',
                        'Mas’ul': s.$7,
                      },
                    ),
                    trail: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Pill(payLabel, tone: payTone),
                        if (s.$6 > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _mono(
                              context,
                              fmtMoney(s.$6),
                              size: 10,
                              color: aColor,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// GROUPS
// ════════════════════════════════════════════════════════════════════════
class GroupsAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const GroupsAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final groups = [
      (
        '9-B Algebra',
        'Nigora Karimova',
        'Yunusobod',
        24,
        26,
        94,
        'Du/Se/Pa · 09:00',
        600000,
        c.primary,
      ),
      (
        'Algebra Mid',
        'Nigora Karimova',
        'Yunusobod',
        21,
        24,
        96,
        'Cho/Pa · 14:00',
        600000,
        c.primary,
      ),
      (
        '10-V Geometriya',
        'Bobur Aliyev',
        'Chilonzor',
        19,
        22,
        88,
        'Du/Pa · 11:30',
        650000,
        c.accent,
      ),
      (
        'Ingliz B2 · Intensiv',
        'Aziz Tursunov',
        'Mirobod',
        16,
        18,
        92,
        'Har kuni · 16:00',
        850000,
        c.success,
      ),
      (
        'Fizika · DTM',
        'Malika Yusupova',
        'Sebzor',
        14,
        20,
        85,
        'Se/Pa/Sh · 10:00',
        700000,
        c.ink2,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Guruhlar', [
        _head(
          context,
          ceo ? '96 guruh' : '28 guruh',
          'Guruhlar',
          ceo ? 'Barcha filiallar bo‘yicha' : 'Yunusobod filiali',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterList<
                (String, String, String, int, int, int, String, num, Color)
              >(
                chips: ['Hammasi', 'Faol', 'To‘lgan', 'Bo‘sh joy bor', 'Fan'],
                items: groups,
                card: false,
                match: (g, chip) {
                  switch (chip) {
                    case 'To‘lgan':
                      return g.$4 >= g.$5; // at/over capacity
                    case 'Bo‘sh joy bor':
                      return g.$4 < g.$5; // seats available
                    default:
                      return true; // Faol / Fan are grouping chips
                  }
                },
                row: (context, g, last) => _groupCard(context, g),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _groupCard(
    BuildContext context,
    (String, String, String, int, int, int, String, num, Color) g,
  ) {
    final c = SfTheme.of(context);
    final ratio = g.$4 / g.$5;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: g.$9,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SfStar(size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.$1,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        g.$2,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ceo) Pill(g.$3, tone: PillTone.neutral),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: c.surface2,
                      valueColor: AlwaysStoppedAnimation(
                        ratio > 0.9 ? c.warn : c.success,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _mono(context, '${g.$4}/${g.$5}', size: 11, color: c.muted),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: c.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    g.$7,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      color: c.ink2,
                    ),
                  ),
                ),
                _mono(
                  context,
                  '${g.$6}%',
                  size: 11,
                  color: g.$6 >= 92 ? c.success : c.warn,
                ),
                const SizedBox(width: 8),
                _mono(
                  context,
                  '${fmtMoneyShort(g.$8)}/oy',
                  size: 11,
                  color: c.ink2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// TEACHERS / STAFF
// ════════════════════════════════════════════════════════════════════════
class TeachersAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const TeachersAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final teachers = [
      (
        'Nigora Karimova',
        'Katta o‘qituvchi',
        'Matematika',
        'Yunusobod',
        94,
        18,
        4,
        4.9,
        8400000,
        'active',
      ),
      (
        'Aziz Tursunov',
        'O‘qituvchi',
        'Ingliz tili',
        'Chilonzor',
        92,
        22,
        2,
        4.8,
        7800000,
        'active',
      ),
      (
        'Malika Yusupova',
        'O‘qituvchi',
        'Fizika',
        'Mirobod',
        88,
        12,
        6,
        4.5,
        7200000,
        'active',
      ),
      (
        'Bobur Aliyev',
        'O‘qituvchi',
        'Geometriya',
        'Yunusobod',
        90,
        15,
        3,
        4.6,
        7600000,
        'active',
      ),
      (
        'Sevara Olimova',
        'Assistent',
        'Matematika',
        'Yunusobod',
        96,
        8,
        0,
        4.7,
        4200000,
        'active',
      ),
      (
        'Jasur Rahimov',
        'O‘qituvchi',
        'Kimyo',
        'Sebzor',
        82,
        6,
        8,
        3.9,
        7000000,
        'review',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, ceo ? 'O‘qituvchilar' : 'Xodimlar', [
        _head(
          context,
          ceo ? '54 xodim · 4 filial' : '16 xodim',
          ceo ? 'O‘qituvchilar' : 'Xodimlar',
          'O‘qituvchilar, assistentlar va reyting',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Jami xodim',
                  value: ceo ? '54' : '16',
                  icon: Icons.badge_rounded,
                ),
                SfKpi(
                  label: 'O‘rtacha reyting',
                  value: '4.6',
                  color: c.accent,
                  sub: '5 dan',
                  icon: Icons.star_rounded,
                ),
                SfKpi(
                  label: 'Oylik fond',
                  value: fmtMoneyMln(ceo ? 412000000 : 96000000),
                  color: c.success,
                  icon: Icons.trending_up_rounded,
                ),
                SfKpi(
                  label: 'Tekshiruvda',
                  value: '2',
                  color: c.warn,
                  sub: 'past reyting',
                ),
              ]),
              const SizedBox(height: 12),
              _FilterList<
                (
                  String,
                  String,
                  String,
                  String,
                  int,
                  int,
                  int,
                  double,
                  num,
                  String,
                )
              >(
                chips: [
                  'Hammasi',
                  'O‘qituvchi',
                  'Assistent',
                  'Faol',
                  'Tekshiruv',
                  'Fan',
                ],
                items: teachers,
                match: (t, chip) {
                  switch (chip) {
                    case 'O‘qituvchi':
                      return t.$2.contains('o‘qituvchi') ||
                          t.$2.contains('O‘qituvchi');
                    case 'Assistent':
                      return t.$2 == 'Assistent';
                    case 'Faol':
                      return t.$10 == 'active';
                    case 'Tekshiruv':
                      return t.$10 == 'review';
                    default:
                      return true; // Fan is a grouping chip
                  }
                },
                row: (context, t, last) {
                  final rTone = t.$8 >= 4.5
                      ? PillTone.success
                      : t.$8 >= 4
                      ? PillTone.warn
                      : PillTone.danger;
                  return _Row(
                    lead: SfAvatar(name: t.$1, size: 32),
                    title: t.$1,
                    sub:
                        '${t.$3}${ceo ? ' · ${t.$4}' : ''} · ↑${t.$6} ↓${t.$7}',
                    last: last,
                    onTap: () => _showRecordDetails(
                      context,
                      title: t.$1,
                      icon: Icons.co_present_rounded,
                      fields: {
                        'Lavozim': t.$2,
                        'Fan': t.$3,
                        'Filial': t.$4,
                        'Посещаемость': '${t.$5}%',
                        'Up / Down': '${t.$6} / ${t.$7}',
                        'Ko‘rsatkich': '${t.$8}',
                        'Maosh': fmtMoney(t.$9),
                        'Holat': t.$10 == 'active' ? 'Faol' : 'Tekshiruvda',
                      },
                    ),
                    trail: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Pill('★ ${t.$8}', tone: rTone),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _mono(
                            context,
                            '${t.$5}%',
                            size: 10,
                            color: t.$5 >= 92 ? c.success : c.warn,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PAYMENTS
// ════════════════════════════════════════════════════════════════════════
class PaymentsAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const PaymentsAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final txns = [
      ('Akbarov Akmal', '9-B Algebra', 600000, 'Click', '19.05 09:42', 'ok'),
      ('Halimova Zilola', '9-B Algebra', 600000, 'Payme', '19.05 08:10', 'ok'),
      ('Bakirov Sherzod', 'Algebra Mid', 600000, '—', 'Muddat 15.05', 'debt'),
      ('Ibragimov Sardor', 'Algebra Mid', 850000, 'Naqd', '18.05 16:30', 'ok'),
      (
        'G‘aniyev Jasur',
        '10-V Geom',
        300000,
        'Uzcard',
        '18.05 14:05',
        'partial',
      ),
      ('Eshmatov Otabek', '9-B Algebra', 1200000, '—', 'Muddat 10.05', 'debt'),
      (
        'Davronova Sevinch',
        'Algebra Mid',
        600000,
        'Click',
        '17.05 11:20',
        'ok',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'To‘lovlar', [
        _head(
          context,
          ceo ? 'Barcha filiallar' : 'Yunusobod filiali',
          'To‘lovlar',
          'Tushum, qarz va to‘lov usullari',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Oylik tushum',
                  value: fmtMoneyMln(ceo ? 1284000000 : 342000000),
                  color: c.success,
                  trend: (up: true, v: '12.4%'),
                  spark: const [
                    60,
                    68,
                    64,
                    72,
                    70,
                    78,
                    82,
                    80,
                    88,
                    92,
                    96,
                    100,
                  ],
                ),
                SfKpi(
                  label: 'Yig‘ilishi kerak',
                  value: fmtMoneyMln(ceo ? 1420000000 : 380000000),
                  sub: 'rejalashtirilgan',
                ),
                SfKpi(
                  label: 'Qarzdorlik',
                  value: fmtMoneyMln(ceo ? 84000000 : 22400000),
                  color: c.danger,
                  sub: ceo ? '142 oila' : '38 oila',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(
                  label: 'To‘lov darajasi',
                  value: '94.2%',
                  color: c.primary,
                  trend: (up: true, v: '1.1%'),
                ),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader(
                      tx(
                        context,
                        uz: 'To‘lov usullari',
                        ru: 'Способы оплаты',
                        en: 'Payment methods',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Row(
                        children: [
                          Donut(
                            size: 92,
                            thickness: 14,
                            segments: [
                              DonutSegment(
                                42,
                                c.primary,
                                label: 'Click',
                                display: '42%',
                              ),
                              DonutSegment(
                                28,
                                c.accent,
                                label: 'Payme',
                                display: '28%',
                              ),
                              DonutSegment(
                                18,
                                c.success,
                                label: 'Uzcard',
                                display: '18%',
                              ),
                              DonutSegment(
                                12,
                                c.ink2,
                                label: tx(
                                  context,
                                  uz: 'Naqd',
                                  ru: 'Наличные',
                                  en: 'Cash',
                                ),
                                display: '12%',
                              ),
                            ],
                            center: _mono(context, '94%', size: 16),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                LegendRow(c.primary, 'Click', '42%'),
                                LegendRow(c.accent, 'Payme', '28%'),
                                LegendRow(c.success, 'Uzcard', '18%'),
                                LegendRow(
                                  c.ink2,
                                  tx(
                                    context,
                                    uz: 'Naqd',
                                    ru: 'Наличные',
                                    en: 'Cash',
                                  ),
                                  '12%',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _FilterList<(String, String, num, String, String, String)>(
                chips: ['Hammasi', 'To‘langan', 'Qarz', 'Qisman', 'Bu oy'],
                items: txns,
                match: (t, chip) {
                  switch (chip) {
                    case 'To‘langan':
                      return t.$6 == 'ok';
                    case 'Qarz':
                      return t.$6 == 'debt';
                    case 'Qisman':
                      return t.$6 == 'partial';
                    default:
                      return true; // Bu oy is a period chip
                  }
                },
                row: (context, t, last) {
                  final debt = t.$6 == 'debt';
                  final tone = t.$6 == 'ok'
                      ? PillTone.success
                      : debt
                      ? PillTone.danger
                      : PillTone.warn;
                  final label = t.$6 == 'ok'
                      ? 'To‘landi'
                      : debt
                      ? 'Qarz'
                      : 'Qisman';
                  return _Row(
                    lead: SfAvatar(name: t.$1, size: 30),
                    title: t.$1,
                    sub: '${t.$2} · ${t.$4} · ${t.$5}',
                    last: last,
                    trail: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _mono(
                          context,
                          fmtMoneyShort(t.$3),
                          size: 12,
                          color: debt ? c.danger : c.ink,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Pill(label, tone: tone),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PARENTS
// ════════════════════════════════════════════════════════════════════════
class ParentsAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const ParentsAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final parents = [
      ('Akbarova Dilnoza', 'Akmal · Ona', '+998 90 222 11 33', true, 0, false),
      (
        'Bakirova Zarnigor',
        'Sherzod · Ona',
        '+998 91 444 55 66',
        true,
        600000,
        false,
      ),
      (
        'Eshmatova Gulnora',
        'Otabek · Ona',
        '+998 93 111 22 44',
        false,
        1200000,
        true,
      ),
      ('Davronov Temur', 'Sevinch · Ota', '+998 90 555 66 77', true, 0, false),
      ('Halimov Rustam', 'Zilola · Ota', '+998 94 888 99 00', true, 0, false),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Ota-onalar', [
        _head(
          context,
          ceo ? 'Barcha filiallar' : 'Yunusobod filiali',
          'Ota-onalar',
          'Aloqa, qarzdorlik va eskalatsiyalar',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Jami ota-ona',
                  value: ceo ? '1 624' : '448',
                  icon: Icons.chat_bubble_outline_rounded,
                ),
                SfKpi(
                  label: 'Telegram ulangan',
                  value: '82%',
                  color: c.primary,
                ),
                SfKpi(
                  label: 'Eskalatsiya',
                  value: ceo ? '8' : '3',
                  color: c.danger,
                  sub: 'hal qilinmagan',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(label: 'O‘rt. javob', value: '14 daq', color: c.success),
              ]),
              const SizedBox(height: 12),
              _FilterList<(String, String, String, bool, int, bool)>(
                chips: [
                  'Hammasi',
                  'Eskalatsiya',
                  'Qarzdor',
                  'Telegramsiz',
                  if (ceo) 'Filial',
                ],
                items: parents,
                match: (p, chip) {
                  switch (chip) {
                    case 'Eskalatsiya':
                      return p.$6;
                    case 'Qarzdor':
                      return p.$5 > 0;
                    case 'Telegramsiz':
                      return !p.$4;
                    default:
                      return true; // Filial is a grouping chip
                  }
                },
                row: (context, p, last) => _Row(
                  lead: SfAvatar(name: p.$1, size: 32),
                  title: p.$1,
                  sub: '${p.$2} · ${p.$3}',
                  last: last,
                  onTap: () => _showRecordDetails(
                    context,
                    title: p.$1,
                    icon: Icons.family_restroom_rounded,
                    fields: {
                      'Farzand': p.$2,
                      'Guruh / aloqa': p.$3,
                      'Telegram': p.$4 ? 'Ulangan' : 'Ulanmagan',
                      'Qarzdorlik': p.$5 > 0 ? fmtMoney(p.$5) : 'Yo‘q',
                      'Eskalatsiya': p.$6 ? 'Kerak' : 'Yo‘q',
                    },
                  ),
                  trail: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (p.$6)
                        const Pill('eskal.', tone: PillTone.danger)
                      else
                        Pill(
                          p.$4 ? 'Ulangan' : 'Yo‘q',
                          tone: p.$4 ? PillTone.primary : PillTone.neutral,
                          dot: p.$4,
                        ),
                      if (p.$5 > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _mono(
                            context,
                            fmtMoney(p.$5),
                            size: 10,
                            color: c.danger,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CHATS (read-only oversight)
// ════════════════════════════════════════════════════════════════════════
class _OversightMessage {
  final String sender;
  final String text;
  final String time;

  const _OversightMessage(this.sender, this.text, this.time);
}

class _OversightThread {
  final String teacher;
  final String parent;
  final String context;
  final String lastActivity;
  final bool flagged;
  final List<_OversightMessage> messages;

  const _OversightThread({
    required this.teacher,
    required this.parent,
    required this.context,
    required this.lastActivity,
    required this.flagged,
    required this.messages,
  });
}

const _oversightThreads = <_OversightThread>[
  _OversightThread(
    teacher: 'Nigora Karimova',
    parent: 'Akbarova Dilnoza',
    context: '9-B · Akmal',
    lastActivity: '14:42',
    flagged: false,
    messages: [
      _OversightMessage(
        'Nigora Karimova',
        'Assalomu alaykum. Akmal bugun topshiriqni yaxshi bajardi.',
        '14:31',
      ),
      _OversightMessage(
        'Akbarova Dilnoza',
        'Rahmat, uyda ham mashqlarni davom ettiramiz.',
        '14:35',
      ),
      _OversightMessage(
        'Nigora Karimova',
        'Ertaga nazorat ishi bo‘ladi. Daftarini olib kelsin.',
        '14:39',
      ),
      _OversightMessage(
        'Akbarova Dilnoza',
        'Rahmat, ustoz! Ertaga albatta olib keladi.',
        '14:42',
      ),
    ],
  ),
  _OversightThread(
    teacher: 'Nigora Karimova',
    parent: 'Eshmatova Gulnora',
    context: '9-B · Otabek',
    lastActivity: '12:18',
    flagged: true,
    messages: [
      _OversightMessage(
        'Eshmatova Gulnora',
        'Bolam bugun darsga kela olmaydi.',
        '11:52',
      ),
      _OversightMessage(
        'Nigora Karimova',
        'Tushunarli. Sababini administratorga ham yuboring.',
        '12:03',
      ),
      _OversightMessage(
        'Eshmatova Gulnora',
        'Ma’lumotnoma tayyor bo‘lgach yuboraman.',
        '12:18',
      ),
    ],
  ),
  _OversightThread(
    teacher: 'Bobur Aliyev',
    parent: 'Halimov Rustam',
    context: '10-V · Zilola',
    lastActivity: 'Du',
    flagged: false,
    messages: [
      _OversightMessage(
        'Bobur Aliyev',
        'Zilolaning sinov natijasi kabinetga joylandi.',
        'Du · 09:15',
      ),
      _OversightMessage(
        'Halimov Rustam',
        'Yaxshi, biz ko‘rib chiqdik. Rahmat.',
        'Du · 09:28',
      ),
    ],
  ),
  _OversightThread(
    teacher: 'Aziz Tursunov',
    parent: 'Davronov Temur',
    context: 'Ingliz · Sevinch',
    lastActivity: 'Du',
    flagged: false,
    messages: [
      _OversightMessage(
        'Davronov Temur',
        'To‘lov haqida savol bor edi.',
        'Du · 16:04',
      ),
      _OversightMessage(
        'Aziz Tursunov',
        'Kvitansiya va muddatni administrator aniqlashtirib beradi.',
        'Du · 16:12',
      ),
    ],
  ),
];

String _oversightMessageTime(ChatMsg message, String fallback) {
  final createdAt = message.createdAt?.toLocal();
  if (createdAt == null) return fallback;
  return '${createdAt.hour.toString().padLeft(2, '0')}:'
      '${createdAt.minute.toString().padLeft(2, '0')}';
}

_OversightThread _liveOversightThread(ChatThread thread, String selfName) {
  final peer = thread.meta.name.trim().isEmpty ? 'Участник' : thread.meta.name;
  final account = selfName.trim().isEmpty ? 'Моя учётная запись' : selfName;
  return _OversightThread(
    teacher: peer,
    parent: account,
    context: thread.meta.group.trim().isEmpty ? 'Диалог' : thread.meta.group,
    lastActivity: thread.meta.time,
    flagged: false,
    messages: [
      for (final message in thread.messages)
        _OversightMessage(
          message.mine ? account : peer,
          message.text,
          _oversightMessageTime(message, thread.meta.time),
        ),
    ],
  );
}

class ChatsAdminPage extends StatelessWidget {
  final SfColors colors;
  const ChatsAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final session = ApiScope.maybeOf(context)?.notifier;
    final live = session?.authenticated == true;
    final liveSources = live
        ? List<ChatThread>.unmodifiable(AppScope.of(context).threads)
        : const <ChatThread>[];
    final selfName = live
        ? apiText(
            apiValue(session!.me ?? const {}, const [
              'full_name',
              'display_name',
              'name',
              'username',
            ]),
            fallback: 'Моя учётная запись',
          )
        : '';
    final threads = live
        ? liveSources
              .map((thread) => _liveOversightThread(thread, selfName))
              .toList(growable: false)
        : _oversightThreads;
    return SfTheme(
      colors: c,
      child: _page(c, 'Suhbat nazorati', [
        _head(
          context,
          'Nazorat ko‘rinishi',
          'Suhbatlar',
          'O‘qituvchi ↔ ota-ona · faqat o‘qish',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.aiBg),
                  border: Border.all(color: c.aiBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 16, color: c.ai),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Audit rejimi — bu suhbatlarga yozib bo‘lmaydi.',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11.5,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (threads.isEmpty)
                SfCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        live
                            ? 'Пока нет доступных диалогов'
                            : 'Диалоги не добавлены',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ),
                )
              else
                _listCard(
                  rows: [
                    for (int i = 0; i < threads.length; i++)
                      _Row(
                        key: ValueKey(
                          live
                              ? 'oversight-live-thread-${liveSources[i].meta.serverId ?? i}'
                              : 'oversight-thread-$i',
                        ),
                        lead: SfAvatar(name: threads[i].teacher, size: 32),
                        title:
                            '${threads[i].teacher.split(' ')[0]} ↔ ${threads[i].parent.split(' ')[0]}',
                        sub: threads[i].messages.isEmpty
                            ? '${threads[i].context} · Сообщений пока нет'
                            : '${threads[i].context} · ${threads[i].messages.last.text}',
                        last: i == threads.length - 1,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _OversightChatDetailPage(
                              colors: c,
                              thread: threads[i],
                              liveSource: live ? liveSources[i] : null,
                            ),
                          ),
                        ),
                        trail: threads[i].flagged
                            ? Icon(
                                Icons.flag_rounded,
                                size: 16,
                                color: c.danger,
                              )
                            : _mono(
                                context,
                                threads[i].lastActivity,
                                size: 9.5,
                                color: c.muted,
                              ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _OversightChatDetailPage extends StatefulWidget {
  final SfColors colors;
  final _OversightThread thread;
  final ChatThread? liveSource;

  const _OversightChatDetailPage({
    required this.colors,
    required this.thread,
    this.liveSource,
  });

  @override
  State<_OversightChatDetailPage> createState() =>
      _OversightChatDetailPageState();
}

class _OversightChatDetailPageState extends State<_OversightChatDetailPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  late _OversightThread _thread = widget.thread;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.liveSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTranscript());
    }
  }

  Future<void> _loadTranscript() async {
    final source = widget.liveSource;
    final id = source?.meta.serverId?.trim() ?? '';
    final session = ApiScope.maybeOf(context)?.notifier;
    if (source == null ||
        id.isEmpty ||
        session == null ||
        !session.authenticated ||
        _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await session.threadMessages(id);
      final messages =
          page.items
              .map((row) => apiChatMessage(session, row))
              .toList(growable: false)
            ..sort((left, right) {
              final leftAt = left.createdAt;
              final rightAt = right.createdAt;
              if (leftAt == null && rightAt == null) return 0;
              if (leftAt == null) return -1;
              if (rightAt == null) return 1;
              return leftAt.compareTo(rightAt);
            });
      final selfName = apiText(
        apiValue(session.me ?? const {}, const [
          'full_name',
          'display_name',
          'name',
          'username',
        ]),
        fallback: 'Моя учётная запись',
      );
      if (!mounted) return;
      setState(() {
        _thread = _liveOversightThread(
          ChatThread(source.meta, messages),
          selfName,
        );
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final thread = _thread;
    final query = _query.trim().toLowerCase();
    final messages = thread.messages
        .where(
          (message) =>
              query.isEmpty ||
              message.sender.toLowerCase().contains(query) ||
              message.text.toLowerCase().contains(query) ||
              message.time.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return SfTheme(
      colors: c,
      child: Scaffold(
        key: const ValueKey('oversight-chat-detail'),
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: c.ink),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${thread.teacher.split(' ')[0]} ↔ ${thread.parent.split(' ')[0]}',
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              Text(
                thread.context,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 9.5,
                  color: c.muted,
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          children: [
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
            ],
            Container(
              key: const ValueKey('oversight-read-only-banner'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.aiBg.first,
                border: Border.all(color: c.aiBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.visibility_rounded, size: 17, color: c.ai),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Только чтение: отправка, редактирование и удаление сообщений отключены.',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        height: 1.35,
                        color: c.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              SfCard(
                child: ListTile(
                  leading: Icon(Icons.sync_problem_rounded, color: c.danger),
                  title: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      color: c.danger,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Повторить',
                    onPressed: _loadTranscript,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  const SfCardHeader('Метаданные разговора'),
                  _OversightMetadataRow('O‘qituvchi', thread.teacher),
                  _OversightMetadataRow('Ota-ona', thread.parent),
                  _OversightMetadataRow('O‘quvchi · guruh', thread.context),
                  _OversightMetadataRow('Oxirgi faollik', thread.lastActivity),
                  _OversightMetadataRow(
                    'Nazorat holati',
                    thread.flagged ? 'Flag qo‘yilgan' : 'Signal yo‘q',
                    last: true,
                    valueColor: thread.flagged ? c.danger : c.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('oversight-chat-search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 13,
                color: c.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Поиск по сообщениям или участнику',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ПЕРЕПИСКА',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                      color: c.muted,
                    ),
                  ),
                ),
                _mono(
                  context,
                  '${messages.length}/${thread.messages.length}',
                  size: 10,
                  color: c.muted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (messages.isEmpty)
              SfCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Сообщения не найдены',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12.5,
                        color: c.muted,
                      ),
                    ),
                  ),
                ),
              )
            else
              for (var index = 0; index < messages.length; index++) ...[
                _OversightMessageCard(
                  message: messages[index],
                  teacher: thread.teacher,
                ),
                if (index < messages.length - 1) const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _OversightMetadataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  final Color? valueColor;

  const _OversightMetadataRow(
    this.label,
    this.value, {
    this.last = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11,
                color: c.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OversightMessageCard extends StatelessWidget {
  final _OversightMessage message;
  final String teacher;

  const _OversightMessageCard({required this.message, required this.teacher});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final fromTeacher = message.sender == teacher;
    return Align(
      alignment: fromTeacher ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          color: fromTeacher ? c.surface : c.primarySoft,
          border: Border.all(
            color: fromTeacher ? c.border : c.primary.withValues(alpha: .18),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(fromTeacher ? 4 : 14),
            bottomRight: Radius.circular(fromTeacher ? 14 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: fromTeacher ? c.primary : c.primaryInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.text,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12.5,
                height: 1.35,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                message.time,
                style: TextStyle(
                  fontFamily: SfType.mono,
                  fontSize: 9,
                  color: c.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AI strategic
// ════════════════════════════════════════════════════════════════════════
class AiAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const AiAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final insights = [
      (
        'Churn riski',
        PillTone.danger,
        ceo
            ? 'Sebzor filialida churn 6.2% — boshqalardan 2x. Oxirgi 3 oyda 3 o‘qituvchi almashdi.'
            : '6 o‘quvchi ketish belgilarini ko‘rsatmoqda.',
      ),
      (
        'O‘sish imkoniyati',
        PillTone.success,
        ceo
            ? 'Ingliz B2 guruhlari 90%+ to‘lgan. Yangi guruh +\$4.2k oylik daromad keltiradi.'
            : 'Ingliz B2 to‘lgan. Kutish ro‘yxatida 14 o‘quvchi bor.',
      ),
      (
        'Moliya',
        PillTone.warn,
        ceo
            ? '142 oila qarzdor (84 mln). Avtomatik eslatma to‘lovni ~6% oshiradi.'
            : '38 oila qarzdor (22.4 mln). 12 tasi 30 kundan oshgan.',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'AI tahlil', [
        _head(
          context,
          'AI yordamchi',
          'Strategik tahlil',
          ceo
              ? 'Barcha filiallar bo‘yicha biznes tahlili'
              : 'Filial operatsiyalari tahlili',
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final ins in insights)
                SfAiCard(
                  badge: ins.$1,
                  quote: ins.$3,
                  trailing: Pill(
                    ins.$2 == PillTone.danger
                        ? 'Yuqori'
                        : ins.$2 == PillTone.warn
                        ? 'O‘rta'
                        : 'Imkoniyat',
                    tone: ins.$2,
                    dot: true,
                  ),
                ),
              const SizedBox(height: 6),
              SfChips([
                'Churn sabablari',
                'Daromad prognozi',
                'O‘qituvchi reytingi',
                'Filiallarni solishtir',
              ], aiStyle: true),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// LEADS (kanban → stacked)
// ════════════════════════════════════════════════════════════════════════
class LeadsAdminPage extends StatelessWidget {
  final SfColors colors;
  const LeadsAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final cols = [
      (
        'Yangi',
        c.primary,
        [
          ('Olimov Aziz', 'Instagram', 'Matematika', '2 soat'),
          ('Sobirova Nilufar', 'Tavsiya', 'Ingliz B2', '5 soat'),
        ],
      ),
      (
        'Bog‘lanildi',
        c.accent,
        [
          ('Karimov Bek', 'Telegram', 'Fizika', 'Kecha'),
          ('Yusupova Dilfuza', 'Sayt', 'Matematika', 'Kecha'),
          ('Rashidov Temur', 'Instagram', 'Kimyo', '2 kun'),
        ],
      ),
      (
        'Sinov darsi',
        c.warn,
        [('Aliyeva Sevara', 'Tavsiya', 'Ingliz B2', '24 May')],
      ),
      (
        'Qabul qilindi',
        c.success,
        [
          ('Tosheva Madina', 'Sayt', 'Matematika', 'Bugun'),
          ('Norov Jasur', 'Telegram', 'Fizika', 'Kecha'),
        ],
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Lidlar · Qabul', [
        _head(
          context,
          'Yunusobod filiali',
          'Lidlar · Qabul',
          '34 ta faol lid · konversiya 28%',
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Faol lidlar',
                  value: '34',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(
                  label: 'Bu oy qabul',
                  value: '+86',
                  color: c.success,
                  trend: (up: true, v: '18%'),
                ),
                SfKpi(label: 'Konversiya', value: '28%', color: c.primary),
                SfKpi(label: 'O‘rt. qabul', value: '4.2 kun'),
              ]),
              const SizedBox(height: 14),
              for (final col in cols) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(
                    children: [
                      _dot(col.$2),
                      const SizedBox(width: 8),
                      Text(
                        col.$1,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${col.$3.length}',
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
                for (final l in col.$3)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 3, color: col.$2),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SfAvatar(name: l.$1, size: 26),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l.$1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: SfType.ui,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: c.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Pill(l.$3, tone: PillTone.primary),
                                      Pill(l.$2, tone: PillTone.neutral),
                                      _mono(
                                        context,
                                        l.$4,
                                        size: 10,
                                        color: c.muted,
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
                  ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// APPROVALS (rich, manager)
// ════════════════════════════════════════════════════════════════════════
class ApprovalsAdminPage extends StatefulWidget {
  final SfColors colors;
  const ApprovalsAdminPage({super.key, required this.colors});

  @override
  State<ApprovalsAdminPage> createState() => _ApprovalsAdminPageState();
}

class _ApprovalsAdminPageState extends State<ApprovalsAdminPage> {
  final Map<String, String> _decisions = {};

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final items = [
      (
        'To‘lov qaytarish',
        'Akbarov Akmal',
        'Ortiqcha to‘lov · iyun',
        600000,
        'Nigora Karimova',
        c.success,
      ),
      (
        'Ta‘til so‘rovi',
        'Yusupova Nargiza',
        '24–26 May · 3 kun · oilaviy',
        0,
        'O‘zi',
        c.primary,
      ),
      (
        'Yangi guruh ochish',
        'Ingliz B2 · Intensiv',
        'Aziz Tursunov · 18 o‘rin',
        0,
        'Aziz Tursunov',
        c.accent,
      ),
      (
        'Guruhdan chiqarish',
        'Eshmatov Otabek',
        '3+ oy qarz · 9-B',
        1200000,
        'Nigora Karimova',
        c.danger,
      ),
      (
        'Maosh oshirish',
        'Sevara Olimova',
        'Assistent → O‘qituvchi',
        7200000,
        'HR',
        c.warn,
      ),
      (
        'Chegirma',
        'Halimova Zilola',
        'Aka-uka · 15% · doimiy',
        0,
        'Nigora Karimova',
        c.primary,
      ),
      (
        'Material xarid',
        'Printer kartrij ×4',
        'Yunusobod · ofis',
        1800000,
        'Ofis',
        c.ink2,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Tasdiqlash', [
        _head(
          context,
          'Yunusobod filiali',
          'Tasdiqlash',
          '7 ta so‘rov kutmoqda',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [for (final it in items) _apprCard(context, it)],
          ),
        ),
      ]),
    );
  }

  Widget _apprCard(
    BuildContext context,
    (String, String, String, num, String, Color) it,
  ) {
    final c = SfTheme.of(context);
    final decision = _decisions[it.$1];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: it.$6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: it.$6.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.fact_check_rounded,
                            size: 16,
                            color: it.$6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.$1,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                it.$2,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 11.5,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (it.$4 > 0)
                          _mono(context, fmtMoney(it.$4), size: 13),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        it.$3,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11.5,
                          color: c.ink2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (decision == null)
                      Row(
                        children: [
                          Expanded(
                            child: SfButton(
                              key: ValueKey('approval-reject-${it.$1}'),
                              label: 'Rad',
                              primary: false,
                              onTap: () => _decide(it.$1, false),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SfButton(
                              key: ValueKey('approval-approve-${it.$1}'),
                              label: 'Tasdiqlash',
                              primary: true,
                              onTap: () => _decide(it.$1, true),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Pill(
                              decision,
                              tone: decision == 'Tasdiqlandi'
                                  ? PillTone.success
                                  : PillTone.danger,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _decisions.remove(it.$1)),
                            icon: const Icon(Icons.undo_rounded, size: 17),
                            label: const Text('Bekor qilish'),
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
    );
  }

  Future<void> _decide(String request, bool approve) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(approve ? 'So‘rovni tasdiqlash' : 'So‘rovni rad etish'),
            content: Text(
              approve
                  ? '“$request” so‘rovi tasdiqlangan holatga o‘tkazilsinmi?'
                  : '“$request” so‘rovi rad etilgan holatga o‘tkazilsinmi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Yo‘q'),
              ),
              FilledButton(
                key: const ValueKey('approval-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(approve ? 'Tasdiqlash' : 'Rad etish'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(
      () => _decisions[request] = approve ? 'Tasdiqlandi' : 'Rad etildi',
    );
    sfSnack(
      context,
      approve ? '“$request” tasdiqlandi' : '“$request” rad etildi',
      bg: approve ? const Color(0xFF4F7B3B) : const Color(0xFF9A4A42),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SCHEDULE (grid → list)
// ════════════════════════════════════════════════════════════════════════
class ScheduleAdminPage extends StatelessWidget {
  final SfColors colors;
  const ScheduleAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final lessons = [
      ('08:00', 'Fizika', 'Malika Y.', 'Xona 301', c.accent),
      ('09:30', '9-B Algebra', 'Nigora K.', 'Xona 304', c.primary),
      ('11:00', 'Ingliz B2', 'Aziz T.', 'Xona 302', c.success),
      ('14:00', 'Algebra Mid', 'Nigora K.', 'Xona 304', c.primary),
      ('15:30', 'Geometriya', 'Bobur A.', 'Xona 305', c.ink2),
      ('15:30', 'DTM', 'Malika Y.', 'Xona 301', c.accent),
      ('17:00', 'Kimyo', 'Jasur R.', 'Xona 210', c.warn),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Jadval · Xonalar', [
        _head(
          context,
          'Yunusobod · Seshanba',
          'Jadval',
          '5 xona · 28 guruh · bandlik 68%',
        ),
        Padding(
          padding: _pad,
          child: _listCard(
            rows: [
              for (int i = 0; i < lessons.length; i++)
                _Row(
                  lead: Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: _mono(
                      context,
                      lessons[i].$1,
                      size: 12,
                      color: lessons[i].$5,
                    ),
                  ),
                  title: lessons[i].$2,
                  sub: '${lessons[i].$3} · ${lessons[i].$4}',
                  last: i == lessons.length - 1,
                  trail: Container(
                    width: 4,
                    height: 30,
                    decoration: BoxDecoration(
                      color: lessons[i].$5,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DEPARTMENTS
// ════════════════════════════════════════════════════════════════════════
class DepartmentsAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const DepartmentsAdminPage({
    super.key,
    required this.colors,
    required this.ceo,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final depts = [
      ('Matematika', 'Nigora Karimova', 12, 18, c.primary),
      ('Ingliz tili', 'Aziz Tursunov', 14, 22, c.success),
      ('Tabiiy fanlar', 'Malika Yusupova', 9, 12, c.accent),
      ('Qabul · Reception', 'Gulnora Saidova', 8, 0, c.ink2),
      ('Sotuv · Marketing', 'Rustam Olimov', 5, 0, c.warn),
      ('Moliya · Buxgalteriya', 'Akmal Yusupov', 3, 0, c.success),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Bo‘limlar', [
        _head(
          context,
          ceo ? 'Barcha filiallar' : 'Yunusobod filiali',
          'Bo‘limlar',
          '6 bo‘lim · 51 xodim',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                const SfKpi(
                  label: 'Bo‘limlar',
                  value: '6',
                  icon: Icons.folder_rounded,
                ),
                SfKpi(label: 'Jami xodim', value: '51', color: c.primary),
                const SfKpi(
                  label: 'O‘qit. bo‘limlar',
                  value: '3',
                  sub: '35 o‘qituvchi',
                ),
                const SfKpi(label: 'Ma‘muriy', value: '3', sub: '16 xodim'),
              ]),
              const SizedBox(height: 12),
              _listCard(
                rows: [
                  for (int i = 0; i < depts.length; i++)
                    _Row(
                      lead: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: depts[i].$5,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      title: depts[i].$1,
                      sub: 'Boshliq: ${depts[i].$2}',
                      last: i == depts.length - 1,
                      trail: Text(
                        '${depts[i].$3} xodim${depts[i].$4 > 0 ? ' · ${depts[i].$4} guruh' : ''}',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11,
                          color: c.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HR
// ════════════════════════════════════════════════════════════════════════
class HrAdminPage extends StatelessWidget {
  final SfColors colors;
  final bool ceo;
  const HrAdminPage({super.key, required this.colors, required this.ceo});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final employees = [
      (
        'Nigora Karimova',
        'Katta o‘qituvchi',
        'Matematika',
        'To‘liq',
        8400000,
        '2021',
        'active',
      ),
      (
        'Aziz Tursunov',
        'O‘qituvchi',
        'Ingliz tili',
        'To‘liq',
        7800000,
        '2022',
        'active',
      ),
      (
        'Sevara Olimova',
        'Assistent',
        'Matematika',
        'Yarim',
        4200000,
        '2024',
        'active',
      ),
      (
        'Gulnora Saidova',
        'Reception boshlig‘i',
        'Qabul',
        'To‘liq',
        5600000,
        '2023',
        'active',
      ),
      (
        'Jasur Rahimov',
        'O‘qituvchi',
        'Tabiiy fanlar',
        'To‘liq',
        7000000,
        '2023',
        'leave',
      ),
      (
        'Nodira Karimova',
        'SMM menejer',
        'Marketing',
        'Soatbay',
        3800000,
        '2025',
        'active',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'HR · Xodimlar', [
        _head(
          context,
          ceo ? '82 xodim · 4 filial' : '16 xodim',
          'HR · Xodimlar',
          'Ishga qabul, shartnomalar va lavozimlar',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Jami xodim',
                  value: ceo ? '82' : '16',
                  icon: Icons.badge_rounded,
                  trend: (up: true, v: '4'),
                ),
                SfKpi(
                  label: 'Ochiq vakansiya',
                  value: '7',
                  color: c.warn,
                  sub: '3 ta shoshilinch',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(
                  label: 'Oylik fond',
                  value: fmtMoneyMln(ceo ? 512000000 : 96000000),
                  color: c.success,
                ),
                SfKpi(label: 'Ta‘tilda', value: '3', color: c.primary),
              ]),
              const SizedBox(height: 12),
              SfChips(['Hammasi', 'O‘qituvchi', 'Ma‘muriy', 'Ta‘tilda']),
              const SizedBox(height: 12),
              _listCard(
                title: 'Xodimlar · ${ceo ? 82 : 16}',
                rows: [
                  for (int i = 0; i < employees.length; i++)
                    Builder(
                      builder: (context) {
                        final e = employees[i];
                        final typeTone = e.$4 == 'To‘liq'
                            ? PillTone.success
                            : e.$4 == 'Yarim'
                            ? PillTone.warn
                            : PillTone.neutral;
                        return _Row(
                          lead: SfAvatar(name: e.$1, size: 32),
                          title: e.$1,
                          sub: '${e.$2} · ${e.$3} · ${e.$6}',
                          last: i == employees.length - 1,
                          trail: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Pill(
                                e.$7 == 'active' ? e.$4 : 'Ta‘tilda',
                                tone: e.$7 == 'active'
                                    ? typeTone
                                    : PillTone.primary,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: _mono(
                                  context,
                                  fmtMoneyShort(e.$5),
                                  size: 10,
                                  color: c.ink2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PAYROLL
// ════════════════════════════════════════════════════════════════════════
class PayrollAdminPage extends StatefulWidget {
  final SfColors colors;
  final bool ceo;
  const PayrollAdminPage({super.key, required this.colors, required this.ceo});

  @override
  State<PayrollAdminPage> createState() => _PayrollAdminPageState();
}

class _PayrollAdminPageState extends State<PayrollAdminPage> {
  String _month = 'Июль 2026';
  bool _approved = false;

  Future<void> _selectMonth() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Расчётный период'),
              subtitle: Text('Выберите месяц зарплаты'),
            ),
            for (final month in const ['Май 2026', 'Июнь 2026', 'Июль 2026'])
              ListTile(
                leading: Icon(
                  month == _month
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month_outlined,
                ),
                title: Text(month),
                onTap: () => Navigator.of(context).pop(month),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _month = value;
        _approved = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final rows = [
      ('Nigora Karimova', 'Matematika', 6000000, 900000, 600000, 900000),
      ('Aziz Tursunov', 'Ingliz tili', 5500000, 1100000, 600000, 600000),
      ('Bobur Aliyev', 'Matematika', 5500000, 750000, 500000, 850000),
      ('Sevara Olimova', 'Matematika', 3500000, 400000, 300000, 0),
      ('Malika Yusupova', 'Tabiiy fanlar', 5500000, 600000, 400000, 700000),
      ('Gulnora Saidova', 'Qabul', 5000000, 0, 400000, 200000),
    ];
    final tot = rows.fold<num>(0, (a, r) => a + r.$3 + r.$4 + r.$5 + r.$6);
    return SfTheme(
      colors: c,
      child: _page(c, 'Зарплаты', [
        _head(
          context,
          '$_month · ${_approved ? 'утверждено' : 'черновик'}',
          'Зарплаты',
          'Оклад, бонусы и итоговая сумма по каждому сотруднику',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('payroll-period'),
                      onPressed: _selectMonth,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(_month),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('payroll-approve'),
                      onPressed: () {
                        setState(() => _approved = true);
                        _showRecordDetails(
                          context,
                          title: 'Зарплаты утверждены',
                          icon: Icons.verified_rounded,
                          fields: {
                            'Период': _month,
                            'Сотрудников': '${rows.length}',
                            'Общий фонд': fmtMoneyMln(tot),
                            'Статус': 'Утверждено',
                            'Утвердил': widget.ceo
                                ? 'CEO'
                                : 'Ответственный менеджер',
                          },
                        );
                      },
                      icon: const Icon(Icons.verified_rounded),
                      label: Text(_approved ? 'Утверждено' : 'Утвердить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('payroll-recalculate'),
                  onPressed: () => _showRecordDetails(
                    context,
                    title: 'Проверка расчёта',
                    icon: Icons.calculate_outlined,
                    fields: {
                      'Период': _month,
                      'Оклад': fmtMoneyMln(
                        rows.fold<num>(0, (sum, row) => sum + row.$3),
                      ),
                      'Бонус за KPI': fmtMoneyMln(
                        rows.fold<num>(0, (sum, row) => sum + row.$4),
                      ),
                      'Бонус за посещаемость': fmtMoneyMln(
                        rows.fold<num>(0, (sum, row) => sum + row.$5),
                      ),
                      'Доплаты': fmtMoneyMln(
                        rows.fold<num>(0, (sum, row) => sum + row.$6),
                      ),
                      'Итого': fmtMoneyMln(tot),
                    },
                  ),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Пересчитать и проверить фонд'),
                ),
              ),
              const SizedBox(height: 12),
              sfKpiGrid([
                SfKpi(
                  label: 'Jami fond',
                  value: fmtMoneyMln(tot),
                  color: c.success,
                  icon: Icons.trending_up_rounded,
                ),
                SfKpi(
                  label: 'Asosiy maosh',
                  value: fmtMoneyMln(rows.fold<num>(0, (a, r) => a + r.$3)),
                ),
                SfKpi(
                  label: 'Bonuslar',
                  value: fmtMoneyMln(
                    rows.fold<num>(0, (a, r) => a + r.$4 + r.$5 + r.$6),
                  ),
                  color: c.accent,
                  sub: 'KPI + посещаемость',
                ),
                SfKpi(
                  label: 'Holat',
                  value: _approved ? 'Готово' : 'Черновик',
                  color: c.warn,
                  sub: _approved ? 'утверждено' : 'ожидает утверждения',
                ),
              ]),
              const SizedBox(height: 12),
              _listCard(
                rows: [
                  for (int i = 0; i < rows.length; i++)
                    Builder(
                      builder: (context) {
                        final r = rows[i];
                        final total = r.$3 + r.$4 + r.$5 + r.$6;
                        return _Row(
                          lead: SfAvatar(name: r.$1, size: 30),
                          title: r.$1,
                          sub:
                              '${r.$2} · asos ${fmtMoneyShort(r.$3)} + bonus ${fmtMoneyShort(r.$4 + r.$5 + r.$6)}',
                          last: i == rows.length - 1,
                          trail: _mono(
                            context,
                            fmtMoneyShort(total),
                            size: 12,
                            color: c.success,
                          ),
                          onTap: () => _showRecordDetails(
                            context,
                            title: r.$1,
                            icon: Icons.receipt_long_rounded,
                            fields: {
                              'Период': _month,
                              'Сотрудник': r.$1,
                              'Должность / предмет': r.$2,
                              'Оклад': fmtMoneyShort(r.$3),
                              'Бонус за KPI': fmtMoneyShort(r.$4),
                              'Бонус за посещаемость': fmtMoneyShort(r.$5),
                              'Другие доплаты': fmtMoneyShort(r.$6),
                              'Итого начислено': fmtMoneyShort(total),
                              'Способ выплаты': 'Банковская карта',
                              'Статус': _approved ? 'Утверждено' : 'Черновик',
                            },
                          ),
                        );
                      },
                    ),
                  Container(
                    color: c.surface2,
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'JAMI · ${rows.length} xodim',
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        _mono(
                          context,
                          fmtMoneyMln(tot),
                          size: 13,
                          color: c.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PERMISSIONS (RBAC)
// ════════════════════════════════════════════════════════════════════════
class PermissionsAdminPage extends StatelessWidget {
  final SfColors colors;
  const PermissionsAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final roles = SfRole.values;
    return SfTheme(
      colors: c,
      child: _page(c, 'Ruxsatlar · RBAC', [
        _head(
          context,
          'Rol va ruxsatlar',
          'Ruxsatlar · RBAC',
          '${roles.length} ta amaldagi rol · faqat ko‘rish',
        ),
        Padding(
          padding: _pad,
          child: _listCard(
            title: 'Rollar',
            rows: [
              for (int i = 0; i < roles.length; i++)
                _Row(
                  key: ValueKey('permission-role-${roles[i].name}'),
                  lead: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _permissionRoleColor(c, roles[i]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  title: kRoleConfigs[roles[i]]!.label,
                  sub:
                      '${navigationRoutesFor(roles[i]).length} route · ${kRoleConfigs[roles[i]]!.scope}',
                  last: i == roles.length - 1,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _PermissionMatrixDetailPage(
                        colors: c,
                        role: roles[i],
                      ),
                    ),
                  ),
                  trail: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roles[i] == SfRole.ceo) ...[
                        const Pill('tizim', tone: PillTone.neutral),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: c.muted2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

Color _permissionRoleColor(SfColors colors, SfRole role) => switch (role) {
  SfRole.ceo => colors.primary,
  SfRole.manager => colors.success,
  SfRole.audit => _purple,
  SfRole.student => colors.accent,
};

String _permissionActionFor(String route, SfRole role) => switch (route) {
  'dash' => 'Просмотр показателей',
  'branches' => 'Просмотр · настройка',
  'comparison' || 'history' => 'Только чтение',
  'students' => 'Просмотр профилей',
  'groups' => 'Просмотр · управление',
  'teachers' || 'hr' || 'departments' || 'meetings' => 'Просмотр · управление',
  'parents' => 'Просмотр профилей',
  'attendance' when role == SfRole.manager => 'Просмотр · отметка',
  'attendance' => 'Только чтение',
  'payments' => 'Просмотр операций',
  'report' => 'Просмотр · экспорт',
  'payroll' => 'Только чтение',
  'leads' || 'enroll' || 'schedule' => 'Просмотр процесса',
  'approvals' => 'Просмотр · решение',
  'messages' => 'Чтение · отправка',
  'chats' => 'Только чтение',
  'ai' => 'AI-запросы',
  'notifications' => 'Просмотр',
  'permissions' => 'Только чтение',
  'settings' => 'Настройка подключения',
  'anomalies' => 'Просмотр · решение',
  'fairness' ||
  'finance' ||
  'logs' ||
  'aiusage' ||
  'surveys' => 'Только чтение',
  'cases' => 'Просмотр · смена статуса',
  _ => 'Просмотр',
};

class _PermissionMatrixDetailPage extends StatelessWidget {
  final SfColors colors;
  final SfRole role;

  const _PermissionMatrixDetailPage({required this.colors, required this.role});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final config = kRoleConfigs[role]!;
    final groups = menuFor(role);
    final count = navigationRoutesFor(role).length;
    return SfTheme(
      colors: c,
      child: Scaffold(
        key: ValueKey('permission-matrix-${role.name}'),
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            '${config.label} · permissions',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _permissionRoleColor(
                            c,
                            role,
                          ).withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          role == SfRole.audit
                              ? Icons.shield_rounded
                              : role == SfRole.manager
                              ? Icons.business_center_rounded
                              : Icons.account_balance_rounded,
                          color: _permissionRoleColor(c, role),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              configLabel(context, config.roleTitle),
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              config.scope,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 11,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pill('$count route', tone: PillTone.neutral),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'Матрица формируется из фактического menuFor(${role.name}). Изменение разрешений на этом экране отключено.',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      height: 1.4,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
                child: Text(
                  group.title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                    color: c.muted,
                  ),
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    for (var index = 0; index < group.items.length; index++)
                      _PermissionRouteRow(
                        key: ValueKey(
                          'permission-route-${group.items[index].id}',
                        ),
                        item: group.items[index],
                        role: role,
                        scope: config.scope,
                        last: index == group.items.length - 1,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SfCard(
              child: _PermissionRouteRow(
                key: const ValueKey('permission-route-me'),
                item: const MenuItem(
                  'me',
                  'Profil',
                  Icons.person_outline_rounded,
                ),
                role: role,
                scope: 'Собственный профиль',
                last: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRouteRow extends StatelessWidget {
  final MenuItem item;
  final SfRole role;
  final String scope;
  final bool last;

  const _PermissionRouteRow({
    super.key,
    required this.item,
    required this.role,
    required this.scope,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.icon, size: 16, color: c.ink2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.id,
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 9,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_permissionActionFor(item.id, role)} · $scope',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    height: 1.3,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Icon(Icons.visibility_rounded, size: 15, color: c.success),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// MEETINGS
// ════════════════════════════════════════════════════════════════════════
class MeetingsAdminPage extends StatelessWidget {
  final SfColors colors;
  const MeetingsAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final meetings = [
      (
        'Haftalik filial yig‘ilishi',
        'Butun filial · 16 kishi',
        '19',
        'Bugun · 17:00',
        'Konferens zal',
        c.primary,
        true,
      ),
      (
        'Matematika · metodik',
        'Matematika bo‘limi · 12',
        '20',
        'Ertaga · 14:00',
        'Onlayn · Zoom',
        c.accent,
        false,
      ),
      (
        'Sotuv natijalari · oylik',
        'Sotuv · Marketing · 5',
        '23',
        '23 May · 11:00',
        '301-xona',
        c.warn,
        false,
      ),
      (
        'Yangi o‘qituvchilar treningi',
        'Tanlangan · 6 kishi',
        '24',
        '24 May · 10:00',
        'O‘quv zal',
        c.success,
        false,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Yig‘ilishlar', [
        _head(
          context,
          'Yunusobod filiali',
          'Yig‘ilishlar',
          'Bo‘lim yoki jamoa uchun yig‘ilish',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (final m in meetings)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 56,
                          color: m.$6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m.$3,
                                style: const TextStyle(
                                  fontFamily: SfType.mono,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'May',
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m.$1,
                                        style: TextStyle(
                                          fontFamily: SfType.ui,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: c.ink,
                                        ),
                                      ),
                                    ),
                                    if (m.$7)
                                      const Pill(
                                        'Bugun',
                                        tone: PillTone.primary,
                                        dot: true,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${m.$4} · ${m.$5}',
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 11,
                                    color: c.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.$2,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 10.5,
                                    color: c.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// MESSAGES hub (admin) — simplified thread list
// ════════════════════════════════════════════════════════════════════════
class MessagesAdminPage extends StatelessWidget {
  final SfColors colors;
  const MessagesAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final threads = [
      (
        'Nigora Karimova',
        'O‘qituvchi · Matematika',
        'Ertangi yig‘ilishga tayyorman',
        '14:42',
        0,
        true,
        false,
      ),
      (
        'Matematika bo‘limi',
        'Guruh · 12 a‘zo',
        'Siz: Yangi mavzular...',
        '13:20',
        0,
        false,
        true,
      ),
      (
        'Akbarova Dilnoza',
        'Ota-ona · Akmal · 9-B',
        'Rahmat ustoz!',
        '12:18',
        2,
        false,
        false,
      ),
      (
        'Aziz Tursunov',
        'O‘qituvchi · Ingliz',
        'Yangi guruh ochsak?',
        '11:05',
        1,
        true,
        false,
      ),
      (
        'Halimova Zilola',
        'O‘quvchi · 9-B',
        'Uy ishini yubordim',
        'Du',
        0,
        false,
        false,
      ),
      (
        'Qabul bo‘limi',
        'Guruh · 8 a‘zo',
        'Bugun 6 ta yangi lid',
        'Du',
        3,
        false,
        true,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Xabarlar', [
        _head(
          context,
          'Aloqa markazi',
          'Xabarlar',
          'O‘qituvchi, ota-ona, o‘quvchi va xodimlar',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              SfChips([
                'Hammasi',
                'Xodimlar',
                'O‘qituvchilar',
                'Ota-onalar',
                'O‘quvchilar',
              ]),
              const SizedBox(height: 12),
              _listCard(
                rows: [
                  for (int i = 0; i < threads.length; i++)
                    _Row(
                      lead: threads[i].$7
                          ? Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: SfStar(size: 16, color: c.surface),
                              ),
                            )
                          : SfAvatar(name: threads[i].$1, size: 34),
                      title: threads[i].$1,
                      sub: threads[i].$3,
                      last: i == threads.length - 1,
                      onTap: () => _showRecordDetails(
                        context,
                        title: threads[i].$1,
                        icon: Icons.forum_rounded,
                        fields: {
                          'Kim': threads[i].$2,
                          'Oxirgi xabar': threads[i].$3,
                          'Vaqt': threads[i].$4,
                          'O‘qilmagan': '${threads[i].$5}',
                          'Faol': threads[i].$6 ? 'Ha' : 'Yo‘q',
                          'Guruh suhbati': threads[i].$7 ? 'Ha' : 'Yo‘q',
                        },
                      ),
                      trail: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _mono(
                            context,
                            threads[i].$4,
                            size: 9.5,
                            color: c.muted,
                          ),
                          if (threads[i].$5 > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${threads[i].$5}',
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: c.surface,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// ENROLL (test funnel)
// ════════════════════════════════════════════════════════════════════════
class EnrollAdminPage extends StatefulWidget {
  final SfColors colors;
  const EnrollAdminPage({super.key, required this.colors});

  @override
  State<EnrollAdminPage> createState() => _EnrollAdminPageState();
}

class _EnrollAdminPageState extends State<EnrollAdminPage> {
  final List<({String name, String target, int score})> _results = [];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final steps = [
      (
        'Ariza',
        'Yangi nomzod ma‘lumotlari',
        Icons.person_add_rounded,
        c.primary,
        true,
      ),
      (
        'Daraja testi',
        'Avtomatik test · 20 savol',
        Icons.quiz_rounded,
        c.accent,
        true,
      ),
      (
        'Natija',
        'Ball va daraja aniqlanadi',
        Icons.assessment_rounded,
        c.warn,
        false,
      ),
      (
        'Joylashtirish',
        'Mos guruhga biriktirish',
        Icons.groups_rounded,
        c.success,
        false,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Qabul · Test', [
        _head(
          context,
          'Yunusobod filiali',
          'Qabul · Test',
          'Daraja testi orqali guruhga joylash',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Bu oy test',
                  value: '124',
                  icon: Icons.quiz_rounded,
                ),
                SfKpi(
                  label: 'Qabul qilindi',
                  value: '86',
                  color: c.success,
                  trend: (up: true, v: '18%'),
                ),
                SfKpi(
                  label: 'O‘rtacha ball',
                  value: '72',
                  color: c.primary,
                  sub: '100 dan',
                ),
                SfKpi(label: 'Konversiya', value: '69%', color: c.accent),
              ]),
              const SizedBox(height: 12),
              _listCard(
                title: 'Qabul bosqichlari',
                rows: [
                  for (int i = 0; i < steps.length; i++)
                    _Row(
                      lead: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: steps[i].$4.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(steps[i].$3, size: 18, color: steps[i].$4),
                      ),
                      title: '${i + 1}. ${steps[i].$1}',
                      sub: steps[i].$2,
                      last: i == steps.length - 1,
                      trail: Pill(
                        steps[i].$5 ? 'Tayyor' : 'Avto',
                        tone: steps[i].$5 ? PillTone.success : PillTone.neutral,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SfButton(
                icon: Icons.add_rounded,
                label: 'Yangi nomzod · test boshlash',
                primary: true,
                onTap: () async {
                  final result = await Navigator.of(context)
                      .push<({String name, String target, int score})>(
                        MaterialPageRoute(
                          builder: (_) => SfTheme(
                            colors: c,
                            child: const _EnrollmentTestPage(),
                          ),
                        ),
                      );
                  if (result == null || !mounted) return;
                  setState(() => _results.insert(0, result));
                },
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                _listCard(
                  title: 'Oxirgi natijalar',
                  rows: [
                    for (var index = 0; index < _results.length; index++)
                      _Row(
                        lead: SfAvatar(name: _results[index].name, size: 32),
                        title: _results[index].name,
                        sub: _results[index].target,
                        last: index == _results.length - 1,
                        trail: Pill(
                          '${_results[index].score}%',
                          tone: _results[index].score >= 50
                              ? PillTone.success
                              : PillTone.warn,
                        ),
                        onTap: () => _showRecordDetails(
                          context,
                          title: _results[index].name,
                          icon: Icons.assignment_turned_in_rounded,
                          fields: {
                            'Yo‘nalish': _results[index].target,
                            'Natija': '${_results[index].score}%',
                            'Tavsiya': _results[index].score >= 75
                                ? 'Yuqori daraja guruhi'
                                : _results[index].score >= 50
                                ? 'O‘rta daraja guruhi'
                                : 'Foundation guruhi',
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _EnrollmentTestPage extends StatefulWidget {
  const _EnrollmentTestPage();

  @override
  State<_EnrollmentTestPage> createState() => _EnrollmentTestPageState();
}

class _EnrollmentTestPageState extends State<_EnrollmentTestPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _target = 'English';
  int _step = 0;
  final List<int> _answers = List<int>.filled(4, -1);

  static const _questions = [
    (
      'Choose the correct sentence',
      ['She go to school.', 'She goes to school.', 'She going school.'],
      1,
    ),
    ('Past tense of “teach”', ['teached', 'taught', 'teach'], 1),
    ('12 × 8', ['86', '96', '108'], 1),
    ('Davomini toping: 2, 4, 8, 16, …', ['24', '30', '32'], 2),
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  int get _score {
    var correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].$3) correct++;
    }
    return (correct / _questions.length * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SfScaffold(
      colors: c,
      title: _step == 0
          ? 'Nomzod ma’lumotlari'
          : _step == 1
          ? 'Daraja testi'
          : 'Test natijasi',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: _step == 0
              ? _candidateForm(c)
              : _step == 1
              ? _testForm(c)
              : _result(c),
        ),
      ),
    );
  }

  Widget _candidateForm(SfColors c) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SfCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('enroll-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'To‘liq ism',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Ismni to‘liq kiriting'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('enroll-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      hintText: '+998 90 123 45 67',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) =>
                        (value ?? '').replaceAll(RegExp(r'\D'), '').length < 9
                        ? 'Telefon raqamini tekshiring'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('enroll-target'),
                    initialValue: _target,
                    decoration: const InputDecoration(
                      labelText: 'Yo‘nalish',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(value: 'IT', child: Text('IT')),
                      DropdownMenuItem(
                        value: 'Matematika',
                        child: Text('Matematika'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _target = value ?? _target),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SfButton(
            icon: Icons.play_arrow_rounded,
            label: 'Testni boshlash',
            primary: true,
            onTap: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _step = 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _testForm(SfColors c) {
    final answered = _answers.where((answer) => answer >= 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: answered / _questions.length,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        Text(
          '$answered / ${_questions.length} savol javoblandi',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _questions.length; index++) ...[
          SfCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${_questions[index].$1}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.ink),
                  ),
                  const SizedBox(height: 9),
                  RadioGroup<int>(
                    groupValue: _answers[index],
                    onChanged: (value) =>
                        setState(() => _answers[index] = value ?? -1),
                    child: Column(
                      children: [
                        for (
                          var option = 0;
                          option < _questions[index].$2.length;
                          option++
                        )
                          RadioListTile<int>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: option,
                            title: Text(_questions[index].$2[option]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SfButton(
          icon: Icons.check_circle_outline_rounded,
          label: 'Natijani hisoblash',
          primary: true,
          onTap: () {
            if (answered != _questions.length) {
              sfSnack(context, 'Barcha savollarga javob bering');
              return;
            }
            setState(() => _step = 2);
          },
        ),
      ],
    );
  }

  Widget _result(SfColors c) {
    final level = _score >= 75
        ? 'Yuqori daraja'
        : _score >= 50
        ? 'O‘rta daraja'
        : 'Boshlang‘ich daraja';
    return Column(
      children: [
        SfCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.verified_rounded, size: 54, color: c.success),
                const SizedBox(height: 10),
                Text(
                  '${_name.text.trim()} · $_score%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text('$level · $_target', style: TextStyle(color: c.muted)),
                const SizedBox(height: 14),
                Pill(
                  _score >= 50 ? 'Guruh tavsiya qilindi' : 'Foundation tavsiya',
                  tone: _score >= 50 ? PillTone.success : PillTone.warn,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SfButton(
          icon: Icons.refresh_rounded,
          label: 'Testni qayta topshirish',
          primary: false,
          onTap: () => setState(() {
            _answers.fillRange(0, _answers.length, -1);
            _step = 1;
          }),
        ),
        const SizedBox(height: 8),
        SfButton(
          icon: Icons.done_rounded,
          label: 'Natijani saqlash',
          primary: true,
          onTap: () => Navigator.pop(context, (
            name: _name.text.trim(),
            target: _target,
            score: _score,
          )),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Anomalies (rich)
// ════════════════════════════════════════════════════════════════════════
class AnomaliesAdminPage extends StatelessWidget {
  final SfColors colors;
  const AnomaliesAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final rows = [
      (
        'Посещаемость 100% · 21 kun ketma-ket',
        'Посещаемость',
        'Sebzor · Fizika DTM',
        94,
        'high',
        '2 soat',
        'open',
      ),
      (
        'Bir o‘qituvchi · 48 Up karta/hafta',
        'Karta',
        'Mirobod · M. Yusupova',
        72,
        'med',
        '5 soat',
        'open',
      ),
      (
        'Naqd to‘lov · kvitansiyasiz · 3.2 mln',
        'Moliya',
        'Sebzor · ofis',
        88,
        'high',
        'Kecha',
        'review',
      ),
      (
        'Profil 02:14 da o‘zgartirilgan',
        'Kirish',
        'Chilonzor · admin',
        34,
        'low',
        'Kecha',
        'open',
      ),
      (
        'So‘rovnoma · 30s ichida to‘ldirilgan',
        'So‘rovnoma',
        'Yunusobod · 8 ta',
        61,
        'med',
        '2 kun',
        'review',
      ),
      (
        'Down karta 0 · 3 oy davomida',
        'Karta',
        'Sebzor · J. Rahimov',
        58,
        'med',
        '3 kun',
        'open',
      ),
      (
        'To‘lov qaytarish · ketma-ket 4 ta',
        'Moliya',
        'Mirobod · ofis',
        81,
        'high',
        '4 kun',
        'open',
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Anomaliyalar', [
        _head(
          context,
          '12 ta ochiq signal',
          'Anomaliyalar',
          'AI aniqlagan g‘ayritabiiy naqshlar',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterList<
                (String, String, String, int, String, String, String)
              >(
                chips: [
                  'Hammasi',
                  'Посещаемость',
                  'Karta',
                  'Moliya',
                  'Kirish',
                  'Yuqori',
                ],
                items: rows,
                match: (r, chip) {
                  switch (chip) {
                    case 'Yuqori':
                      return r.$5 == 'high';
                    case 'Посещаемость':
                    case 'Karta':
                    case 'Moliya':
                    case 'Kirish':
                      return r.$2 == chip;
                    default:
                      return true;
                  }
                },
                row: (context, r, last) {
                  final sevColor = r.$5 == 'high'
                      ? c.danger
                      : r.$5 == 'med'
                      ? c.warn
                      : c.muted;
                  final scoreColor = r.$4 >= 80
                      ? c.danger
                      : r.$4 >= 60
                      ? c.warn
                      : c.muted;
                  return _Row(
                    lead: _dot(sevColor),
                    title: r.$1,
                    sub: '${r.$3} · ${r.$2} · ${r.$6}',
                    last: last,
                    onTap: () => _showRecordDetails(
                      context,
                      title: r.$1,
                      icon: Icons.warning_amber_rounded,
                      fields: {
                        'Turi': r.$2,
                        'Manba': r.$3,
                        'AI skor': '${r.$4} / 100',
                        'Muhimlik': r.$5,
                        'Aniqlangan': r.$6,
                        'Holat': r.$7,
                      },
                    ),
                    trail: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _mono(context, '${r.$4}', size: 14, color: scoreColor),
                        Text(
                          'AI skor',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 9,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Card fairness
// ════════════════════════════════════════════════════════════════════════
class FairnessAdminPage extends StatelessWidget {
  final SfColors colors;
  const FairnessAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final teachers = [
      (
        'Aziz Tursunov',
        'Chilonzor',
        22,
        2,
        '11:1',
        'O‘ta saxiy',
        PillTone.warn,
      ),
      (
        'Malika Yusupova',
        'Mirobod',
        48,
        6,
        '8:1',
        'Juda ko‘p',
        PillTone.danger,
      ),
      (
        'Nigora Karimova',
        'Yunusobod',
        18,
        4,
        '4.5:1',
        'Muvozanatli',
        PillTone.success,
      ),
      ('Jasur Rahimov', 'Sebzor', 6, 0, '∞', 'Down yo‘q', PillTone.warn),
      (
        'Bobur Aliyev',
        'Yunusobod',
        15,
        3,
        '5:1',
        'Muvozanatli',
        PillTone.success,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Karta adolati', [
        _head(
          context,
          '5 ta signal',
          'Karta adolati',
          'Up/Down kartalar adolatli taqsimlanyaptimi?',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'O‘rt. Up/Down',
                  value: '6.2:1',
                  color: c.primary,
                  sub: 'me‘yor: 4-5:1',
                ),
                SfKpi(
                  label: 'O‘ta saxiy',
                  value: '2',
                  color: c.warn,
                  sub: 'o‘qituvchi',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(
                  label: 'Down bermagan',
                  value: '1',
                  color: c.danger,
                  sub: '3+ oy',
                ),
                const SfKpi(
                  label: 'Tekshirilgan',
                  value: '54',
                  sub: 'o‘qituvchi',
                ),
              ]),
              const SizedBox(height: 12),
              _listCard(
                rows: [
                  for (int i = 0; i < teachers.length; i++)
                    _Row(
                      lead: SfAvatar(name: teachers[i].$1, size: 30),
                      title: teachers[i].$1,
                      sub:
                          '${teachers[i].$2} · ↑${teachers[i].$3} ↓${teachers[i].$4} · ${teachers[i].$5}',
                      last: i == teachers.length - 1,
                      trail: Pill(teachers[i].$6, tone: teachers[i].$7),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Finance reconciliation
// ════════════════════════════════════════════════════════════════════════
class FinanceAuditPage extends StatelessWidget {
  final SfColors colors;
  const FinanceAuditPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final rows = [
      (
        '15.05',
        'Naqd to‘lov · Sebzor · kvitansiyasiz',
        3200000,
        2000000,
        'Jiddiy',
        PillTone.danger,
      ),
      (
        '12.05',
        'Click qaytarish · Mirobod',
        600000,
        0,
        'Tekshir',
        PillTone.warn,
      ),
      (
        '08.05',
        'Bank komissiyasi · hisobga olinmagan',
        0,
        600000,
        'Kichik',
        PillTone.neutral,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Moliyaviy tekshir', [
        _head(
          context,
          'Moliyaviy tekshiruv',
          'Reconciliation',
          'Tizim yozuvlari ↔ haqiqiy tushum',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Tizim yozuvi',
                  value: fmtMoneyMln(1284000000),
                  icon: Icons.description_rounded,
                ),
                SfKpi(
                  label: 'Bank/kassa',
                  value: fmtMoneyMln(1281600000),
                  color: c.success,
                ),
                SfKpi(
                  label: 'Farq',
                  value: fmtMoneyMln(2400000),
                  color: c.danger,
                  sub: '0.19% · 3 yozuv',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(label: 'Tasdiqlangan', value: '98.4%', color: c.success),
              ]),
              const SizedBox(height: 12),
              _listCard(
                title: 'Mos kelmagan yozuvlar · 3 ta',
                rows: [
                  for (int i = 0; i < rows.length; i++)
                    _Row(
                      lead: SizedBox(
                        width: 40,
                        child: _mono(
                          context,
                          rows[i].$1,
                          size: 11,
                          color: c.muted,
                        ),
                      ),
                      title: rows[i].$2,
                      sub:
                          'Tizim ${fmtMoneyShort(rows[i].$3)} · Haqiqiy ${fmtMoneyShort(rows[i].$4)}',
                      last: i == rows.length - 1,
                      trail: Pill(rows[i].$5, tone: rows[i].$6),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Access logs
// ════════════════════════════════════════════════════════════════════════
class LogsAdminPage extends StatelessWidget {
  final SfColors colors;
  const LogsAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final logs = [
      (
        'Dilnoza Yo‘ldosheva',
        'Manager',
        'To‘lov yozuvini o‘zgartirdi',
        '09:42',
        false,
      ),
      ('admin_yun', 'Admin', 'Profilni 02:14 da o‘zgartirdi', '02:14', true),
      (
        'Sardor Rashidov',
        'CEO',
        'Moliya hisobotini eksport qildi',
        '08:30',
        false,
      ),
      ('Malika Yusupova', 'O‘qituvchi', '48 ta karta berdi', 'Kecha', true),
      ('Jamshid Qodirov', 'Audit', 'Suhbatni ko‘rdi', 'Kecha', false),
      (
        'office_seb',
        'Ofis',
        'Kvitansiyasiz naqd qabul · 3.2 mln',
        '2 kun',
        true,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Kirish jurnali', [
        _head(
          context,
          'Kirish va harakatlar',
          'Kirish jurnali',
          'Barcha harakatlar · o‘zgarmas yozuv',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterList<(String, String, String, String, bool)>(
                chips: [
                  'Hammasi',
                  'Riskli',
                  'Moliya',
                  'Profil',
                  'Kartalar',
                  'Tungi soat',
                ],
                items: logs,
                match: (l, chip) {
                  final act = l.$3.toLowerCase();
                  switch (chip) {
                    case 'Riskli':
                      return l.$5;
                    case 'Moliya':
                      return act.contains('to‘lov') ||
                          act.contains('moliya') ||
                          act.contains('naqd');
                    case 'Profil':
                      return act.contains('profil');
                    case 'Kartalar':
                      return act.contains('karta');
                    case 'Tungi soat':
                      return l.$4.startsWith('0') || l.$4.startsWith('02');
                    default:
                      return true;
                  }
                },
                row: (context, l, last) => _Row(
                  lead: l.$5 ? _dot(c.danger) : _dot(c.muted2),
                  title: l.$1,
                  sub: l.$3,
                  last: last,
                  trail: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Pill(l.$2, tone: PillTone.neutral),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _mono(
                          context,
                          l.$4,
                          size: 10,
                          color: l.$5 ? c.danger : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: AI usage
// ════════════════════════════════════════════════════════════════════════
class AiUsageAdminPage extends StatelessWidget {
  final SfColors colors;
  const AiUsageAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SfTheme(
      colors: c,
      child: _page(c, 'AI monitoring', [
        _head(
          context,
          'AI monitoring',
          'AI ishlatilishi',
          'Token sarfi, narx va nazorat',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                SfKpi(
                  label: 'Jami token',
                  value: '284k',
                  color: c.ai,
                  sub: '/ 1M limit',
                  icon: Icons.auto_awesome_rounded,
                ),
                SfKpi(
                  label: 'AI xarajati',
                  value: fmtMoneyMln(3400000),
                  sub: 'bu oy',
                ),
                const SfKpi(
                  label: 'Faol foydalanuvchi',
                  value: '48',
                  sub: '54 dan',
                ),
                SfKpi(
                  label: 'Anomaliya',
                  value: '2',
                  color: c.warn,
                  sub: 'ortiqcha sarf',
                  icon: Icons.flag_rounded,
                ),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader('Token sarfi · 30 kun'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                      child: AreaChart(
                        color: c.ai,
                        height: 120,
                        data: const [
                          6,
                          8,
                          7,
                          10,
                          9,
                          12,
                          11,
                          14,
                          13,
                          16,
                          15,
                          18,
                        ].map((e) => (e * 1000).toDouble()).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader('Eng faol foydalanuvchilar'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: HBars(
                        rows: [
                          HBarRow('N. Karimova', 42, '42k', c.primary),
                          HBarRow('A. Tursunov', 38, '38k', c.primary),
                          HBarRow('B. Aliyev', 31, '31k', c.accent),
                          HBarRow('D. Yo‘ldosheva', 28, '28k', c.warn),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Survey integrity
// ════════════════════════════════════════════════════════════════════════
class SurveyAuditPage extends StatelessWidget {
  final SfColors colors;
  const SurveyAuditPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final rows = [
      (
        'Oylik qoniqish',
        'Yunusobod',
        '8 ta · 30s ichida',
        '18s',
        PillTone.danger,
      ),
      ('Karta tizimi', 'Mirobod', 'Bir IP · 3 javob', '45s', PillTone.danger),
      ('AI sifati', 'Chilonzor', 'Bir xil javoblar', '1m 12s', PillTone.warn),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'So‘rovnoma nazorati', [
        _head(
          context,
          'So‘rovnoma yaxlitligi',
          'So‘rovnoma nazorati',
          'Soxta yoki shoshma javoblar',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              sfKpiGrid([
                const SfKpi(
                  label: 'Jami javob',
                  value: '412',
                  icon: Icons.fact_check_rounded,
                ),
                SfKpi(
                  label: 'Shubhali',
                  value: '8',
                  color: c.warn,
                  sub: '30s dan tez',
                  icon: Icons.flag_rounded,
                ),
                SfKpi(
                  label: 'Bir xil naqsh',
                  value: '3',
                  color: c.danger,
                  sub: 'bir IP',
                ),
                SfKpi(label: 'Yaxlitlik', value: '97.3%', color: c.success),
              ]),
              const SizedBox(height: 12),
              _listCard(
                title: 'Shubhali javoblar',
                rows: [
                  for (int i = 0; i < rows.length; i++)
                    _Row(
                      lead: _dot(
                        rows[i].$5 == PillTone.danger ? c.danger : c.warn,
                      ),
                      title: rows[i].$1,
                      sub: '${rows[i].$2} · ${rows[i].$3} · ${rows[i].$4}',
                      last: i == rows.length - 1,
                      trail: Pill(
                        rows[i].$5 == PillTone.danger ? 'Yuqori' : 'O‘rta',
                        tone: rows[i].$5,
                        dot: true,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT: Cases (rich)
// ════════════════════════════════════════════════════════════════════════
class CasesAdminPage extends StatelessWidget {
  final SfColors colors;
  const CasesAdminPage({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final cases = [
      (
        'C-0042',
        'Sebzor · kvitansiyasiz naqd',
        'high',
        'open',
        'J. Qodirov',
        '2 kun',
        3,
      ),
      (
        'C-0041',
        'Mirobod · karta nomutanosibligi',
        'med',
        'review',
        'J. Qodirov',
        '4 kun',
        2,
      ),
      (
        'C-0040',
        'Посещаемость anomaliyasi · Fizika DTM',
        'high',
        'open',
        'Tayinlanmagan',
        '2 soat',
        1,
      ),
      (
        'C-0039',
        'So‘rovnoma yaxlitligi · Yunusobod',
        'med',
        'review',
        'J. Qodirov',
        '1 hafta',
        8,
      ),
      (
        'C-0038',
        'Tungi profil o‘zgarishi',
        'low',
        'closed',
        'J. Qodirov',
        '2 hafta',
        1,
      ),
    ];
    return SfTheme(
      colors: c,
      child: _page(c, 'Holatlar · Flaglar', [
        _head(
          context,
          '8 ta faol holat',
          'Holatlar · Flaglar',
          'Audit tergovlari va holati',
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterList<
                (String, String, String, String, String, String, int)
              >(
                chips: ['Hammasi', 'Ochiq', 'Tekshiruvda', 'Jiddiy', 'Mening'],
                items: cases,
                card: false,
                match: (cs, chip) {
                  switch (chip) {
                    case 'Ochiq':
                      return cs.$4 == 'open';
                    case 'Tekshiruvda':
                      return cs.$4 == 'review';
                    case 'Jiddiy':
                      return cs.$3 == 'high';
                    case 'Mening':
                      return cs.$5.contains('Qodirov');
                    default:
                      return true;
                  }
                },
                row: (context, cs, last) => _caseCard(context, cs),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _caseCard(
    BuildContext context,
    (String, String, String, String, String, String, int) cs,
  ) {
    final c = SfTheme.of(context);
    final sevColor = cs.$3 == 'high'
        ? c.danger
        : cs.$3 == 'med'
        ? c.warn
        : c.muted;
    final stTone = cs.$4 == 'open'
        ? PillTone.danger
        : cs.$4 == 'review'
        ? PillTone.warn
        : PillTone.success;
    final stLabel = cs.$4 == 'open'
        ? 'Ochiq'
        : cs.$4 == 'review'
        ? 'Tekshirilmoqda'
        : 'Yopilgan';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: sevColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _mono(context, cs.$1, size: 11, color: c.muted),
                        const Spacer(),
                        Pill(stLabel, tone: stTone, dot: true),
                        const SizedBox(width: 6),
                        Pill(
                          cs.$3 == 'high'
                              ? 'Yuqori'
                              : cs.$3 == 'med'
                              ? 'O‘rta'
                              : 'Past',
                          tone: cs.$3 == 'high'
                              ? PillTone.danger
                              : cs.$3 == 'med'
                              ? PillTone.warn
                              : PillTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cs.$2,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SfAvatar(
                          name: cs.$5 == 'Tayinlanmagan' ? 'NA' : cs.$5,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cs.$5,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10.5,
                            color: c.muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${cs.$7} dalil · ${cs.$6}',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10.5,
                            color: c.muted,
                          ),
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
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// GROUPED MENU HUB
// ════════════════════════════════════════════════════════════════════════
class MenuItem {
  final String id;
  final String label;
  final IconData icon;
  final int? badge;
  const MenuItem(this.id, this.label, this.icon, [this.badge]);
}

class MenuGroup {
  final String title;
  final List<MenuItem> items;
  const MenuGroup(this.title, this.items);
}

List<MenuGroup> menuFor(SfRole role) {
  switch (role) {
    case SfRole.ceo:
      return const [
        MenuGroup('Asosiy', [
          MenuItem('dash', 'Boshqaruv paneli', Icons.home_rounded),
          MenuItem('tools', 'Tezkor amallar', Icons.bolt_rounded),
          MenuItem('branches', 'Filiallar', Icons.public_rounded),
          MenuItem(
            'comparison',
            'Filiallarni solishtirish',
            Icons.compare_arrows_rounded,
          ),
          MenuItem('history', 'So‘nggi hodisalar', Icons.history_rounded),
        ]),
        MenuGroup('Odamlar', [
          MenuItem('students', 'O‘quvchilar', Icons.groups_rounded),
          MenuItem('groups', 'Guruhlar', Icons.workspaces_rounded),
          MenuItem('teachers', 'O‘qituvchilar', Icons.badge_rounded),
          MenuItem('parents', 'Ota-onalar', Icons.chat_bubble_outline_rounded),
          MenuItem('attendance', 'Посещаемость', Icons.fact_check_outlined),
        ]),
        MenuGroup('Tashkilot', [
          MenuItem('departments', 'Bo‘limlar', Icons.folder_rounded),
          MenuItem('hr', 'HR · Xodimlar', Icons.badge_outlined),
          MenuItem('meetings', 'Yig‘ilishlar', Icons.event_rounded),
        ]),
        MenuGroup('Moliya', [
          MenuItem('payments', 'To‘lovlar', Icons.payments_rounded),
          MenuItem('report', 'Moliyaviy hisobot', Icons.analytics_outlined),
          MenuItem('payroll', 'Oyliklar', Icons.receipt_long_rounded),
        ]),
        MenuGroup('Operatsiya', [
          MenuItem('leads', 'Lidlar · Qabul', Icons.flag_rounded),
          MenuItem('enroll', 'Qabul · Test', Icons.fact_check_rounded),
          MenuItem('approvals', 'Tasdiqlash', Icons.fact_check_rounded),
          MenuItem(
            'schedule',
            'Jadval · Xonalar',
            Icons.calendar_month_rounded,
          ),
        ]),
        MenuGroup('Aloqa', [
          MenuItem('messages', 'Xabarlar', Icons.chat_rounded),
          MenuItem('chats', 'Suhbat nazorati', Icons.shield_outlined),
          MenuItem('ai', 'AI tahlil', Icons.auto_awesome_rounded),
        ]),
        MenuGroup('Tizim', [
          MenuItem(
            'notifications',
            'Bildirishnomalar',
            Icons.notifications_none_rounded,
          ),
          MenuItem('permissions', 'Ruxsatlar · RBAC', Icons.shield_rounded),
          MenuItem('settings', 'Sozlamalar', Icons.settings_rounded),
        ]),
      ];
    case SfRole.manager:
      return const [
        MenuGroup('Asosiy', [
          MenuItem('dash', 'Boshqaruv paneli', Icons.home_rounded),
          MenuItem('tools', 'Tezkor amallar', Icons.bolt_rounded),
        ]),
        MenuGroup('Odamlar', [
          MenuItem('students', 'O‘quvchilar', Icons.groups_rounded),
          MenuItem('groups', 'Guruhlar', Icons.workspaces_rounded),
          MenuItem('teachers', 'Xodimlar', Icons.badge_rounded),
          MenuItem('parents', 'Ota-onalar', Icons.chat_bubble_outline_rounded),
          MenuItem('attendance', 'Посещаемость', Icons.fact_check_outlined),
          MenuItem('leads', 'Lidlar · Qabul', Icons.flag_rounded),
          MenuItem('enroll', 'Qabul · Test', Icons.fact_check_rounded),
        ]),
        MenuGroup('Tashkilot', [
          MenuItem('departments', 'Bo‘limlar', Icons.folder_rounded),
          MenuItem('hr', 'HR · Xodimlar', Icons.badge_outlined),
          MenuItem('meetings', 'Yig‘ilishlar', Icons.event_rounded),
        ]),
        MenuGroup('Moliya', [
          MenuItem('payments', 'To‘lovlar', Icons.payments_rounded),
          MenuItem('payroll', 'Oyliklar', Icons.receipt_long_rounded),
        ]),
        MenuGroup('Operatsiya', [
          MenuItem('approvals', 'Tasdiqlash', Icons.fact_check_rounded),
          MenuItem(
            'schedule',
            'Jadval · Xonalar',
            Icons.calendar_month_rounded,
          ),
        ]),
        MenuGroup('Aloqa', [
          MenuItem('messages', 'Xabarlar', Icons.chat_rounded),
          MenuItem('chats', 'Suhbat nazorati', Icons.shield_outlined),
          MenuItem('ai', 'AI tahlil', Icons.auto_awesome_rounded),
        ]),
        MenuGroup('Tizim', [
          MenuItem(
            'notifications',
            'Bildirishnomalar',
            Icons.notifications_none_rounded,
          ),
          MenuItem('settings', 'Sozlamalar', Icons.settings_rounded),
        ]),
      ];
    case SfRole.audit:
      return const [
        MenuGroup('Asosiy', [
          MenuItem('dash', 'Audit paneli', Icons.shield_rounded),
          MenuItem('tools', 'Tezkor amallar', Icons.bolt_rounded),
        ]),
        MenuGroup('Nazorat', [
          MenuItem('anomalies', 'Anomaliyalar', Icons.flag_rounded),
          MenuItem('fairness', 'Karta adolati', Icons.balance_rounded),
          MenuItem('finance', 'Moliyaviy tekshir', Icons.trending_up_rounded),
        ]),
        MenuGroup('Jurnal', [
          MenuItem('logs', 'Kirish jurnali', Icons.description_rounded),
          MenuItem('aiusage', 'AI monitoring', Icons.auto_awesome_rounded),
          MenuItem(
            'surveys',
            'So‘rovnoma yaxlitligi',
            Icons.fact_check_rounded,
          ),
          MenuItem('messages', 'Xabarlar', Icons.chat_rounded),
        ]),
        MenuGroup('Boshqaruv', [
          MenuItem('cases', 'Holatlar · Flaglar', Icons.push_pin_rounded),
        ]),
        MenuGroup('Tizim', [
          MenuItem(
            'notifications',
            'Bildirishnomalar',
            Icons.notifications_none_rounded,
          ),
          MenuItem('settings', 'Sozlamalar', Icons.settings_rounded),
        ]),
      ];
    case SfRole.student:
      return const [
        MenuGroup('Shaxsiy kabinet', [
          MenuItem('dash', 'Mening panelim', Icons.home_rounded),
          MenuItem('student_report', 'Natijalarim', Icons.school_rounded),
          MenuItem('messages', 'Xabarlar', Icons.chat_rounded),
          MenuItem(
            'notifications',
            'Bildirishnomalar',
            Icons.notifications_none_rounded,
          ),
        ]),
        MenuGroup('Tizim', [
          MenuItem('settings', 'Sozlamalar', Icons.settings_rounded),
        ]),
      ];
  }
}

/// The single role-access source for navigation and pushed admin pages.
///
/// Keeping this derived from [menuFor] prevents the sidebar, notification
/// deep-links and programmatic dashboard navigation from drifting into
/// different permission matrices. Profile is intentionally available to every
/// authenticated role even though it is not duplicated in the sidebar.
Set<String> navigationRoutesFor(SfRole role) => {
  'me',
  // Account destinations are opened from the profile rather than duplicated
  // in every role's sidebar. They remain role-safe because they only expose
  // the authenticated user's own preferences, activity and security actions.
  'account_preferences',
  'account_activity',
  'privacy',
  'security',
  for (final group in menuFor(role))
    for (final item in group.items) item.id,
};

bool roleCanNavigate(SfRole role, String route) =>
    navigationRoutesFor(role).contains(route);

/// Resolve a menu id to its pushed page. Returns null for ids handled by the
/// console's own bottom tabs (dash, and the role's quick screens).
Widget? buildAdminPage(String id, SfColors c, SfRole role) {
  if (!roleCanNavigate(role, id)) return null;
  final page = _adminPageFor(id, c, role);
  // Pushed routes have no ambient SfTheme, so wrap here: this gives the page's
  // own build context an SfTheme ancestor, which the shared free-function
  // helpers (_mono, _eyebrow, …) resolve via SfTheme.of(context).
  return page == null ? null : SfTheme(colors: c, child: page);
}

Widget? _adminPageFor(String id, SfColors c, SfRole role) {
  final ceo = role == SfRole.ceo;
  switch (id) {
    case 'student_report':
      return StudentSelfServiceScreen(colors: c, reportOnly: true);
    case 'branches':
      return SfScaffold(
        colors: c,
        title: 'Filiallar',
        body: const BranchesScreen(),
      );
    case 'students':
      return StudentsWorkspaceScreen(colors: c);
    case 'groups':
      return GroupsWorkspaceScreen(colors: c);
    case 'teachers':
      return TeachersWorkspaceScreen(colors: c);
    case 'parents':
      return ParentsWorkspaceScreen(colors: c);
    case 'departments':
      return DepartmentsWorkspaceScreen(colors: c);
    case 'hr':
      return HrWorkspaceScreen(colors: c);
    case 'comparison':
      return BranchComparisonScreen(colors: c);
    case 'history':
      return ActivityHistoryScreen(colors: c);
    case 'meetings':
      return MeetingsWorkspaceScreen(colors: c);
    case 'payments':
      return PaymentsWorkspaceScreen(colors: c);
    case 'payroll':
      return PayrollAdminPage(colors: c, ceo: ceo);
    case 'messages':
      // Audit may inspect server transcripts, but must never reach the
      // writable message workspace (composer, attachments or reactions).
      // Keep this guard in the shared resolver as well as Console so pushed
      // and future deep-linked routes preserve the role boundary.
      return role == SfRole.audit
          ? ChatsAdminPage(colors: c)
          : MessagesAdminPage(colors: c);
    case 'chats':
      return ChatsAdminPage(colors: c);
    case 'ai':
      return AiAdminPage(colors: c, ceo: ceo);
    case 'permissions':
      return PermissionsAdminPage(colors: c);
    case 'leads':
      return LeadsAdminPage(colors: c);
    case 'enroll':
      return EnrollAdminPage(colors: c);
    case 'approvals':
      return ApprovalsAdminPage(colors: c);
    case 'schedule':
      return ScheduleAdminPage(colors: c);
    case 'anomalies':
      return AnomaliesAdminPage(colors: c);
    case 'fairness':
      return FairnessAdminPage(colors: c);
    case 'finance':
      return FinanceAuditPage(colors: c);
    case 'logs':
      return LogsAdminPage(colors: c);
    case 'aiusage':
      return AiUsageAdminPage(colors: c);
    case 'surveys':
      return SurveyAuditPage(colors: c);
    case 'cases':
      return CasesAdminPage(colors: c);
    case 'settings':
      return SettingsScreen(colors: c);
    default:
      return null;
  }
}

/// Full grouped navigation menu (web sidebar → mobile page). Pushed from Profile.
class MenuHub extends StatelessWidget {
  final SfColors colors;
  final SfRole role;
  const MenuHub({super.key, required this.colors, required this.role});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final groups = menuFor(role);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: c.ink),
          shape: Border(bottom: BorderSide(color: c.border)),
          title: Text(
            'Barcha bo‘limlar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            for (final g in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                child: Text(
                  g.title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.muted,
                  ),
                ),
              ),
              SfCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < g.items.length; i++)
                      _menuRow(context, g.items[i], i == g.items.length - 1),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, MenuItem it, bool last) {
    final c = colors;
    final page = buildAdminPage(it.id, c, role);
    return InkWell(
      onTap: () {
        if (it.id == 'dash') {
          Navigator.of(context).maybePop();
          return;
        }
        if (page != null) Navigator.of(context).push(sfPageRoute(page));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(it.icon, size: 17, color: c.ink2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                it.label,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            if (it.badge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${it.badge}',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.muted2),
          ],
        ),
      ),
    );
  }
}
