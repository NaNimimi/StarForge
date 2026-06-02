import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'modules.dart';
import 'widgets.dart';

const _pad = EdgeInsets.fromLTRB(16, 4, 16, 24);

Widget _mono(BuildContext c, String t, {double size = 21, FontWeight w = FontWeight.w700, Color? color}) =>
    Text(t,
        style: TextStyle(
            fontFamily: SfType.mono, fontSize: size, fontWeight: w, color: color ?? SfTheme.of(c).ink, height: 1));

// ── Top bar (dashboard greeting) ───────────────────────────────────────
class _TopBar extends StatelessWidget {
  final RoleConfig cfg;
  final String hello;
  final String sub;
  const _TopBar({required this.cfg, required this.hello, required this.sub});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          SfAvatar(name: cfg.who, size: 36, color: cfg.accent(c)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hello,
                    style: TextStyle(
                        fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
                Text(sub, style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(11)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, size: 19, color: c.ink2),
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: c.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface2, width: 2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI tile ───────────────────────────────────────────────────────────
class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final ({bool up, String v})? trend;
  final List<double>? spark;
  const _Kpi({required this.label, required this.value, this.color, this.trend, this.spark});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: c.muted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: _mono(context, value, color: color)),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Text('${trend!.up ? '↑' : '↓'}${trend!.v}',
                    style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: trend!.up ? c.success : c.danger)),
              ],
            ],
          ),
          if (spark != null) ...[
            const SizedBox(height: 6),
            Sparkline(data: spark!, color: color ?? c.primary, height: 24),
          ],
        ],
      ),
    );
  }
}

Widget _kpiGrid(List<Widget> tiles) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.62,
      children: tiles,
    );

// ── Dashboard ──────────────────────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  final RoleConfig cfg;
  final void Function(String tab) go;
  const DashboardScreen({super.key, required this.cfg, required this.go});

  @override
  Widget build(BuildContext context) {
    if (cfg.role == SfRole.audit) return _AuditDash(cfg: cfg, go: go);
    final c = SfTheme.of(context);
    final ceo = cfg.role == SfRole.ceo;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TopBar(cfg: cfg, hello: ceo ? 'Boshqaruv' : 'Filial paneli', sub: cfg.scope),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kpiGrid([
                _Kpi(
                    label: 'Oylik daromad',
                    value: fmtMoneyShort(ceo ? 1284000000 : 342000000),
                    color: c.success,
                    trend: (up: true, v: '12%'),
                    spark: const [60, 66, 63, 72, 70, 78, 82, 80, 88, 94, 98, 100]),
                _Kpi(
                    label: "O'quvchilar",
                    value: ceo ? '1 842' : '512',
                    trend: (up: true, v: '4%'),
                    spark: const [70, 73, 72, 78, 82, 85, 88, 92, 96, 100]),
                _Kpi(label: 'Davomat', value: '91.2%', color: c.primary),
                _Kpi(label: 'Qarzdorlik', value: fmtMoneyShort(ceo ? 84000000 : 22400000), color: c.warn),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader('Daromad · 12 oy',
                        link: 'Kassa daftari',
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => LedgerScreen(colors: c)))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                      child: AreaChart(
                        color: c.success,
                        height: 130,
                        data: const [820, 860, 910, 890, 960, 1020, 1080, 1040, 1140, 1180, 1220, 1284]
                            .map((e) => e.toDouble())
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SfAiCard(
                badge: 'Strategik',
                quote: ceo
                    ? 'Sebzorda churn 6.2% — 2x yuqori. Tekshiring.'
                    : '38 oila qarzdor. 12 tasi 30 kundan oshgan.',
                onTap: () => go(ceo ? 'ai' : 'approvals'),
              ),
              if (ceo)
                SfCard(
                  child: Column(
                    children: [
                      SfCardHeader('Filiallar reytingi', link: 'Hammasi', onTap: () => go('students')),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: HBars(rows: [
                          for (final b in kBranches)
                            HBarRow(b.name, b.revenue.toDouble(), fmtMoneyShort(b.revenue), b.mark),
                        ]),
                      ),
                    ],
                  ),
                )
              else
                _ManagerApprovalsPreview(go: go),
              SfCard(
                child: Column(
                  children: [
                    const SfCardHeader('Davomat salomatligi'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Row(
                        children: [
                          Donut(
                            size: 92,
                            thickness: 14,
                            segments: [
                              DonutSegment(72, c.success),
                              DonutSegment(19, c.warn),
                              DonutSegment(9, c.danger),
                            ],
                            center: _mono(context, '91%', size: 17),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                LegendRow(c.success, 'Yaxshi', '72%'),
                                LegendRow(c.warn, "O'rta", '19%'),
                                LegendRow(c.danger, 'Past', '9%'),
                              ],
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
        ),
      ],
    );
  }
}

class _ManagerApprovalsPreview extends StatelessWidget {
  final void Function(String) go;
  const _ManagerApprovalsPreview({required this.go});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final rows = store.approvals.take(3).toList();
    return SfCard(
      child: Column(
        children: [
          SfCardHeader('Tasdiqlash · ${store.pendingCount}', link: 'Hammasi', onTap: () => go('approvals')),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              child: Text("Yangi so'rov yo'q — hammasi tasdiqlangan.",
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
            )
          else
            for (int i = 0; i < rows.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                      bottom: i < rows.length - 1 ? BorderSide(color: c.border) : BorderSide.none),
                ),
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(9)),
                      child: Icon(Icons.check_rounded, size: 15, color: c.warn),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].title,
                              style: TextStyle(
                                  fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                          Text(rows[i].amount > 0 ? '${rows[i].who} · ${fmtMoney(rows[i].amount)}' : rows[i].who,
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                        ],
                      ),
                    ),
                    _MiniBtn(ok: true, onTap: () => _quick(context, store, rows[i], true)),
                    const SizedBox(width: 4),
                    _MiniBtn(ok: false, onTap: () => _quick(context, store, rows[i], false)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _quick(BuildContext context, AppStore store, Approval a, bool approved) {
    store.resolve(a, approved: approved);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: approved ? const Color(0xFF4F7B3B) : const Color(0xFF8A4232),
        content: Text(approved ? '✓ "${a.title}" tasdiqlandi' : '✗ "${a.title}" rad etildi',
            style: const TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ));
  }
}

class _MiniBtn extends StatelessWidget {
  final bool ok;
  final VoidCallback? onTap;
  const _MiniBtn({required this.ok, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 15, color: ok ? c.success : c.danger),
        ),
      ),
    );
  }
}

