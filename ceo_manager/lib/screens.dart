import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'settings.dart';
import 'i18n.dart';
import 'modules.dart';
import 'pages.dart';
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
    final store = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          // Tap the avatar to change it.
          GestureDetector(
            onTap: () => Navigator.of(context).push(sfPageRoute(AvatarPickerScreen(colors: c))),
            child: SfAvatar(name: cfg.who, size: 36, color: cfg.accent(c), choice: store.avatarChoice),
          ),
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
          GestureDetector(
            onTap: () => _showNotifications(context),
            child: Container(
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
          ),
        ],
      ),
    );
  }
}

/// Notifications bottom sheet (demo content) opened from the dashboard bell.
void _showNotifications(BuildContext context) {
  final c = SfTheme.of(context);
  final items = [
    (Icons.payments_rounded, c.success, "Yangi to'lov qabul qilindi", '2 daq oldin'),
    (Icons.flag_rounded, c.danger, 'Sebzorda yangi anomaliya signali', '18 daq oldin'),
    (Icons.groups_rounded, c.primary, "Ingliz B2 guruhi to'ldi", '1 soat oldin'),
    (Icons.task_alt_rounded, c.warn, "3 ta yangi tasdiq so'rovi", '2 soat oldin'),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
          Text(tr(context, 'notifs_title'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  border: Border(bottom: i < items.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: items[i].$2.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(items[i].$1, size: 18, color: items[i].$2),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(items[i].$3,
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
                  ),
                  const SizedBox(width: 8),
                  Text(items[i].$4, style: TextStyle(fontFamily: SfType.ui, fontSize: 10, color: c.muted)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SfButton(
            icon: Icons.done_all_rounded,
            label: tr(context, 'notif_mark_read'),
            primary: true,
            onTap: () {
              Navigator.of(context).maybePop();
              _snack(context, tr(context, 'notif_all_read'), bg: const Color(0xFF4F7B3B));
            },
          ),
        ],
      ),
    ),
  );
}

// ── KPI tile ───────────────────────────────────────────────────────────
class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final ({bool up, String v})? trend;
  final List<double>? spark;
  final String? sub;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Kpi(
      {required this.label,
      required this.value,
      this.color,
      this.trend,
      this.spark,
      this.sub,
      this.icon,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SfTap(
        scale: onTap == null ? 1.0 : 0.97,
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: c.muted)),
              ),
              if (icon != null) Icon(icon, size: 15, color: color ?? c.muted2),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _mono(context, value, color: color))),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${trend!.up ? '↑' : '↓'}${trend!.v}',
                      style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: trend!.up ? c.success : c.danger)),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, color: c.muted)),
          ] else if (spark != null) ...[
            const SizedBox(height: 6),
            Sparkline(data: spark!, color: color ?? c.primary, height: 22),
          ],
        ],
      ),
        ),
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
      childAspectRatio: 1.6,
      children: tiles,
    );

// ── Dashboard (web design ported to mobile) ─────────────────────────────
class DashboardScreen extends StatelessWidget {
  final RoleConfig cfg;
  final void Function(String tab) go;
  const DashboardScreen({super.key, required this.cfg, required this.go});

