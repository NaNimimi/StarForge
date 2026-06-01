import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
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
                    const SfCardHeader('Daromad · 12 oy', link: 'Batafsil'),
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
    final rows = [
      ("To'lov qaytarish", 'Akbarov A.', 600000),
      ("Ta'til", 'Yusupova N.', 0),
      ('Yangi guruh', 'Ingliz B2', 0),
    ];
    return SfCard(
      child: Column(
        children: [
          SfCardHeader('Tasdiqlash · 7', link: 'Hammasi', onTap: () => go('approvals')),
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
                        Text(rows[i].$1,
                            style: TextStyle(
                                fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                        Text(rows[i].$3 > 0 ? '${rows[i].$2} · ${fmtMoney(rows[i].$3)}' : rows[i].$2,
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                      ],
                    ),
                  ),
                  _MiniBtn(ok: true),
                  const SizedBox(width: 4),
                  _MiniBtn(ok: false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final bool ok;
  const _MiniBtn({required this.ok});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
          color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 15, color: ok ? c.success : c.danger),
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
class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    const tones = {
      'paid': (PillTone.success, "To'langan"),
      'debt': (PillTone.danger, 'Qarz'),
      'partial': (PillTone.warn, 'Qisman'),
    };
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: "512 o'quvchi", title: "O'quvchilar"),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              const SfChips(['Hammasi', 'Qarzdor', 'Riskli', 'Guruh']),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < kStudents.length; i++)
                      Builder(builder: (context) {
                        final s = kStudents[i];
                        final aColor = s.attendance >= 92 ? c.success : s.attendance >= 85 ? c.warn : c.danger;
                        final t = tones[s.pay]!;
                        return Container(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          decoration: BoxDecoration(
                              border: Border(bottom: i < kStudents.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                          child: Row(
                            children: [
                              SfAvatar(name: s.name, size: 34),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: TextStyle(
                                            fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                                    Row(children: [
                                      Text('${s.group} · ',
                                          style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                                      Text('${s.attendance}%',
                                          style: TextStyle(
                                              fontFamily: SfType.mono, fontSize: 10.5, fontWeight: FontWeight.w700, color: aColor)),
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
                        );
                      }),
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

// ── Anomalies (audit) ──────────────────────────────────────────────────
class AnomaliesScreen extends StatelessWidget {
  const AnomaliesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: '12 ochiq signal', title: 'Anomaliyalar'),
        Padding(
          padding: _pad,
          child: Column(children: [
            const SfChips(['Hammasi', 'Yuqori', 'Davomat', 'Karta', 'Moliya']),
            const SizedBox(height: 12),
            SfCard(
              child: Column(children: [
                for (int i = 0; i < kAnomalies.length; i++)
                  Builder(builder: (context) {
                    final a = kAnomalies[i];
                    final dot = a.sev == 'high' ? c.danger : a.sev == 'med' ? c.warn : c.muted;
                    final scoreColor = a.score >= 80 ? c.danger : a.score >= 60 ? c.warn : c.muted;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      decoration: BoxDecoration(
                          border: Border(bottom: i < kAnomalies.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
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
                    );
                  }),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Approvals (manager) ────────────────────────────────────────────────
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: "7 so'rov", title: 'Tasdiqlash'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (final it in kApprovals)
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
                                      Text(fmtMoney(it.amount),
                                          style: TextStyle(fontFamily: SfType.mono, fontSize: 12, fontWeight: FontWeight.w700, color: c.ink)),
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
                                  Expanded(child: _ApprBtn(label: 'Rad', primary: false)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _ApprBtn(label: 'Tasdiqlash', primary: true)),
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

class _ApprBtn extends StatelessWidget {
  final String label;
  final bool primary;
  const _ApprBtn({required this.label, required this.primary});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: primary ? c.primary : c.surface2,
        border: primary ? null : Border.all(color: c.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: primary ? const Color(0xFFFFFCF5) : c.ink2)),
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
                  return Container(
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
                  );
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

// ── Cases (audit) ──────────────────────────────────────────────────────
class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    const st = {
      'open': (PillTone.danger, 'Ochiq'),
      'review': (PillTone.warn, 'Tekshir'),
      'closed': (PillTone.success, 'Yopilgan'),
    };
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: '8 faol holat', title: 'Holatlar'),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (final cs in kCases)
                Container(
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
                                    Pill(st[cs.status]!.$2, tone: st[cs.status]!.$1),
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
            ],
          ),
        ),
      ],
    );
  }
}

// ── AI ─────────────────────────────────────────────────────────────────
class AiScreen extends StatelessWidget {
  final RoleConfig cfg;
  const AiScreen({super.key, required this.cfg});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SfHead(eyebrow: 'AI yordamchi', title: 'Strategik tahlil'),
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
                    ins.$2 == 'danger' ? 'Yuqori' : ins.$2 == 'warn' ? "O'rta" : 'Imkon',
                    tone: toneFromString(ins.$2),
                    dot: true,
                  ),
                ),
              SfCard(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final p in ['Churn sabablari', 'Daromad prognozi', 'Reyting'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: c.aiBg.first,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: c.aiBorder)),
                            child: Text(p,
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: c.ai)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    Expanded(child: Text('Savol yozing...', style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.muted))),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
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

// ── Messages ───────────────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int sel = 0;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final cur = kThreads[sel];
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
                    for (int i = 0; i < kThreads.length; i++)
                      Builder(builder: (context) {
                        final th = kThreads[i];
                        return InkWell(
                          onTap: () => setState(() => sel = i),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                            decoration: BoxDecoration(
                                border: Border(bottom: i < kThreads.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
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
                          _bubble(context, cur.last, mine: false),
                          const SizedBox(height: 8),
                          _bubble(context, "Albatta, ko'rib chiqaman 👍", mine: true),
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
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(20)),
                              child: Text('Xabar yoki vazifa...',
                                  style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
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