class _AuditDash extends StatelessWidget {
  final RoleConfig cfg;
  final void Function(String) go;
  const _AuditDash({required this.cfg, required this.go});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TopBar(cfg: cfg, hello: 'Audit paneli', sub: 'Barcha filiallar · nazorat'),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kpiGrid([
                _Kpi(label: 'Ochiq flaglar', value: '12', color: c.danger, trend: (up: false, v: '3')),
                _Kpi(label: 'Faol holatlar', value: '8', color: const Color(0xFFB48BC0)),
                _Kpi(label: 'Anomaliya', value: '2.4%', color: c.warn),
                _Kpi(label: 'Muvofiqlik', value: '96.8%', color: c.success, trend: (up: true, v: '1%')),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(children: [
                  const SfCardHeader('Anomaliya · 30 kun'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: AreaChart(
                      color: c.danger,
                      height: 120,
                      data: const [4, 6, 3, 8, 5, 12, 7, 9, 6, 11, 8, 12].map((e) => e.toDouble()).toList(),
                    ),
                  ),
                ]),
              ),
              SfAiCard(
                badge: 'Audit AI',
                quote: 'Sebzorda 3 ta yuqori signal: 100% davomat, kvitansiyasiz naqd, karta nomutanosibligi.',
                onTap: () => go('anomalies'),
              ),
              SfCard(
                child: Column(children: [
                  SfCardHeader("So'nggi flaglar", link: 'Hammasi', onTap: () => go('anomalies')),
                  for (final f in const [
                    ['Davomat 100% · 21 kun', 'Sebzor', 'high'],
                    ['48 Up karta/hafta', 'Mirobod', 'med'],
                    ['Naqd · kvitansiyasiz', 'Sebzor', 'high'],
                  ])
                    _FlagRow(title: f[0], branch: f[1], sev: f[2], last: f == const ['Naqd · kvitansiyasiz', 'Sebzor', 'high']),
                ]),
              ),
              SfCard(
                child: Column(children: [
                  const SfCardHeader('Filiallar muvofiqligi'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: HBars(rows: [
                      HBarRow('Yunusobod', 98, '98%', c.success),
                      HBarRow('Chilonzor', 97, '97%', c.success),
                      HBarRow('Mirobod', 95, '95%', c.warn),
                      HBarRow('Sebzor', 89, '89%', c.danger),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlagRow extends StatelessWidget {
  final String title, branch, sev;
  final bool last;
  const _FlagRow({required this.title, required this.branch, required this.sev, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final high = sev == 'high';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: high ? c.danger : c.warn, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                Text(branch, style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
              ],
            ),
          ),
          Pill(high ? 'Yuqori' : "O'rta", tone: high ? PillTone.danger : PillTone.warn),
        ],
      ),
    );
  }
}

// ── Students ───────────────────────────────────────────────────────────
const _studentTones = {
  'paid': (PillTone.success, "To'langan"),
  'debt': (PillTone.danger, 'Qarz'),
  'partial': (PillTone.warn, 'Qisman'),
};

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  static const _filters = ['Hammasi', 'Qarzdor', 'Riskli', 'Guruh'];
  int sel = 0;

  List<Student> get _filtered {
    switch (_filters[sel]) {
      case 'Qarzdor':
        return kStudents.where((s) => s.debt > 0).toList();
      case 'Riskli':
        return kStudents.where((s) => s.attendance < 85 || s.debt >= 1000000).toList();
      case 'Guruh':
        return [...kStudents]..sort((a, b) => a.group.compareTo(b.group));
      default:
        return kStudents;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: "${list.length} o'quvchi", title: "O'quvchilar"),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(items: _filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(icon: Icons.groups_rounded, title: 'Mos keladigan yo‘q', sub: 'Boshqa filtrni tanlang.')
              else
                SfCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < list.length; i++)
                        _StudentRow(s: list[i], last: i == list.length - 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student s;
  final bool last;
  const _StudentRow({required this.s, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final aColor = s.attendance >= 92 ? c.success : s.attendance >= 85 ? c.warn : c.danger;
    final t = _studentTones[s.pay]!;
    return InkWell(
      onTap: () => _showStudentSheet(context, s),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
        child: Row(
          children: [
            SfAvatar(name: s.name, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                  Row(children: [
                    Text('${s.group} · ',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                    Text('${s.attendance}%',
                        style: TextStyle(fontFamily: SfType.mono, fontSize: 10.5, fontWeight: FontWeight.w700, color: aColor)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill(t.$2, tone: t.$1),
                if (s.debt > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(fmtMoney(s.debt),
                        style: TextStyle(fontFamily: SfType.mono, fontSize: 10, color: c.ink)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Student detail sheet with dignity-first actions (call parent / send reminder).
void _showStudentSheet(BuildContext context, Student s) {
  final c = SfTheme.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
            Row(
              children: [
                SfAvatar(name: s.name, size: 52),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
                      Text(s.group, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _DetailStat('Davomat', '${s.attendance}%', s.attendance >= 92 ? c.success : s.attendance >= 85 ? c.warn : c.danger)),
              const SizedBox(width: 10),
              Expanded(child: _DetailStat('Qarzdorlik', s.debt > 0 ? fmtMoneyShort(s.debt) : '0', s.debt > 0 ? c.danger : c.success)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.call_rounded,
                  label: 'Ota-onaga qo‘ng‘iroq',
                  primary: true,
                  onTap: () => _toast(context, '📞 ${s.name} ota-onasiga qo‘ng‘iroq (demo)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetAction(
                  icon: Icons.notifications_active_rounded,
                  label: s.debt > 0 ? 'To‘lov eslatmasi' : 'Xabar yuborish',
                  primary: false,
                  onTap: () => _toast(
                      context, s.debt > 0 ? '🔔 To‘lov eslatmasi yuborildi (demo)' : '✉️ Xabar yuborildi (demo)'),
                ),
              ),
            ]),
          ],
        ),
      ),
  );
}

void _toast(BuildContext context, String msg) {
  Navigator.of(context).maybePop();
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A332A),
      content: Text(msg, style: const TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ));
}

class _DetailStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DetailStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.muted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontFamily: SfType.mono, fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.label, required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: primary ? c.primary : c.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: primary ? Colors.white : c.ink2),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: primary ? Colors.white : c.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Anomalies (audit) ──────────────────────────────────────────────────
class AnomaliesScreen extends StatefulWidget {
  const AnomaliesScreen({super.key});
  @override
  State<AnomaliesScreen> createState() => _AnomaliesScreenState();
}

class _AnomaliesScreenState extends State<AnomaliesScreen> {
  static const _filters = ['Hammasi', 'Yuqori', 'Davomat', 'Karta', 'Moliya'];
  int sel = 0;

  bool _match(Anomaly a) {
    switch (_filters[sel]) {
      case 'Yuqori':
        return a.sev == 'high';
      case 'Davomat':
        return a.kind == 'Davomat';
      case 'Karta':
        return a.kind == 'Karta';
      case 'Moliya':
        return a.kind == 'Moliya';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.anomalies.where(_match).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${store.anomalies.length} ochiq signal', title: 'Anomaliyalar'),
        Padding(
          padding: _pad,
          child: Column(children: [
            _FilterChips(
                items: _filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              _EmptyState(icon: Icons.flag_rounded, title: 'Signal yo‘q', sub: 'Bu filtr bo‘yicha anomaliya topilmadi.')
            else
              SfCard(
                child: Column(children: [
                  for (int i = 0; i < list.length; i++)
                    _AnomalyRow(a: list[i], last: i == list.length - 1, store: store),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class _AnomalyRow extends StatelessWidget {
  final Anomaly a;
  final bool last;
  final AppStore store;
  const _AnomalyRow({required this.a, required this.last, required this.store});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final dot = a.sev == 'high' ? c.danger : a.sev == 'med' ? c.warn : c.muted;
    final scoreColor = a.score >= 80 ? c.danger : a.score >= 60 ? c.warn : c.muted;
    return InkWell(
      onTap: () => _showAnomalySheet(context, a, store),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                Row(children: [
                  Text('${a.branch} · ', style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(5)),
                    child: Text(a.kind,
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, color: c.ink2)),
                  ),
                ]),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${a.score}',
                style: TextStyle(fontFamily: SfType.mono, fontSize: 14, fontWeight: FontWeight.w700, color: scoreColor)),
            Text('AI skor', style: TextStyle(fontFamily: SfType.ui, fontSize: 9, color: c.muted)),
          ]),
        ]),
      ),
    );
  }
}

void _showAnomalySheet(BuildContext context, Anomaly a, AppStore store) {
  final c = SfTheme.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: (a.sev == 'high' ? c.danger : c.warn).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.flag_rounded, size: 20, color: a.sev == 'high' ? c.danger : c.warn),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
                  Text('${a.branch} · ${a.kind} · AI skor ${a.score}',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _SheetAction(
                icon: Icons.push_pin_rounded,
                label: 'Holatga aylantirish',
                primary: true,
                onTap: () {
                  store.anomalyToCase(a);
                  _toast(context, '📌 Yangi audit holati ochildi');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetAction(
                icon: Icons.close_rounded,
                label: 'Signalni yopish',
                primary: false,
                onTap: () {
                  store.dismissAnomaly(a);
                  _toast(context, '✓ Signal yopildi');
                },
              ),
            ),
          ]),
        ],
      ),
    ),
  );
}

// ── Approvals (manager) ────────────────────────────────────────────────
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  void _resolve(BuildContext context, AppStore store, Approval it, bool approved) {
    store.resolve(it, approved: approved);
    final posted = approved && it.amount > 0;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: approved ? const Color(0xFF4F7B3B) : const Color(0xFF8A4232),
        content: Text(
          approved
              ? (posted
                  ? '✓ Tasdiqlandi · ${fmtMoney(it.amount)} kassa daftariga yozildi'
                  : '✓ "${it.title}" tasdiqlandi')
              : '✗ "${it.title}" rad etildi',
          style: const TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        action: posted
            ? SnackBarAction(
                label: 'Daftar',
                textColor: Colors.white,
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LedgerScreen(colors: SfTheme.of(context)))),
              )
            : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final items = store.approvals;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${items.length} so\'rov', title: 'Tasdiqlash'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _LedgerBanner(store: store),
              const SizedBox(height: 12),
              if (items.isEmpty)
                _EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Hammasi tasdiqlangan',
                  sub: "Yangi so'rov kelganda shu yerda ko'rinadi.",
                )
              else
                for (final it in items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 4, color: it.rail),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(it.title,
                                                style: TextStyle(
                                                    fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                                            Text(it.who, style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                                          ],
                                        ),
                                      ),
                                      if (it.amount > 0)
                                        Text('${it.inflow ? '+' : '−'}${fmtMoney(it.amount)}',
                                            style: TextStyle(
                                                fontFamily: SfType.mono,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: it.inflow ? c.success : c.ink)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(8)),
                                    child: Text(it.sub, style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.ink2)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        child: _ApprBtn(
                                            label: 'Rad',
                                            primary: false,
                                            onTap: () => _resolve(context, store, it, false))),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: _ApprBtn(
                                            label: 'Tasdiqlash',
                                            primary: true,
                                            onTap: () => _resolve(context, store, it, true))),
                                  ]),
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
      ],
    );
  }
}