  @override
  Widget build(BuildContext context) {
    if (cfg.role == SfRole.audit) return _AuditDash(cfg: cfg, go: go);
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final ceo = cfg.role == SfRole.ceo;
    final num rev = ceo ? 1284000000 : 342000000;
    final num debt = ceo ? 84000000 : 22400000;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TopBar(cfg: cfg, hello: ceo ? tr(context, 'greet_ceo') : tr(context, 'greet_manager'), sub: ceo ? tr(context, 'scope_all') : cfg.scope),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchPill(onTap: () => _snack(context, '🔎 ${tr(context, 'search_hint')}')),
              const SizedBox(height: 12),
              _DashHeader(
                eyebrow: tr(context, ceo ? 'dash_eyebrow_ceo' : 'dash_eyebrow_manager'),
                title: tr(context, ceo ? 'dash_title_ceo' : 'dash_title_manager'),
                sub: tr(context, ceo ? 'dash_sub_ceo' : 'dash_sub_manager'),
                reportLabel: tr(context, 'btn_report'),
                newLabel: tr(context, ceo ? 'btn_new_branch' : 'btn_new_group'),
                accent: c.primary,
                onReport: () => Navigator.of(context).push(sfPageRoute(ReportScreen(colors: c, role: cfg.role))),
                onNew: () => _showCreateSheet(context, SettingsScope.of(context), ceo ? 'create_branch' : 'create_group'),
              ),
              const SizedBox(height: 14),
              _kpiGrid([
                _Kpi(
                    label: tr(context, 'kpi_revenue'),
                    value: fmtMoneyMln(rev),
                    color: c.success,
                    icon: Icons.trending_up_rounded,
                    trend: (up: true, v: '12.4%'),
                    spark: const [60, 64, 62, 70, 68, 76, 80, 78, 86, 90, 94, 100],
                    onTap: () => Navigator.of(context).push(sfPageRoute(LedgerScreen(colors: c)))),
                _Kpi(
                    label: tr(context, 'kpi_students'),
                    value: ceo ? '1 842' : '512',
                    icon: Icons.groups_rounded,
                    trend: (up: true, v: '4.1%'),
                    spark: const [70, 72, 74, 73, 78, 82, 85, 88, 90, 92, 96, 100],
                    onTap: () => go('students')),
                _Kpi(
                    label: tr(context, 'kpi_attendance'),
                    value: '91.2%',
                    color: c.primary,
                    icon: Icons.check_circle_outline_rounded,
                    trend: (up: true, v: '0.8%'),
                    spark: const [88, 90, 87, 91, 89, 92, 90, 93, 91, 92, 90, 91],
                    onTap: () => Navigator.of(context).push(sfPageRoute(SfTheme(colors: c, child: AttendanceScreen(colors: c))))),
                _Kpi(
                    label: tr(context, 'kpi_churn'),
                    value: '3.4%',
                    color: c.danger,
                    icon: Icons.trending_down_rounded,
                    trend: (up: false, v: '0.6%'),
                    sub: 'Maqsad: < 4%',
                    onTap: () => go('ai')),
                _Kpi(
                    label: tr(context, 'kpi_debt'),
                    value: fmtMoneyMln(debt),
                    color: c.warn,
                    icon: Icons.flag_rounded,
                    sub: ceo ? '142 oila' : '38 oila',
                    onTap: () => go('students')),
                ceo
                    ? _Kpi(
                        label: tr(context, 'kpi_nps'),
                        value: '72',
                        color: c.accent,
                        icon: Icons.star_rounded,
                        trend: (up: true, v: '5'),
                        sub: 'Ota-onalar',
                        onTap: () => go('ai'))
                    : _Kpi(
                        label: tr(context, 'kpi_pending'),
                        value: '${store.pendingCount}',
                        color: c.warn,
                        icon: Icons.task_alt_rounded,
                        sub: "To'lov · ta'til",
                        onTap: () => go('approvals')),
              ]),
              const SizedBox(height: 12),
              _RevenueCard(
                  ceo: ceo,
                  rev: rev,
                  color: c.success,
                  onLink: () => Navigator.of(context).push(sfPageRoute(LedgerScreen(colors: c)))),
              SfAiCard(
                badge: 'Strategik',
                quote: store.stats.aiQuote,
                onTap: () => go(ceo ? 'ai' : 'approvals'),
              ),
              if (ceo)
                SfCard(
                  child: Column(
                    children: [
                      SfCardHeader(tr(context, 'card_branch_rank'),
                          link: tr(context, 'link_all'), onTap: () => go('students')),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: HBars(ranked: true, rows: [
                          for (final b in store.branches)
                            HBarRow(b.name, b.revenue.toDouble(), fmtMoneyMln(b.revenue), b.mark,
                                mark: true, onTap: () => _showBranchSheet(context, b)),
                        ]),
                      ),
                    ],
                  ),
                )
              else
                _ManagerApprovalsPreview(go: go),
              GestureDetector(
                onTap: () => Navigator.of(context).push(sfPageRoute(SfTheme(colors: c, child: AttendanceScreen(colors: c)))),
                child: SfCard(
                  child: Column(
                    children: [
                      SfCardHeader(tr(context, 'card_attendance_health'),
                          link: tr(context, 'link_all'),
                          onTap: () => Navigator.of(context).push(sfPageRoute(SfTheme(colors: c, child: AttendanceScreen(colors: c))))),
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
                                  LegendRow(c.success, tr(context, 'legend_good'), '72%'),
                                  LegendRow(c.warn, tr(context, 'legend_mid'), '19%'),
                                  LegendRow(c.danger, tr(context, 'legend_low'), '9%'),
                                ],
                              ),
                            ),
                          ],
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

/// Read-only search pill at the top of the dashboard (web global search).
class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr(context, 'search_hint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard page header: dated eyebrow, big title, sub, and two action buttons.
class _DashHeader extends StatelessWidget {
  final String eyebrow, title, sub, reportLabel, newLabel;
  final Color accent;
  final VoidCallback onReport, onNew;
  const _DashHeader({
    required this.eyebrow,
    required this.title,
    required this.sub,
    required this.reportLabel,
    required this.newLabel,
    required this.accent,
    required this.onReport,
    required this.onNew,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(),
            style: TextStyle(
                fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.muted)),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                fontFamily: SfType.ui, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: c.ink)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _ActionBtn(
                    icon: Icons.download_rounded, label: reportLabel, primary: false, accent: accent, onTap: onReport)),
            const SizedBox(width: 8),
            Expanded(
                child: _ActionBtn(
                    icon: Icons.add_rounded, label: newLabel, primary: true, accent: accent, onTap: onNew)),
          ],
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final Color accent;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.primary, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SfTap(
      child: Material(
        color: primary ? accent : c.surface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: primary ? null : Border.all(color: c.border), borderRadius: BorderRadius.circular(11)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: primary ? Colors.white : c.ink2),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: primary ? Colors.white : c.ink2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Revenue card with a working 12 oy / 6 oy / YTD period switch, a month-labeled
/// area chart, and three footer stats (forecast / avg-check / payment-rate).
class _RevenueCard extends StatefulWidget {
  final bool ceo;
  final num rev;
  final Color color;
  final VoidCallback onLink;
  const _RevenueCard({required this.ceo, required this.rev, required this.color, required this.onLink});
  @override
  State<_RevenueCard> createState() => _RevenueCardState();
}

class _RevenueCardState extends State<_RevenueCard> {
  static const List<double> _all = [820, 860, 910, 890, 960, 1020, 1080, 1040, 1140, 1180, 1220, 1284];
  static const List<String> _labels = ['Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek', 'Yan', 'Fev', 'Mar', 'Apr', 'May'];
  int seg = 0; // 0 = 12 oy, 1 = 6 oy, 2 = YTD

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final start = seg == 1 ? 6 : seg == 2 ? 7 : 0;
    final data = _all.sublist(start).map((e) => e * 1e6).toList();
    final labels = _labels.sublist(start);
    final segLabels = [tr(context, 'seg_12mo'), tr(context, 'seg_6mo'), tr(context, 'seg_ytd')];
    return SfCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onLink,
                    child: Text(tr(context, widget.ceo ? 'card_rev_dynamics' : 'card_branch_rev'),
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(9)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 3; i++)
                        GestureDetector(
                          onTap: () => setState(() => seg = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: seg == i ? c.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: seg == i ? Border.all(color: c.border) : null,
                            ),
                            child: Text(segLabels[i],
                                style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: seg == i ? c.ink : c.muted)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: AreaChart(color: widget.color, height: 144, data: data, labels: labels),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(
              children: [
                _foot(context, tr(context, 'foot_forecast'), fmtMoneyMln(widget.rev * 12.4)),
                _foot(context, tr(context, 'foot_avg_check'), fmtMoneyMln(680000), border: true),
                _foot(context, tr(context, 'foot_pay_rate'), '94.2%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _foot(BuildContext context, String l, String v, {bool border = false}) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
            border: Border.symmetric(vertical: border ? BorderSide(color: c.border) : BorderSide.none)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 9, fontWeight: FontWeight.w600, color: c.muted)),
            const SizedBox(height: 3),
            Text(v, style: TextStyle(fontFamily: SfType.mono, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
          ],
        ),
      ),
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
          SfCardHeader('${tr(context, 'card_approvals')} · ${store.pendingCount}', link: tr(context, 'link_all'), onTap: () => go('approvals')),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              child: Text(tr(context, 'no_requests'),
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
            )
          else
            for (int i = 0; i < rows.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => go('approvals'),
                child: Container(
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
            style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
    final accent = cfg.accent(c);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TopBar(cfg: cfg, hello: tr(context, 'greet_audit'), sub: tr(context, 'scope_audit')),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchPill(onTap: () => _snack(context, '🔎 ${tr(context, 'search_hint')}')),
              const SizedBox(height: 12),
              _DashHeader(
                eyebrow: tr(context, 'audit_eyebrow'),
                title: tr(context, 'greet_audit'),
                sub: tr(context, 'audit_sub'),
                reportLabel: tr(context, 'btn_audit_report'),
                newLabel: tr(context, 'btn_new_case'),
                accent: accent,
                onReport: () => Navigator.of(context).push(sfPageRoute(ReportScreen(colors: c, role: SfRole.audit))),
                onNew: () => _showCreateSheet(context, SettingsScope.of(context), 'create_case'),
              ),
              const SizedBox(height: 14),
              _kpiGrid([
                _Kpi(label: tr(context, 'kpi_open_flags'), value: '12', color: c.danger, icon: Icons.flag_rounded, trend: (up: false, v: '3'), sub: '3 ta yuqori', onTap: () => go('anomalies')),
                _Kpi(label: tr(context, 'kpi_active_cases'), value: '8', color: accent, icon: Icons.push_pin_rounded, sub: '2 ta jiddiy', onTap: () => go('cases')),
                _Kpi(label: tr(context, 'kpi_anom_score'), value: '2.4%', color: c.warn, sub: 'tranzaksiyalar', onTap: () => go('anomalies')),
                _Kpi(label: tr(context, 'kpi_compliance'), value: '96.8%', color: c.success, icon: Icons.shield_rounded, trend: (up: true, v: '1.2%')),
                _Kpi(label: tr(context, 'kpi_checked'), value: '1 842', sub: "o'quvchi yozuvi", onTap: () => go('anomalies')),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(children: [
                  SfCardHeader(tr(context, 'card_anom_signals'), link: tr(context, 'link_all'), onTap: () => go('anomalies')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: AreaChart(
                      color: c.danger,
                      height: 120,
                      data: const [4, 6, 3, 8, 5, 12, 7, 9, 6, 11, 8, 12].map((e) => e.toDouble()).toList(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                    child: Row(children: [
                      _footStat(context, 'Davomat anomaliyasi', '5', c.danger),
                      _footStat(context, 'Karta nomutanosib.', '5', c.warn, border: true),
                      _footStat(context, 'Moliya', '2', c.danger),
                    ]),
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
                  SfCardHeader(tr(context, 'card_recent_flags'), link: tr(context, 'link_all'), onTap: () => go('anomalies')),
                  for (final f in const [
                    ['Davomat 100% · 21 kun', 'Sebzor', 'high'],
                    ['48 Up karta/hafta', 'Mirobod', 'med'],
                    ['Naqd · kvitansiyasiz', 'Sebzor', 'high'],
                  ])
                    _FlagRow(
                        title: f[0],
                        branch: f[1],
                        sev: f[2],
                        last: f == const ['Naqd · kvitansiyasiz', 'Sebzor', 'high'],
                        onTap: () => go('anomalies')),
                ]),
              ),
              SfCard(
                child: Column(children: [
                  SfCardHeader(tr(context, 'card_branch_compliance'), link: tr(context, 'link_all'), onTap: () => go('cases')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: HBars(rows: [
                      HBarRow('Yunusobod', 98, '98%', c.success, onTap: () => go('cases')),
                      HBarRow('Chilonzor', 97, '97%', c.success, onTap: () => go('cases')),
                      HBarRow('Mirobod', 95, '95%', c.warn, onTap: () => go('cases')),
                      HBarRow('Sebzor', 89, '89%', c.danger, onTap: () => go('cases')),
                    ]),
                  ),
                ]),
              ),
              SfCard(
                child: Column(children: [
                  SfCardHeader(tr(context, 'card_case_status')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(children: [
                      Donut(
                        size: 92,
                        thickness: 14,
                        segments: [
                          DonutSegment(3, c.danger),
                          DonutSegment(5, c.warn),
                          DonutSegment(14, c.success),
                        ],
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _mono(context, '22', size: 17),
                            Text(tr(context, 'unit_total'),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(children: [
                          LegendRow(c.danger, tr(context, 'legend_open_serious'), '3'),
                          LegendRow(c.warn, tr(context, 'legend_reviewing'), '5'),
                          LegendRow(c.success, tr(context, 'legend_closed'), '14'),
                        ]),
                      ),
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

/// A small label + coloured value cell used in dashboard chart footers.
Widget _footStat(BuildContext context, String label, String value, Color valueColor, {bool border = false}) {
  final c = SfTheme.of(context);
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
          border: Border.symmetric(vertical: border ? BorderSide(color: c.border) : BorderSide.none)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 9, fontWeight: FontWeight.w600, color: c.muted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontFamily: SfType.mono, fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    ),
  );
}

class _FlagRow extends StatelessWidget {
  final String title, branch, sev;
  final bool last;
  final VoidCallback? onTap;
  const _FlagRow({required this.title, required this.branch, required this.sev, required this.last, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final high = sev == 'high';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
  int sel = 0;

  List<Student> _filter(List<Student> all) {
    switch (sel) {
      case 1: // debtors
        return all.where((s) => s.debt > 0).toList();
      case 2: // at risk
        return all.where((s) => s.attendance < 85 || s.debt >= 1000000).toList();
      case 3: // by group
        return [...all]..sort((a, b) => a.group.compareTo(b.group));
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter(AppScope.of(context).students);
    final filters = [tr(context, 'f_all'), tr(context, 'f_debtor'), tr(context, 'f_risky'), tr(context, 'f_group')];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: "${list.length} ${tr(context, 'unit_student')}", title: tr(context, 'students_title')),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(items: filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
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
      onTap: () => Navigator.of(context).push(sfPageRoute(StudentDetailScreen(student: s, colors: c))),
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

/// Full-page student profile with dignity-first actions (call parent / send
/// reminder) and an attendance trend. Pushed as its own route — [colors] passed
/// in because it has no [SfTheme] ancestor from the originating console.
class StudentDetailScreen extends StatelessWidget {
  final Student student;
  final SfColors colors;
  const StudentDetailScreen({super.key, required this.student, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final s = student;
    final aColor = s.attendance >= 92 ? c.success : s.attendance >= 85 ? c.warn : c.danger;
    final t = _studentTones[s.pay]!;
    // Synthesise an 8-week attendance trend ending near the current value.
    final base = s.attendance.toDouble();
    final spark = <double>[base - 7, base - 3, base - 5, base - 1, base - 3, base + 1, base - 2, base]
        .map((v) => v.clamp(40.0, 100.0))
        .toList();
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
          title: Text(tr(context, 'tab_students'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                SfAvatar(name: s.name, size: 60),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 20, fontWeight: FontWeight.w800, color: c.ink)),
                      const SizedBox(height: 2),
                      Text(s.group, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted)),
                    ],
                  ),
                ),
                Pill(t.$2, tone: t.$1),
              ],
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _DetailStat(tr(context, 'stat_attendance'), '${s.attendance}%', aColor)),
              const SizedBox(width: 10),
              Expanded(child: _DetailStat(tr(context, 'stat_debt'), s.debt > 0 ? fmtMoneyShort(s.debt) : '0', s.debt > 0 ? c.danger : c.success)),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'stu_trend').toUpperCase(),
                      style: TextStyle(
                          fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c.muted)),
                  const SizedBox(height: 10),
                  Sparkline(data: spark, color: aColor, height: 46),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.call_rounded,
                  label: tr(context, 'stu_call'),
                  primary: true,
                  onTap: () => _snack(context, '📞 ${s.name} ota-onasiga qo‘ng‘iroq (demo)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetAction(
                  icon: Icons.notifications_active_rounded,
                  label: s.debt > 0 ? tr(context, 'stu_remind') : tr(context, 'stu_message'),
                  primary: false,
                  onTap: () => _snack(
                      context, s.debt > 0 ? '🔔 To‘lov eslatmasi yuborildi (demo)' : '✉️ Xabar yuborildi (demo)'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  Navigator.of(context).maybePop();
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A332A),
      content: Text(msg, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
  int sel = 0;

  bool _match(Anomaly a) {
    switch (sel) {
      case 1:
        return a.sev == 'high';
      case 2:
        return a.kind == 'Davomat';
      case 3:
        return a.kind == 'Karta';
      case 4:
        return a.kind == 'Moliya';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.anomalies.where(_match).toList();
    final filters = [tr(context, 'f_all'), tr(context, 'f_high'), tr(context, 'f_attendance'), tr(context, 'f_card'), tr(context, 'f_finance')];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${store.anomalies.length} ${tr(context, 'unit_open_signal')}', title: tr(context, 'anomalies_title')),
        Padding(
          padding: _pad,
          child: Column(children: [
            _FilterChips(
                items: filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
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
          style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        action: posted
            ? SnackBarAction(
                label: 'Daftar',
                textColor: Colors.white,
                onPressed: () => Navigator.of(context).push(
                    sfPageRoute(LedgerScreen(colors: SfTheme.of(context)))),
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
        SfHead(eyebrow: '${items.length} ${tr(context, 'unit_request')}', title: tr(context, 'approvals_title')),
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
                                            label: tr(context, 'btn_reject'),
                                            primary: false,
                                            onTap: () => _resolve(context, store, it, false))),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: _ApprBtn(
                                            label: tr(context, 'btn_approve'),
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
          .push(sfPageRoute(LedgerScreen(colors: c))),
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
                  Text(tr(context, 'link_ledger'),
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
    return InkWell(
      onTap: () => Navigator.of(context).push(sfPageRoute(LedgerEntryScreen(entry: e, colors: c))),
      child: Container(
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
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.muted2),
        ],
      ),
      ),
    );
  }
}

/// Full-page detail for one immutable ledger movement. Pushed as its own route.
class LedgerEntryScreen extends StatelessWidget {
  final LedgerEntry entry;
  final SfColors colors;
  const LedgerEntryScreen({super.key, required this.entry, required this.colors});

  Widget _row(BuildContext context, String k, String v, {bool last = false}) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted)),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final e = entry;
    final accent = e.inflow ? c.success : c.danger;
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
          title: Text(tr(context, 'tx_title'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Hero amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)),
                    child: Icon(e.inflow ? Icons.south_west_rounded : Icons.north_east_rounded, size: 26, color: accent),
                  ),
                  const SizedBox(height: 14),
                  Text('${e.inflow ? '+' : '−'}${fmtMoney(e.amount)}',
                      style: TextStyle(fontFamily: SfType.mono, fontSize: 26, fontWeight: FontWeight.w700, color: accent)),
                  const SizedBox(height: 6),
                  Pill(e.inflow ? tr(context, 'tx_inflow') : tr(context, 'tx_outflow'),
                      tone: e.inflow ? PillTone.success : PillTone.danger),
                  const SizedBox(height: 12),
                  Text(e.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 14.5, fontWeight: FontWeight.w700, color: c.ink)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  _row(context, tr(context, 'tx_type'), e.kind),
                  _row(context, tr(context, 'tx_channel'), e.channel),
                  _row(context, tr(context, 'tx_who'), e.who),
                  _row(context, tr(context, 'tx_time'), e.time),
                  _row(context, tr(context, 'tx_id'), e.id, last: true),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 20, color: c.success),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, 'tx_confirmed'),
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.success)),
                        const SizedBox(height: 2),
                        Text(tr(context, 'tx_immutable'),
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.ink2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final branches = AppScope.of(context).branches;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${branches.length} ${tr(context, 'unit_branch')}', title: tr(context, 'branches_title')),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (int i = 0; i < branches.length; i++)
                Builder(builder: (context) {
                  final b = branches[i];
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
    final filters = [tr(context, 'f_all'), tr(context, 'f_open'), tr(context, 'f_review'), tr(context, 'f_closed')];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '$active ${tr(context, 'unit_active_case')}', title: tr(context, 'cases_title')),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(items: filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
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
              SfHead(eyebrow: tr(context, 'ai_eyebrow'), title: tr(context, 'ai_title')),
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
                      hintText: tr(context, 'ai_hint'),
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
  int sel = 0;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final filters = [tr(context, 'f_all'), tr(context, 'f_direct'), tr(context, 'f_groups'), tr(context, 'f_unread')];
    // Keep each thread's real store index so the chat page opens the right one.
    final visible = <int>[];
    for (int i = 0; i < store.threads.length; i++) {
      final th = store.threads[i].meta;
      final ok = switch (sel) {
        1 => !th.isGroup,
        2 => th.isGroup,
        3 => th.unread > 0,
        _ => true,
      };
      if (ok) visible.add(i);
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: tr(context, 'messages_eyebrow'), title: tr(context, 'messages_title')),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(items: filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                _EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: tr(context, 'no_messages'),
                    sub: tr(context, 'pick_filter'))
              else
                SfCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < visible.length; i++)
                        _ThreadRow(idx: visible[i], colors: c, last: i == visible.length - 1),
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

/// One row in the conversation list; tapping it opens the full chat page.
class _ThreadRow extends StatelessWidget {
  final int idx;
  final SfColors colors;
  final bool last;
  const _ThreadRow({required this.idx, required this.colors, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final th = AppScope.of(context).threads[idx].meta;
    return InkWell(
      onTap: () => Navigator.of(context).push(sfPageRoute(ChatScreen(threadIdx: idx, colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
            border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
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
                        style: TextStyle(
                            fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.muted2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page conversation. Pushed as its own route (so it has no [SfTheme]
/// ancestor — [colors] is passed in). Writing happens here, on its own page.
class ChatScreen extends StatefulWidget {
  final int threadIdx;
  final SfColors colors;
  const ChatScreen({super.key, required this.threadIdx, required this.colors});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppStore store) {
    if (_ctrl.text.trim().isEmpty) return;
    store.sendMessage(widget.threadIdx, _ctrl.text);
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final thread = store.threads[widget.threadIdx];
    final th = thread.meta;
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
          titleSpacing: 0,
          title: Row(
            children: [
              if (th.isGroup)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(9)),
                  child: const Center(child: SfStar(size: 14, color: Colors.white)),
                )
              else
                SfAvatar(name: th.name, size: 32),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(th.name,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w800, color: c.ink)),
                  Text(th.online ? tr(context, 'online') : th.group,
                      style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: th.online ? c.success : c.muted)),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in thread.messages) ...[
                    _bubble(context, m.text, mine: m.mine),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(22)),
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(store),
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.ink),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          hintText: tr(context, 'msg_hint'),
                          hintStyle: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.muted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SfTap(
                    child: GestureDetector(
                      onTap: () => _send(store),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, String text, {required bool mine}) {
    final c = widget.colors;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface,
          border: mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(mine ? 13 : 4),
            bottomRight: Radius.circular(mine ? 4 : 13),
          ),
        ),
        child: Text(text,
            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, height: 1.3, color: mine ? Colors.white : c.ink)),
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
    final store = AppScope.of(context);
    final settings = SettingsScope.of(context);
    void openDesign() => showDesignPanel(context, cfg.role);
    // (label, value, onTap) — theme/lang/currency change inline, instantly.
    final rows = <(String, String, VoidCallback)>[
      (tr(context, 'set_role'), cfg.label, () => _toast(context, '${cfg.roleTitle} · ${cfg.scope}')),
      (tr(context, 'set_currency'), '${kCurrencyCode[settings.currency]} · ${kCurrencySym[settings.currency]}', () => _showCurrencyPicker(context, settings)),
      (tr(context, 'set_lang'), langName(context, settings.lang), () => _showLanguagePicker(context, settings)),
      (tr(context, 'set_theme'), tr(context, settings.dark ? 'theme_dark' : 'theme_light'), settings.toggleTheme),
      (tr(context, 'set_notifs'), tr(context, 'on'), () => _showNotifications(context)),
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(eyebrow: '${cfg.label} ${tr(context, 'unit_console')}', title: tr(context, 'profile_title')),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              SfCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Tap avatar → avatar picker.
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(sfPageRoute(AvatarPickerScreen(colors: c))),
                      child: Stack(
                        children: [
                          SfAvatar(name: cfg.who, size: 56, color: cfg.accent(c), choice: store.avatarChoice),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                  color: c.primary, borderRadius: BorderRadius.circular(7), border: Border.all(color: c.surface, width: 2)),
                              child: const Icon(Icons.edit_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    GestureDetector(
                      onTap: openDesign,
                      child: Icon(Icons.tune_rounded, size: 22, color: c.muted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: openDesign,
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
                      Icon(Icons.tune_rounded, size: 20, color: c.ai),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(context, 'tweaks_title'),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, fontWeight: FontWeight.w800, color: c.ink)),
                            Text(tr(context, 'tweaks_sub'),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.ai)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.ai),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(sfPageRoute(ModulesHub(colors: c))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SfStar(size: 20, color: c.primary),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(context, 'all_modules'),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, fontWeight: FontWeight.w800, color: c.ink)),
                            Text(tr(context, 'all_modules_sub'),
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.muted),
                    ],
                  ),
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++)
                      InkWell(
                        onTap: rows[i].$3,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                              border: Border(bottom: i < rows.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(rows[i].$1, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.ink)),
                              Text('${rows[i].$2} ›', style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
                            ],
                          ),
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
                  child: Text(tr(context, 'btn_switch_role'),
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
                  child: Text(tr(context, 'btn_logout'),
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.danger)),
                ),
              ),
              const SizedBox(height: 14),
              // Build marker — lets a tester confirm at a glance which APK is running.
              Center(
                child: Text('StarForge EDU · v1.0.1',
                    style: TextStyle(fontFamily: SfType.mono, fontSize: 10.5, color: c.muted2)),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// Currency chooser — modal sheet with the 3 demo currencies (So'm · Dollar ·
/// Rubl). Applies instantly across the whole app via [AppSettings].
void _showCurrencyPicker(BuildContext context, AppSettings settings) {
  final c = settings.colors;
  const opts = [SfCurrency.uzs, SfCurrency.usd, SfCurrency.rub];
  const nameKey = {
    SfCurrency.uzs: 'cur_uzs',
    SfCurrency.usd: 'cur_usd',
    SfCurrency.eur: 'cur_eur',
    SfCurrency.rub: 'cur_rub',
  };
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SfTheme(
      colors: c,
      child: Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr(context, 'currency_pick'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
              ),
            ),
            for (final cur in opts)
              InkWell(
                onTap: () {
                  settings.setCurrency(cur);
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(11)),
                      child: Text(kCurrencySym[cur]!,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(context, nameKey[cur]!),
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
                        Text(kCurrencyCode[cur]!, style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
                      ]),
                    ),
                    Icon(settings.currency == cur ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 22, color: settings.currency == cur ? c.primary : c.muted2),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ),
  );
}

/// Language chooser — modal sheet with the 3 UI languages (O'zbekcha · Русский ·
/// English), mirroring the currency picker. Applies instantly across the app.
void _showLanguagePicker(BuildContext context, AppSettings settings) {
  final c = settings.colors;
  const opts = [
    (SfLang.uz, 'UZ', 'lang_uz'),
    (SfLang.ru, 'RU', 'lang_ru'),
    (SfLang.en, 'EN', 'lang_en'),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SfTheme(
      colors: c,
      child: Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr(context, 'lang_pick'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
              ),
            ),
            for (final o in opts)
              InkWell(
                onTap: () {
                  settings.setLang(o.$1);
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(11)),
                      child: Text(o.$2,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w800, color: c.ink)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr(context, o.$3),
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
                    ),
                    Icon(settings.lang == o.$1 ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 22, color: settings.lang == o.$1 ? c.primary : c.muted2),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ),
  );
}

// ── Report (pushed route, role-aware) ──────────────────────────────────
/// A printable summary opened by the dashboard "Hisobot" button. Pulls real
/// figures from the live [AppStore] so every role sees its own report.
class ReportScreen extends StatelessWidget {
  final SfColors colors;
  final SfRole role;
  const ReportScreen({super.key, required this.colors, required this.role});

  Widget _kv(BuildContext context, String k, String v, {Color? vColor, bool last = false}) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted)),
        Text(v, style: TextStyle(fontFamily: SfType.mono, fontSize: 13, fontWeight: FontWeight.w700, color: vColor ?? c.ink)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final store = AppScope.of(context);
    final audit = role == SfRole.audit;
    final ceo = role == SfRole.ceo;
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
          title: Text(tr(context, audit ? 'report_audit_title' : 'report_title'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.primary, c.primaryHover], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const SfStar(size: 22, color: Colors.white),
                  const SizedBox(width: 9),
                  Text('StarForge EDU',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
                const SizedBox(height: 12),
                Text(tr(context, audit ? 'report_audit_title' : 'report_title'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(tr(context, 'report_period'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            if (audit) ...[
              _setSec(c, tr(context, 'report_summary')),
              SfCard(child: Column(children: [
                _kv(context, tr(context, 'kpi_open_flags'), '12'),
                _kv(context, tr(context, 'kpi_active_cases'), '8'),
                _kv(context, tr(context, 'kpi_anom_score'), '2.4%', vColor: c.warn),
                _kv(context, tr(context, 'kpi_compliance'), '96.8%', vColor: c.success, last: true),
              ])),
              _setSec(c, tr(context, 'report_compliance')),
              SfCard(child: Padding(
                padding: const EdgeInsets.all(14),
                child: HBars(rows: [
                  HBarRow('Yunusobod', 98, '98%', c.success),
                  HBarRow('Chilonzor', 97, '97%', c.success),
                  HBarRow('Mirobod', 95, '95%', c.warn),
                  HBarRow('Sebzor', 89, '89%', c.danger),
                ]),
              )),
            ] else ...[
              _setSec(c, tr(context, 'report_summary')),
              SfCard(child: Column(children: [
                _kv(context, tr(context, 'kpi_revenue'), fmtMoneyMln(store.stats.revenue), vColor: c.success),
                _kv(context, tr(context, 'kpi_students'), store.stats.students),
                _kv(context, tr(context, 'kpi_attendance'), '91.2%', vColor: c.primary),
                _kv(context, tr(context, 'kpi_debt'), fmtMoneyMln(store.stats.debt), vColor: c.warn, last: true),
              ])),
              _setSec(c, tr(context, 'report_finance')),
              SfCard(child: Column(children: [
                _kv(context, tr(context, 'tx_inflow'), fmtMoneyMln(store.inflowTotal), vColor: c.success),
                _kv(context, tr(context, 'tx_outflow'), fmtMoneyMln(store.outflowTotal), vColor: c.danger),
                _kv(context, 'JORIY QOLDIQ', fmtMoneyMln(store.balance), last: true),
              ])),
              if (ceo) ...[
                _setSec(c, tr(context, 'report_branches')),
                SfCard(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: HBars(ranked: true, rows: [
                    for (final b in store.branches)
                      HBarRow(b.name, b.revenue.toDouble(), fmtMoneyMln(b.revenue), b.mark, mark: true),
                  ]),
                )),
              ],
            ],
            const SizedBox(height: 6),
            Text(tr(context, 'report_gen'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted2)),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: GestureDetector(
            onTap: () => _snack(context, tr(context, 'report_exported'), bg: const Color(0xFF4F7B3B)),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(tr(context, 'report_export'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ Yangi …" creation sheet opened by the dashboard's new-entity button.
/// A real little form (name · owner · note) that validates and confirms — the
/// demo has no backend, so a successful submit shows a toast and closes.
void _showCreateSheet(BuildContext context, AppSettings settings, String titleKey) {
  final c = settings.colors;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SfTheme(colors: c, child: _CreateSheet(c: c, titleKey: titleKey)),
  );
}

class _CreateSheet extends StatefulWidget {
  final SfColors c;
  final String titleKey;
  const _CreateSheet({required this.c, required this.titleKey});
  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _note = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _note.dispose();
    super.dispose();
  }

  Widget _input(String hint, TextEditingController ctrl, {bool multiline = false}) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: multiline ? 3 : 1,
        onChanged: (_) {
          if (_err != null) setState(() => _err = null);
        },
        style: TextStyle(fontFamily: SfType.ui, fontSize: 14, color: c.ink, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: SfType.ui, color: c.muted2, fontWeight: FontWeight.w500),
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text(tr(context, widget.titleKey),
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
              const SizedBox(height: 14),
              _input(tr(context, 'create_name'), _name),
              _input(tr(context, 'create_owner'), _owner),
              _input(tr(context, 'create_note'), _note, multiline: true),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr(context, _err!),
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: c.danger)),
                ),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(border: Border.all(color: c.borderStrong), borderRadius: BorderRadius.circular(11)),
                      child: Text(tr(context, 'create_cancel'),
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink2)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_name.text.trim().isEmpty) {
                        setState(() => _err = 'create_need_name');
                        return;
                      }
                      Navigator.of(context).pop();
                      _snack(context, tr(context, 'create_done'), bg: const Color(0xFF4F7B3B));
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(11)),
                      child: Text(tr(context, 'create_submit'),
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Avatar picker (pushed route) ────────────────────────────────────────
/// Lets the logged-in user pick a real-photo or emoji-badge avatar. The choice
/// is stored on the [AppStore] so it updates everywhere the user appears.
class AvatarPickerScreen extends StatelessWidget {
  final SfColors colors;
  const AvatarPickerScreen({super.key, required this.colors});

  bool _isSel(AvatarChoice? cur, AvatarChoice opt) =>
      cur?.photo == opt.photo && cur?.emoji == opt.emoji;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final store = AppScope.of(context);
    final cur = store.avatarChoice;
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
          title: Text(tr(context, 'avatar_title'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: SfAvatar(name: 'Sardor Rashidov', size: 96, choice: cur),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(tr(context, 'avatar_eyebrow'),
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.muted)),
            ),
            const SizedBox(height: 20),
            _AvatarSection(
              title: tr(context, 'avatar_photos'),
              options: kAvatarPhotos,
              selected: cur,
              isSel: _isSel,
              onPick: (ch) => _pick(context, store, ch),
            ),
            const SizedBox(height: 18),
            _AvatarSection(
              title: tr(context, 'avatar_colors'),
              options: kAvatarBadges,
              selected: cur,
              isSel: _isSel,
              onPick: (ch) => _pick(context, store, ch),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, AppStore store, AvatarChoice ch) {
    store.setAvatar(ch);
    _snack(context, tr(context, 'avatar_saved'), bg: const Color(0xFF4F7B3B));
  }
}

class _AvatarSection extends StatelessWidget {
  final String title;
  final List<AvatarChoice> options;
  final AvatarChoice? selected;
  final bool Function(AvatarChoice?, AvatarChoice) isSel;
  final ValueChanged<AvatarChoice> onPick;
  const _AvatarSection(
      {required this.title, required this.options, required this.selected, required this.isSel, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.muted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final opt in options)
              GestureDetector(
                onTap: () => onPick(opt),
                child: SfTap(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSel(selected, opt) ? c.primary : Colors.transparent, width: 2.5),
                    ),
                    child: SfAvatar(name: 'StarForge', size: 60, choice: opt),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Live design panel ("Ko'rinishni sozlash") ───────────────────────────
/// The web's slide-out `sf-control` panel, mobilised as a draggable sheet.
/// Opens from the floating ✦ button (every console screen) and the Profile
/// gear — palette · theme · layout · density · pattern · font, then the full
/// "Barcha bo'limlar" navigation at the bottom, exactly like the web design.
void showDesignPanel(BuildContext context, SfRole role) {
  // Right-side slide-in drawer (like the web `.sfcp`): partial width, full
  // height, slides from the right — not a full-screen page.
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, a1, a2) => DesignPanel(role: role),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
  );
}

/// Shared design-control sections (palette · theme · layout · density · pattern
/// · font) used by both the live panel and the Sozlamalar route.
List<Widget> _designControls(BuildContext context, AppSettings settings, SfColors c) {
  return [
    _setSec(c, '${tr(context, 'tw_palette')} · 10'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.4,
      children: [
        for (int i = 0; i < kPalettes.length; i++)
          _PalCard(p: kPalettes[i], selected: settings.palette == i, onTap: () => settings.setPalette(i)),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_theme')),
    Row(children: [
      Expanded(child: _ChoiceCard(icon: Icons.light_mode_rounded, label: tr(context, 'theme_light'), selected: !settings.dark, onTap: () => settings.setDark(false))),
      const SizedBox(width: 12),
      Expanded(child: _ChoiceCard(icon: Icons.dark_mode_rounded, label: tr(context, 'theme_dark'), selected: settings.dark, onTap: () => settings.setDark(true))),
    ]),
    const SizedBox(height: 22),
    _setSec(c, '${tr(context, 'tw_layout')} · 5'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (int i = 0; i < kLayouts.length; i++)
          _LayCard(lay: kLayouts[i], selected: settings.layout == i, onTap: () => settings.setLayout(i)),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_density')),
    _setSeg(c, [
      (tr(context, 'tw_dense_s'), settings.density == 0, () => settings.setDensity(0)),
      (tr(context, 'tw_dense_m'), settings.density == 1, () => settings.setDensity(1)),
      (tr(context, 'tw_dense_l'), settings.density == 2, () => settings.setDensity(2)),
    ]),
    const SizedBox(height: 22),
    _setSec(c, '${tr(context, 'tw_pattern')} · 5'),
    Wrap(spacing: 7, runSpacing: 7, children: [
      for (int i = 0; i < kPatterns.length; i++)
        _setChip(c, tr(context, ['pat_none', 'pat_dots', 'pat_grid', 'pat_tile', 'pat_topo'][i]), settings.pattern == kPatterns[i],
            () => settings.setPattern(kPatterns[i])),
    ]),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_font')),
    _setSeg(c, [
      for (int i = 0; i < kFonts.length; i++) (kFonts[i].$2, settings.font == i, () => settings.setFont(i)),
    ]),
  ];
}

class DesignPanel extends StatelessWidget {
  final SfRole role;
  const DesignPanel({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final c = settings.colors;
    final size = MediaQuery.of(context).size;
    // Partial-width right drawer, capped like the web (≤ 360, ≤ 90% of screen).
    final panelW = size.width * 0.9 > 360 ? 360.0 : size.width * 0.9;
    return SfTheme(
      colors: c,
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: panelW,
            height: double.infinity,
            decoration: BoxDecoration(
              color: c.bg,
              border: Border(left: BorderSide(color: c.border)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(-14, 0)),
              ],
            ),
            child: SafeArea(
              left: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(context, 'tweaks_title'),
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
                          Text(tr(context, 'tweaks_sub'),
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.close_rounded, size: 18, color: c.ink2),
                        ),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: c.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        ..._designControls(context, settings, c),
                        const SizedBox(height: 24),
                        _setSec(c, tr(context, 'all_sections')),
                        ..._panelMenu(context, c),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
                    child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: settings.reset,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(border: Border.all(color: c.borderStrong), borderRadius: BorderRadius.circular(11)),
                        child: Text(tr(context, 'tw_reset'),
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(11)),
                        child: Text(tr(context, 'tw_done'),
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _panelMenu(BuildContext context, SfColors c) {
    final groups = menuFor(role);
    final out = <Widget>[];
    for (final g in groups) {
      final items = g.items.where((it) => it.id != 'settings').toList();
      if (items.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 7),
        child: Text(grpLabel(context, g.title).toUpperCase(),
            style: TextStyle(fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted)),
      ));
      out.add(SfCard(
        margin: EdgeInsets.zero,
        child: Column(children: [
          for (int i = 0; i < items.length; i++) _panelRow(context, c, items[i], i == items.length - 1),
        ]),
      ));
    }
    return out;
  }

  Widget _panelRow(BuildContext context, SfColors c, MenuItem it, bool last) {
    return InkWell(
      onTap: () {
        final nav = Navigator.of(context, rootNavigator: true);
        final page = buildAdminPage(it.id, c, role);
        nav.pop();
        if (page != null) nav.push(sfPageRoute(page));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(9)),
            child: Icon(it.icon, size: 16, color: c.ink2),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(menuLabel(context, it.label), style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink))),
          if (it.badge != null)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Text('${it.badge}', style: TextStyle(fontFamily: SfType.mono, fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
            ),
          Icon(Icons.chevron_right_rounded, size: 17, color: c.muted2),
        ]),
      ),
    );
  }
}

/// A nav-layout preview card (mini chrome thumbnail + name + description).
class _LayCard extends StatelessWidget {
  final SfLayout lay;
  final bool selected;
  final VoidCallback onTap;
  const _LayCard({required this.lay, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.8 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayMini(id: lay.id, c: c),
            const SizedBox(height: 6),
            Text(tr(context, lay.nameKey),
                style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w700, color: c.ink)),
            Text(tr(context, lay.descKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _LayMini extends StatelessWidget {
  final String id;
  final SfColors c;
  const _LayMini({required this.id, required this.c});
  @override
  Widget build(BuildContext context) {
    final bar = c.primary.withValues(alpha: 0.55);
    Widget content;
    switch (id) {
      case 'sidebar':
        content = Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.24, heightFactor: 1, child: Container(color: bar)));
        break;
      case 'rail':
        content = Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.12, heightFactor: 1, child: Container(color: bar)));
        break;
      case 'topbar':
        content = Align(alignment: Alignment.topCenter, child: FractionallySizedBox(widthFactor: 1, heightFactor: 0.32, child: Container(color: bar)));
        break;
      case 'dock':
        content = Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: FractionallySizedBox(
                widthFactor: 0.5, heightFactor: 0.28, child: Container(decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(4)))),
          ),
        );
        break;
      default: // zen
        content = const SizedBox.shrink();
    }
    return Container(
      height: 26,
      width: double.infinity,
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(5)),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

// ── Settings (pushed route) ─────────────────────────────────────────────
/// App preferences: light/dark theme + UZ/RU/EN language. Both apply instantly
/// across the whole app via [SettingsScope].
class SettingsScreen extends StatelessWidget {
  final SfColors colors;
  const SettingsScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    // Read live colours so this page itself re-themes when the toggle flips.
    final settings = SettingsScope.of(context);
    final c = settings.colors;
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
          title: Text(tr(context, 'settings_title'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            ..._designControls(context, settings, c),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: settings.reset,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(border: Border.all(color: c.borderStrong), borderRadius: BorderRadius.circular(11)),
                child: Text(tr(context, 'tw_reset'),
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _setSec(SfColors c, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t.toUpperCase(),
          style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.muted)),
    );

Widget _setSeg(SfColors c, List<(String, bool, VoidCallback)> items) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: items[i].$3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: items[i].$2 ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: items[i].$2 ? Border.all(color: c.border) : null),
                child: Text(items[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: items[i].$2 ? c.ink : c.muted)),
              ),
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 4),
        ],
      ]),
    );

Widget _setChip(SfColors c, String label, bool on, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? c.primary : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : c.border),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? Colors.white : c.ink2)),
      ),
    );

/// A palette swatch row used in the design settings.
class _PalCard extends StatelessWidget {
  final SfPalette p;
  final bool selected;
  final VoidCallback onTap;
  const _PalCard({required this.p, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary.withValues(alpha: 0.10) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.primary : c.border, width: selected ? 1.8 : 1),
        ),
        child: Row(children: [
          SizedBox(
            width: 30,
            height: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(children: [
                Expanded(child: Container(color: p.primary)),
                Expanded(child: Container(color: p.accent)),
                Expanded(child: Container(color: p.swatch)),
              ]),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
          ),
          if (selected) Icon(Icons.check_circle_rounded, size: 16, color: p.primary),
        ]),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SfTap(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: selected ? c.primary.withValues(alpha: 0.10) : c.surface,
            border: Border.all(color: selected ? c.primary : c.border, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? c.primary : c.muted),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.primary : c.ink)),
            ],
          ),
        ),
      ),
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
      content: Text(msg, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
  int gi = 0;
  final Set<String> absent = {}; // by student name

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final students = AppScope.of(context).students;
    final groups = students.map((s) => s.group).toSet().toList();
    if (gi >= groups.length) gi = 0;
    final group = groups[gi];
    final roster = students.where((s) => s.group == group).toList();
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
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Donut(
                    size: 78,
                    thickness: 12,
                    segments: [
                      DonutSegment(present.toDouble(), c.success),
                      DonutSegment(absentInGroup.toDouble() == 0 && present == 0 ? 1 : absentInGroup.toDouble(), c.danger),
                    ],
                    center: _mono(context, '${roster.isEmpty ? 0 : (present / roster.length * 100).round()}%', size: 15),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        LegendRow(c.success, 'Hozir', '$present'),
                        LegendRow(c.danger, "Yo'q", '$absentInGroup'),
                        LegendRow(c.ink2, 'Jami', '${roster.length}'),
                      ],
                    ),
                  ),
                ]),
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                  Text('${s.group} · ${s.attendance}%',
                      style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10,
                          color: s.attendance >= 92 ? c.success : s.attendance >= 85 ? c.warn : c.danger)),
                ],
              ),
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
            for (int i = 0; i < modules.length; i++)
              _Entrance(
                delayMs: 45 * i,
                child: _ModuleTile(
                  icon: modules[i].$1,
                  label: modules[i].$2,
                  ready: modules[i].$3,
                  onTap: modules[i].$4 != null
                      ? () => Navigator.of(context).push(sfPageRoute(SfTheme(colors: c, child: modules[i].$4!())))
                      : () => _snack(context, '"${modules[i].$2}" — tez orada (demo)'),
                ),
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
    return SfTap(
      child: Material(
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
      ),
    );
  }
}

/// One-shot fade + lift entrance, optionally delayed — used to stagger grids/lists.
class _Entrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Entrance({required this.child, this.delayMs = 0});
  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}