/// Tappable banner that opens the ledger and shows the live till balance.
class _LedgerBanner extends StatelessWidget {
  final AppStore store;
  const _LedgerBanner({required this.store});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LedgerScreen(colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
            color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: c.success),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kassa daftari',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                  Text('Joriy qoldiq · ${store.ledger.length} yozuv',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                ],
              ),
            ),
            Text(fmtMoneyShort(store.balance),
                style: TextStyle(fontFamily: SfType.mono, fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

class _ApprBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _ApprBtn({required this.label, required this.primary, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: primary ? c.primary : c.surface2,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: primary ? const Color(0xFFFFFCF5) : c.ink2)),
        ),
      ),
    );
  }
}

/// Empty-state placeholder used across list screens.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _EmptyState({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
          color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 34, color: c.success),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 3),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
        ],
      ),
    );
  }
}

/// Reusable single-select chip row (dark "ink" pill = active).
class _FilterChips extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const _FilterChips({required this.items, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? c.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? Colors.transparent : c.border),
              ),
              child: Text(items[i],
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: on ? c.bg : c.muted)),
            ),
          );
        },
      ),
    );
  }
}

/// Rounded bottom-sheet container with a drag handle.
class _SheetShell extends StatelessWidget {
  final List<Widget> children;
  const _SheetShell({required this.children});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

// ── Ledger (the money-movement spine) ──────────────────────────────────
class LedgerScreen extends StatelessWidget {
  /// Colours are passed in because this is pushed as its own route and has no
  /// [SfTheme] ancestor from the originating console.
  final SfColors colors;
  const LedgerScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final store = AppScope.of(context);
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
          title: Text('Kassa daftari',
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: _pad,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('JORIY QOLDIQ',
                            style: TextStyle(
                                fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted)),
                        const SizedBox(height: 4),
                        Text(fmtMoney(store.balance),
                            style: TextStyle(fontFamily: SfType.mono, fontSize: 24, fontWeight: FontWeight.w700, color: c.ink)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _FlowStat(label: 'Kirim', value: store.inflowTotal, color: c.success, up: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _FlowStat(label: 'Chiqim', value: store.outflowTotal, color: c.danger, up: false)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SfCard(
                    child: Column(
                      children: [
                        const SfCardHeader('Harakatlar'),
                        for (int i = 0; i < store.ledger.length; i++)
                          _LedgerRow(e: store.ledger[i], last: i == store.ledger.length - 1),
                      ],
                    ),
                  ),
                  Text("Har bir yozuv o'zgarmas — pulni yo'qotib bo'lmaydi.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  final String label;
  final num value;
  final Color color;
  final bool up;
  const _FlowStat({required this.label, required this.value, required this.color, required this.up});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(11)),
      child: Row(
        children: [
          Icon(up ? Icons.south_west_rounded : Icons.north_east_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.muted)),
                Text(fmtMoneyShort(value),
                    style: TextStyle(fontFamily: SfType.mono, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final LedgerEntry e;
  final bool last;
  const _LedgerRow({required this.e, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: (e.inflow ? c.success : c.danger).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(e.inflow ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16, color: e.inflow ? c.success : c.danger),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                Row(children: [
                  Text('${e.who} · ',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(5)),
                    child: Text(e.channel,
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 9, fontWeight: FontWeight.w700, color: c.ink2)),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${e.inflow ? '+' : '−'}${fmtMoneyShort(e.amount)}',
                  style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: e.inflow ? c.success : c.ink)),
              Text(e.time, style: TextStyle(fontFamily: SfType.ui, fontSize: 9, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Branches (CEO ranking detail) ──────────────────────────────────────
class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: '4 filial', title: 'Filiallar'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (int i = 0; i < kBranches.length; i++)
                Builder(builder: (context) {
                  final b = kBranches[i];
                  return GestureDetector(
                    onTap: () => _showBranchSheet(context, b),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: b.mark, borderRadius: BorderRadius.circular(10)),
                                child: const Center(child: SfStar(size: 17, color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name,
                                        style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w800, color: c.ink)),
                                    Text('${fmtMoney(b.revenue)}/oy',
                                        style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                                  ],
                                ),
                              ),
                              Pill('${b.trend >= 0 ? '↑' : '↓'}${b.trend.abs()}%',
                                  tone: b.trend >= 4 ? PillTone.success : b.trend >= 0 ? PillTone.warn : PillTone.danger),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                          child: Row(
                            children: [
                              _branchStat(context, '${b.students}', "o'quvchi", c.ink),
                              _branchStat(context, '${b.attendance}%', 'davomat', b.attendance >= 92 ? c.success : c.warn, border: true),
                              _branchStat(context, fmtMoneyShort(b.revenue), 'daromad', c.ink),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ));
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _branchStat(BuildContext context, String value, String label, Color color, {bool border = false}) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border.symmetric(vertical: border ? BorderSide(color: c.border) : BorderSide.none),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontFamily: SfType.mono, fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 1),
            Text(label.toUpperCase(),
                style: TextStyle(fontFamily: SfType.ui, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

void _showBranchSheet(BuildContext context, Branch b) {
  final c = SfTheme.of(context);
  // Synthesise a 8-point revenue trend ending at the branch's current trend sign.
  final base = b.revenue / 1e6;
  final spark = [
    base * 0.82, base * 0.86, base * 0.84, base * 0.9,
    base * 0.93, base * 0.97, base * (b.trend >= 0 ? 0.99 : 1.02), base,
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: b.mark, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: SfStar(size: 20, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
                  Text('Filial · ${b.students} o‘quvchi',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
                ],
              ),
            ),
            Pill('${b.trend >= 0 ? '↑' : '↓'}${b.trend.abs()}%',
                tone: b.trend >= 4 ? PillTone.success : b.trend >= 0 ? PillTone.warn : PillTone.danger),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAROMAD · 8 OY',
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c.muted)),
                const SizedBox(height: 8),
                Sparkline(data: spark, color: b.trend >= 0 ? c.success : c.danger, height: 40),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _DetailStat('Daromad/oy', fmtMoneyShort(b.revenue), c.ink)),
            const SizedBox(width: 10),
            Expanded(child: _DetailStat('Davomat', '${b.attendance}%', b.attendance >= 92 ? c.success : c.warn)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DetailStat("O'quvchi", '${b.students}', c.ink)),
            const SizedBox(width: 10),
            Expanded(child: _DetailStat('Trend', '${b.trend >= 0 ? '+' : ''}${b.trend}%', b.trend >= 0 ? c.success : c.danger)),
          ]),
        ],
      ),
    ),
  );
}

// ── Cases (audit) ──────────────────────────────────────────────────────
const _caseStatusMeta = {
  'open': (PillTone.danger, 'Ochiq'),
  'review': (PillTone.warn, 'Tekshir'),
  'closed': (PillTone.success, 'Yopilgan'),
};

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  static const _filters = ['Hammasi', 'Ochiq', 'Tekshir', 'Yopilgan'];
  static const _filterStatus = [null, 'open', 'review', 'closed'];
  int sel = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final want = _filterStatus[sel];
    final list = want == null
        ? store.cases
        : store.cases.where((cs) => store.statusOf(cs) == want).toList();
    final active = store.cases.where((cs) => store.statusOf(cs) != 'closed').length;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '$active faol holat', title: 'Holatlar'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(items: _filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(icon: Icons.push_pin_rounded, title: 'Holat yo‘q', sub: 'Bu holat bo‘yicha yozuv yo‘q.')
              else
                for (final cs in list) _CaseCard(cs: cs, store: store),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaseCard extends StatelessWidget {
  final AuditCase cs;
  final AppStore store;
  const _CaseCard({required this.cs, required this.store});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final status = store.statusOf(cs);
    final meta = _caseStatusMeta[status]!;
    return GestureDetector(
      onTap: () => _showCaseSheet(context, cs, store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: cs.sev == 'high' ? c.danger : cs.sev == 'med' ? c.warn : c.muted),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cs.id,
                              style: TextStyle(fontFamily: SfType.mono, fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
                          const Spacer(),
                          Pill(meta.$2, tone: meta.$1),
                          const SizedBox(width: 6),
                          Pill(cs.sev == 'high' ? 'Yuqori' : cs.sev == 'med' ? "O'rta" : 'Past',
                              tone: cs.sev == 'high' ? PillTone.danger : cs.sev == 'med' ? PillTone.warn : PillTone.neutral),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(cs.title,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showCaseSheet(BuildContext context, AuditCase cs, AppStore store) {
  final c = SfTheme.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
          Text(cs.id,
              style: TextStyle(fontFamily: SfType.mono, fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
          const SizedBox(height: 4),
          Text(cs.title,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 16),
          Text('HOLATNI O‘ZGARTIRISH',
              style: TextStyle(fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final entry in _caseStatusMeta.entries) ...[
                Expanded(
                  child: _SheetAction(
                    icon: entry.key == 'open'
                        ? Icons.lock_open_rounded
                        : entry.key == 'review'
                            ? Icons.search_rounded
                            : Icons.check_circle_rounded,
                    label: entry.value.$2,
                    primary: store.statusOf(cs) == entry.key,
                    onTap: () {
                      store.setCaseStatus(cs, entry.key);
                      _toast(context, '✓ ${cs.id} → ${entry.value.$2}');
                    },
                  ),
                ),
                if (entry.key != 'closed') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

// ── AI ─────────────────────────────────────────────────────────────────
class AiScreen extends StatefulWidget {
  final RoleConfig cfg;
  const AiScreen({super.key, required this.cfg});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppStore store, [String? preset]) {
    final text = preset ?? _ctrl.text;
    if (text.trim().isEmpty) return;
    store.sendChat(text);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final cfg = widget.cfg;
    final ceo = cfg.role == SfRole.ceo;
    final audit = cfg.role == SfRole.audit;
    final insights = [
      (
        'Churn riski',
        'danger',
        audit
            ? "Sebzorda 3 yuqori signal to'plandi."
            : ceo
                ? "Sebzorda churn 2x yuqori. 3 o'qituvchi almashgan."
                : "6 o'quvchi ketish belgisini ko'rsatmoqda."
      ),
      ('O\'sish', 'success', ceo ? 'Ingliz B2 to\'lgan — yangi guruh \$4.2k/oy.' : "Kutish ro'yxatida 14 o'quvchi bor."),
      ('Moliya', 'warn', ceo ? '142 oila qarzdor. 38 tasi 30+ kun.' : '38 oila qarzdor (22.4 mln).'),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              const SfHead(eyebrow: 'AI yordamchi', title: 'Strategik tahlil'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (store.chat.isEmpty)
                      for (final ins in insights)
                        SfAiCard(
                          badge: ins.$1,
                          quote: ins.$3,
                          trailing: Pill(
                            ins.$2 == 'danger' ? 'Yuqori' : ins.$2 == 'warn' ? "O'rta" : 'Imkon',
                            tone: toneFromString(ins.$2),
                            dot: true,
                          ),
                        )
                    else
                      for (final turn in store.chat) _ChatBubble(turn: turn),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in ['Churn sabablari', 'Daromad prognozi', 'Reyting'])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => _send(store, p),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                      color: c.aiBg.first,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: c.aiBorder)),
                                  child: Text(p,
                                      style: TextStyle(
                                          fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: c.ai)),
                                ),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(store),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Savol yozing...',
                      hintStyle: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _send(store),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiTurn turn;
  const _ChatBubble({required this.turn});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final mine = turn.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          gradient: mine ? null : LinearGradient(colors: c.aiBg, begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: mine ? c.primary : null,
          border: mine ? null : Border.all(color: c.aiBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(mine ? 13 : 4),
            bottomRight: Radius.circular(mine ? 4 : 13),
          ),
        ),
        child: Text(turn.text,
            style: TextStyle(
                fontFamily: mine ? SfType.ui : SfType.display,
                fontStyle: mine ? FontStyle.normal : FontStyle.italic,
                fontSize: mine ? 13 : 14.5,
                height: 1.35,
                color: mine ? Colors.white : c.ink)),
      ),
    );
  }
}

// ── Messages ───────────────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _ctrl = TextEditingController();
  int sel = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send(AppStore store) {
    if (_ctrl.text.trim().isEmpty) return;
    store.sendMessage(sel, _ctrl.text);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final threads = store.threads;
    final cur = threads[sel].meta;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: 'Aloqa markazi', title: 'Xabarlar'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              const SfChips(['Hammasi', 'Xodimlar', "O'qituvchi", 'Ota-ona', "O'quvchi"]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < threads.length; i++)
                      Builder(builder: (context) {
                        final th = threads[i].meta;
                        return InkWell(
                          onTap: () => setState(() => sel = i),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                            decoration: BoxDecoration(
                                border: Border(bottom: i < threads.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                            child: Row(
                              children: [
                                if (th.isGroup)
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                                    child: const Center(child: SfStar(size: 16, color: Colors.white)),
                                  )
                                else
                                  SfAvatar(name: th.name, size: 34),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(th.name,
                                          style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                                      Text(th.last,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(th.time, style: TextStyle(fontFamily: SfType.mono, fontSize: 9.5, color: c.muted)),
                                    if (th.unread > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 3),
                                        constraints: const BoxConstraints(minWidth: 18),
                                        height: 18,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(9)),
                                        child: Text('${th.unread}',
                                            style: const TextStyle(
                                                fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              // Active conversation preview
              SfCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          if (cur.isGroup)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
                              child: const Center(child: SfStar(size: 13, color: Colors.white)),
                            )
                          else
                            SfAvatar(name: cur.name, size: 28),
                          const SizedBox(width: 8),
                          Text(cur.name,
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                          const Spacer(),
                          if (cur.online)
                            Text('onlayn',
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 11, fontWeight: FontWeight.w600, color: c.success)),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: c.bg,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final m in threads[sel].messages) ...[
                            _bubble(context, m.text, mine: m.mine),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
                              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(20)),
                              child: TextField(
                                controller: _ctrl,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(store),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.ink),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                  hintText: 'Xabar yoki vazifa...',
                                  hintStyle: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _send(store),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
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
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, String text, {required bool mine}) {
    final c = SfTheme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface,
          border: mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 4),
            bottomRight: Radius.circular(mine ? 4 : 12),
          ),
        ),
        child: Text(text,
            style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: mine ? Colors.white : c.ink)),
      ),
    );
  }
}

// ── Profile ────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final RoleConfig cfg;
  final VoidCallback onSwitchRole;
  const ProfileScreen({super.key, required this.cfg, required this.onSwitchRole});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final rows = [
      ['Rol va ruxsatlar', cfg.label],
      ['Valyuta', 'UZS'],
      ['Til', "O'zbekcha"],
      ['Mavzu', cfg.label == 'Audit' ? 'Qora' : 'Tizim'],
      ['Bildirishnomalar', 'Yoniq'],
      ['Xavfsizlik · 2FA', 'Yoqilgan'],
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${cfg.label} konsoli', title: 'Profil'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              SfCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SfAvatar(name: cfg.who, size: 56, color: cfg.accent(c)),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.who,
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
                          Text('${cfg.roleTitle} · ${cfg.scope}',
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ModulesHub(colors: c))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.aiBg, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: c.aiBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SfStar(size: 20, color: c.ai),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barcha modullar',
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, fontWeight: FontWeight.w800, color: c.ink)),
                            Text('Davomat, to‘lovlar, imtihonlar, kamera…',
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.ai)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.ai),
                    ],
                  ),
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++)
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                            border: Border(bottom: i < rows.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rows[i][0], style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.ink)),
                            Text('${rows[i][1]} ›', style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onSwitchRole,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: c.surface2, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(9)),
                  child: Text('Rolni almashtirish',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink2)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onSwitchRole,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: c.surface2, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(9)),
                  child: Text('Chiqish',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.danger)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain (non-popping) snackbar for full-screen routes.
void _snack(BuildContext context, String msg, {Color? bg}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg ?? const Color(0xFF3A332A),
      content: Text(msg, style: const TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ));
}

// ── Attendance — the paper-killer (one-tap roster + auto-notify) ────────
class AttendanceScreen extends StatefulWidget {
  final SfColors colors;
  const AttendanceScreen({super.key, required this.colors});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final List<String> groups = kStudents.map((s) => s.group).toSet().toList();
  int gi = 0;
  final Set<String> absent = {}; // by student name

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final group = groups[gi];
    final roster = kStudents.where((s) => s.group == group).toList();
    final present = roster.where((s) => !absent.contains(s.name)).length;
    final absentInGroup = roster.where((s) => absent.contains(s.name)).length;
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
          title: Text('Davomat',
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
          actions: [
            IconButton(
              icon: Icon(Icons.qr_code_scanner_rounded, color: c.ink),
              tooltip: 'QR check-in',
              onPressed: () => _snack(context, '📷 QR check-in rejimi (demo)'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _FilterChips(items: groups, selected: gi, onSelect: (i) => setState(() => gi = i)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Expanded(child: _DetailStat('Hozir', '$present', c.success)),
                const SizedBox(width: 10),
                Expanded(child: _DetailStat("Yo'q", '$absentInGroup', absentInGroup > 0 ? c.danger : c.muted)),
                const SizedBox(width: 10),
                Expanded(child: _DetailStat('Jami', '${roster.length}', c.ink)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  SfCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < roster.length; i++)
                          _RosterRow(
                            s: roster[i],
                            present: !absent.contains(roster[i].name),
                            last: i == roster.length - 1,
                            onToggle: () => setState(() {
                              final n = roster[i].name;
                              absent.contains(n) ? absent.remove(n) : absent.add(n);
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(children: [
                Expanded(
                  child: _SheetAction(
                    icon: Icons.notifications_active_rounded,
                    label: "Yo'qlarga xabar ($absentInGroup)",
                    primary: false,
                    onTap: absentInGroup == 0
                        ? () => _snack(context, "Bu guruhda yo'q o'quvchi yo'q")
                        : () => _snack(context, '🔔 $absentInGroup ota-onaga xabar yuborildi (demo)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetAction(
                    icon: Icons.check_circle_rounded,
                    label: 'Saqlash',
                    primary: true,
                    onTap: () => _snack(context, '✓ Davomat saqlandi · $present bor, $absentInGroup yo‘q',
                        bg: const Color(0xFF4F7B3B)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  final Student s;
  final bool present;
  final bool last;
  final VoidCallback onToggle;
  const _RosterRow({required this.s, required this.present, required this.last, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
        child: Row(
          children: [
            SfAvatar(name: s.name, size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Text(s.name,
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: present ? c.successSoft : c.dangerSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(present ? Icons.check_rounded : Icons.close_rounded,
                    size: 14, color: present ? c.success : c.danger),
                const SizedBox(width: 5),
                Text(present ? 'Bor' : "Yo'q",
                    style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: present ? c.success : c.danger)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modules hub (built modules + roadmap) ───────────────────────────────
class ModulesHub extends StatelessWidget {
  final SfColors colors;
  const ModulesHub({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    // (icon, label, ready, builder-or-null)
    final modules = <(IconData, String, bool, Widget Function()?)>[
      (Icons.account_balance_wallet_rounded, 'Kassa daftari', true, () => LedgerScreen(colors: c)),
      (Icons.fact_check_rounded, 'Davomat', true, () => AttendanceScreen(colors: c)),
      (Icons.payments_rounded, "To'lovlar · Click/Payme", true, () => PaymentsScreen(colors: c)),
      (Icons.print_rounded, 'Bosib chiqarish', true, () => PrintingScreen(colors: c)),
      (Icons.quiz_rounded, 'Mock imtihonlar', true, () => ExamsScreen(colors: c)),
      (Icons.record_voice_over_rounded, 'AI suhbatdosh', true, () => SpeakingScreen(colors: c)),
      (Icons.videocam_rounded, 'Kamera tahlili', true, () => CameraScreen(colors: c)),
      (Icons.emoji_events_rounded, 'Mukofotlar · ballar', true, () => RewardsScreen(colors: c)),
      (Icons.badge_rounded, 'Xodimlar · HR', true, () => HrScreen(colors: c)),
      (Icons.menu_book_rounded, 'Qoidalar kitobi', true, () => RuleBookScreen(colors: c)),
    ];
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
          title: Text('Modullar',
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: 1.18,
          children: [
            for (final m in modules)
              _ModuleTile(
                icon: m.$1,
                label: m.$2,
                ready: m.$3,
                onTap: m.$4 != null
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => m.$4!()))
                    : () => _snack(context, '"${m.$2}" — tez orada (demo)'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ready;
  final VoidCallback onTap;
  const _ModuleTile({required this.icon, required this.label, required this.ready, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: (ready ? c.primary : c.muted).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 20, color: ready ? c.primary : c.muted),
              ),
              const Spacer(),
              Text(label,
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 5),
              Pill(ready ? 'Tayyor' : 'Tez orada', tone: ready ? PillTone.success : PillTone.neutral),
            ],
          ),
        ),
      ),
    );
  }
}
