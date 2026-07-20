import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'settings.dart';
import 'i18n.dart';
import 'modules.dart';
import 'pages.dart';
import 'reference_ui.dart';
import 'widgets.dart';

const _pad = EdgeInsets.fromLTRB(16, 4, 16, 24);

Widget _mono(
  BuildContext c,
  String t, {
  double size = 21,
  FontWeight w = FontWeight.w700,
  Color? color,
}) => Text(
  t,
  style: TextStyle(
    fontFamily: SfType.mono,
    fontSize: size,
    fontWeight: w,
    color: color ?? SfTheme.of(c).ink,
    height: 1,
  ),
);

/// Opens the platform dialler for a real, dynamically supplied phone number.
/// Formatting characters from display values (spaces, dashes and brackets) are
/// removed without changing the number itself.
Future<void> _launchPhoneCall(BuildContext context, String phone) async {
  final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (normalized.isEmpty || normalized == '+') {
    _snack(context, 'Telefon raqami topilmadi');
    return;
  }

  final uri = Uri(scheme: 'tel', path: normalized);
  final supported = await canLaunchUrl(uri);
  final launched = supported && await launchUrl(uri);
  if (!launched && context.mounted) {
    _snack(context, 'Qo‘ng‘iroqni ochib bo‘lmadi');
  }
}

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
            onTap: () => Navigator.of(
              context,
            ).push(sfPageRoute(AvatarPickerScreen(colors: c))),
            child: SfAvatar(
              name: cfg.who,
              size: 36,
              color: cfg.accent(c),
              choice: store.avatarChoice,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hello,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 11,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          // Quick chat access (Sardor's console has no Chat tab — it lives here).
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              sfPageRoute(SfTheme(colors: c, child: const _MessagesPage())),
            ),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: c.ink2,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showNotifications(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 19,
                    color: c.ink2,
                  ),
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface2, width: 2),
                      ),
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
  Navigator.of(context).push(
    sfPageRoute(
      SfTheme(
        colors: c,
        child: NotificationsScreen(colors: c),
      ),
    ),
  );
}

/// One notification feed entry.
class _Notif {
  final IconData icon;
  final PillTone tone;
  final String title, body, time, group;
  final bool unread;
  const _Notif(
    this.icon,
    this.tone,
    this.title,
    this.body,
    this.time,
    this.group, {
    this.unread = false,
  });
}

const _kNotifs = <_Notif>[
  _Notif(
    Icons.payments_rounded,
    PillTone.success,
    "Yangi to'lov qabul qilindi",
    'Azizova Madina · 600 000 so‘m · Payme',
    '2 daq oldin',
    'today',
    unread: true,
  ),
  _Notif(
    Icons.flag_rounded,
    PillTone.danger,
    'Sebzorda yangi anomaliya signali',
    'Naqd · kvitansiyasiz · AI skor 88',
    '18 daq oldin',
    'today',
    unread: true,
  ),
  _Notif(
    Icons.groups_rounded,
    PillTone.primary,
    "Ingliz B2 guruhi to'ldi",
    '18/18 o‘rin band · yangi guruh ochish mumkin',
    '1 soat oldin',
    'today',
    unread: true,
  ),
  _Notif(
    Icons.task_alt_rounded,
    PillTone.warn,
    "3 ta yangi tasdiq so'rovi",
    "To'lov qaytarish · ta'til · chiqarish",
    '2 soat oldin',
    'today',
  ),
  _Notif(
    Icons.call_rounded,
    PillTone.danger,
    "Eshmatov Otabek — qo'ng'iroq kerak",
    "Ota-onaga 21 kundan beri qo'ng'iroq qilinmagan",
    'Kecha 16:20',
    'earlier',
  ),
  _Notif(
    Icons.emoji_events_rounded,
    PillTone.accent,
    'Yangi reyting natijasi',
    "Chilonzor filiali oyning eng yaxshisi",
    'Kecha 12:05',
    'earlier',
  ),
  _Notif(
    Icons.warning_amber_rounded,
    PillTone.warn,
    '142 oila qarzdor',
    '38 tasi 30+ kun · eslatma yuborish tavsiya etiladi',
    '2 kun oldin',
    'earlier',
  ),
];

/// Full notifications page (was a bottom sheet) — grouped Today / Earlier,
/// each entry with an icon, body and relative time.
class NotificationsScreen extends StatelessWidget {
  final SfColors colors;
  const NotificationsScreen({super.key, required this.colors});

  Color _toneColor(SfColors c, PillTone t) => switch (t) {
    PillTone.success => c.success,
    PillTone.danger => c.danger,
    PillTone.warn => c.warn,
    PillTone.primary => c.primary,
    PillTone.accent => c.ai,
    PillTone.neutral => c.muted,
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final today = _kNotifs.where((n) => n.group == 'today').toList();
    final earlier = _kNotifs.where((n) => n.group == 'earlier').toList();
    final unread = _kNotifs.where((n) => n.unread).length;
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
            tr(context, 'notifs_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Pill(
                    '$unread ${tr(context, 'notif_new')}',
                    tone: PillTone.danger,
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (today.isNotEmpty) ...[
              _setSec(c, tr(context, 'notif_today')),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < today.length; i++)
                      _notifRow(context, c, today[i], i == today.length - 1),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (earlier.isNotEmpty) ...[
              _setSec(c, tr(context, 'notif_earlier')),
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < earlier.length; i++)
                      _notifRow(
                        context,
                        c,
                        earlier[i],
                        i == earlier.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: Container(
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
          child: SfButton(
            icon: Icons.done_all_rounded,
            label: tr(context, 'notif_mark_read'),
            primary: true,
            onTap: () {
              Navigator.of(context).maybePop();
              _snack(
                context,
                tr(context, 'notif_all_read'),
                bg: const Color(0xFF4F7B3B),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _notifRow(BuildContext context, SfColors c, _Notif n, bool last) {
    final col = _toneColor(c, n.tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(n.icon, size: 18, color: col),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (n.unread)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: c.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 11,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  n.time,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    color: c.muted2,
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
  final String? sub;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Kpi({
    required this.label,
    required this.value,
    this.color,
    this.trend,
    this.spark,
    this.sub,
    this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SfTap(
      scale: onTap == null ? 1 : 0.985,
      child: SfSurfaceCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: c.muted,
                          ),
                        ),
                      ),
                      if (icon != null)
                        Icon(icon, size: 15, color: color ?? c.muted2),
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
                          child: _mono(context, value, color: color),
                        ),
                      ),
                      if (trend != null) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${trend!.up ? '↑' : '↓'}${trend!.v}',
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: trend!.up ? c.success : c.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 9.5,
                        color: c.muted,
                      ),
                    ),
                  ] else if (spark != null) ...[
                    const SizedBox(height: 6),
                    Sparkline(
                      data: spark!,
                      color: color ?? c.primary,
                      height: 22,
                    ),
                  ],
                ],
              ),
            ),
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
  Widget build(BuildContext context) =>
      _ReferenceDashboardPage(cfg: cfg, go: go);

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    if (cfg.role == SfRole.audit) return _AuditDash(cfg: cfg, go: go);
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final ceo = cfg.role == SfRole.ceo;
    final num baseRev = ceo ? 1284000000 : 342000000;
    final num rev = store.scopedRevenue(baseRev);
    final num debt = ((ceo ? 84000000 : 22400000) * store.rangeFactor).round();
    final studentsTotal = store.scopedStudents(ceo ? 1842 : 512);
    final attendance = store.scopedAttendance(91);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TopBar(
          cfg: cfg,
          hello: ceo ? tr(context, 'greet_ceo') : tr(context, 'greet_manager'),
          sub: ceo ? tr(context, 'scope_all') : cfg.scope,
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchPill(
                onTap: () =>
                    _snack(context, '🔎 ${tr(context, 'search_hint')}'),
              ),
              const SizedBox(height: 12),
              _DashHeader(
                eyebrow: tr(
                  context,
                  ceo ? 'dash_eyebrow_ceo' : 'dash_eyebrow_manager',
                ),
                title: tr(
                  context,
                  ceo ? 'dash_title_ceo' : 'dash_title_manager',
                ),
                sub: tr(context, ceo ? 'dash_sub_ceo' : 'dash_sub_manager'),
                reportLabel: tr(context, 'btn_report'),
                // CEO no longer has the unused "new branch" action here.
                newLabel: ceo ? null : tr(context, 'btn_new_group'),
                accent: c.primary,
                onReport: () => Navigator.of(
                  context,
                ).push(sfPageRoute(ReportScreen(colors: c, role: cfg.role))),
                onNew: ceo
                    ? null
                    : () => _showCreateSheet(
                        context,
                        SettingsScope.of(context),
                        'create_group',
                      ),
              ),
              const SizedBox(height: 14),
              _CeoContextFilter(showBranches: ceo),
              const SizedBox(height: 12),
              _kpiGrid([
                _Kpi(
                  label: tr(context, 'kpi_revenue'),
                  value: fmtMoneyMln(rev),
                  color: c.success,
                  icon: Icons.trending_up_rounded,
                  trend: (up: true, v: '12.4%'),
                  spark: const [
                    60,
                    64,
                    62,
                    70,
                    68,
                    76,
                    80,
                    78,
                    86,
                    90,
                    94,
                    100,
                  ],
                  onTap: () => Navigator.of(
                    context,
                  ).push(sfPageRoute(LedgerScreen(colors: c))),
                ),
                _Kpi(
                  label: tr(context, 'kpi_students'),
                  value: '$studentsTotal',
                  icon: Icons.groups_rounded,
                  trend: (up: true, v: '4.1%'),
                  spark: const [
                    70,
                    72,
                    74,
                    73,
                    78,
                    82,
                    85,
                    88,
                    90,
                    92,
                    96,
                    100,
                  ],
                  onTap: () => go('students'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_attendance'),
                  value: '$attendance%',
                  color: c.primary,
                  icon: Icons.check_circle_outline_rounded,
                  trend: (up: true, v: '0.8%'),
                  spark: const [88, 90, 87, 91, 89, 92, 90, 93, 91, 92, 90, 91],
                  onTap: () => Navigator.of(context).push(
                    sfPageRoute(
                      SfTheme(
                        colors: c,
                        child: AttendanceScreen(colors: c),
                      ),
                    ),
                  ),
                ),
                _Kpi(
                  label: tr(context, 'kpi_churn'),
                  value: '3.4%',
                  color: c.danger,
                  icon: Icons.trending_down_rounded,
                  trend: (up: false, v: '0.6%'),
                  sub: 'Maqsad: < 4%',
                  onTap: () => go('ai'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_debt'),
                  value: fmtMoneyMln(debt),
                  color: c.warn,
                  icon: Icons.flag_rounded,
                  sub: ceo ? '142 oila' : '38 oila',
                  onTap: () => go('students'),
                ),
                ceo
                    ? _Kpi(
                        label: tr(context, 'kpi_nps'),
                        value: '72',
                        color: c.accent,
                        icon: Icons.star_rounded,
                        trend: (up: true, v: '5'),
                        sub: 'Ota-onalar',
                        onTap: () => go('ai'),
                      )
                    : _Kpi(
                        label: tr(context, 'kpi_pending'),
                        value: '${store.pendingCount}',
                        color: c.warn,
                        icon: Icons.task_alt_rounded,
                        sub: "To'lov · ta'til",
                        onTap: () => go('approvals'),
                      ),
              ]),
              const SizedBox(height: 12),
              _RevenueCard(
                ceo: ceo,
                rev: rev,
                color: c.success,
                onLink: () => Navigator.of(
                  context,
                ).push(sfPageRoute(LedgerScreen(colors: c))),
              ),
              SfAiCard(
                badge: 'Strategik',
                quote: store.stats.aiQuote,
                onTap: () => go(ceo ? 'ai' : 'approvals'),
              ),
              if (ceo)
                SfCard(
                  child: Column(
                    children: [
                      SfCardHeader(
                        tr(context, 'card_branch_rank'),
                        link: tr(context, 'link_all'),
                        onTap: () => go('students'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: HBars(
                          ranked: true,
                          rows: [
                            for (final b in store.branches)
                              HBarRow(
                                b.name,
                                b.revenue.toDouble(),
                                fmtMoneyMln(b.revenue),
                                b.mark,
                                mark: true,
                                onTap: () => Navigator.of(context).push(
                                  sfPageRoute(
                                    BranchWorkspaceScreen(branch: b, colors: c),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                _ManagerApprovalsPreview(go: go),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  sfPageRoute(
                    SfTheme(
                      colors: c,
                      child: AttendanceScreen(colors: c),
                    ),
                  ),
                ),
                child: SfCard(
                  child: Column(
                    children: [
                      SfCardHeader(
                        tr(context, 'card_attendance_health'),
                        link: tr(context, 'link_all'),
                        onTap: () => Navigator.of(context).push(
                          sfPageRoute(
                            SfTheme(
                              colors: c,
                              child: AttendanceScreen(colors: c),
                            ),
                          ),
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
                                  LegendRow(
                                    c.success,
                                    tr(context, 'legend_good'),
                                    '72%',
                                  ),
                                  LegendRow(
                                    c.warn,
                                    tr(context, 'legend_mid'),
                                    '19%',
                                  ),
                                  LegendRow(
                                    c.danger,
                                    tr(context, 'legend_low'),
                                    '9%',
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
              ),
              if (ceo) ...[
                const SizedBox(height: 12),
                _CeoDashboardExtras(colors: c),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Rebuilt dashboard composition using the reference app's large header,
/// metric-card grid, status tiles and editorial decision surfaces.
class _ReferenceDashboardPage extends StatelessWidget {
  const _ReferenceDashboardPage({required this.cfg, required this.go});

  final RoleConfig cfg;
  final void Function(String tab) go;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final ceo = cfg.role == SfRole.ceo;
    final audit = cfg.role == SfRole.audit;
    final revenue = store.scopedRevenue(ceo ? 1284000000 : 342000000);
    final debt = ((ceo ? 84000000 : 22400000) * store.rangeFactor).round();
    final students = store.scopedStudents(ceo ? 1842 : 512);
    final attendance = store.scopedAttendance(91);
    final title = audit
        ? tr(context, 'greet_audit')
        : tr(context, ceo ? 'dash_title_ceo' : 'dash_title_manager');
    final subtitle = audit
        ? tr(context, 'audit_sub')
        : tr(context, ceo ? 'dash_sub_ceo' : 'dash_sub_manager');
    final metrics = audit
        ? <Widget>[
            RefMetricCard(
              label: tr(context, 'kpi_open_flags'),
              value: '12',
              icon: Icons.flag_rounded,
              tone: RefMetricTone.danger,
              detail: '3 ta yuqori',
              onTap: () => go('anomalies'),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_active_cases'),
              value: '8',
              icon: Icons.push_pin_rounded,
              tone: RefMetricTone.primary,
              detail: '2 ta jiddiy',
              onTap: () => go('cases'),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_anom_score'),
              value: '2.4%',
              icon: Icons.analytics_outlined,
              tone: RefMetricTone.warning,
              detail: 'tranzaksiyalar',
              onTap: () => go('anomalies'),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_compliance'),
              value: '96.8%',
              icon: Icons.shield_rounded,
              tone: RefMetricTone.success,
              detail: '+1.2%',
              onTap: () => go('cases'),
            ),
          ]
        : <Widget>[
            RefMetricCard(
              label: tr(context, 'kpi_revenue'),
              value: fmtMoneyMln(revenue),
              icon: Icons.trending_up_rounded,
              tone: RefMetricTone.success,
              detail: '+12.4%',
              onTap: () => Navigator.of(
                context,
              ).push(sfPageRoute(LedgerScreen(colors: c))),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_students'),
              value: '$students',
              icon: Icons.groups_rounded,
              tone: RefMetricTone.primary,
              detail: '+4.1%',
              onTap: () => go('students'),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_attendance'),
              value: '$attendance%',
              icon: Icons.how_to_reg_rounded,
              tone: RefMetricTone.success,
              detail: '+0.8%',
              onTap: () => Navigator.of(context).push(
                sfPageRoute(
                  SfTheme(
                    colors: c,
                    child: AttendanceScreen(colors: c),
                  ),
                ),
              ),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_churn'),
              value: '3.4%',
              icon: Icons.trending_down_rounded,
              tone: RefMetricTone.danger,
              detail: 'Maqsad: < 4%',
              onTap: () => go('ai'),
            ),
            RefMetricCard(
              label: tr(context, 'kpi_debt'),
              value: fmtMoneyMln(debt),
              icon: Icons.account_balance_wallet_outlined,
              tone: RefMetricTone.warning,
              detail: ceo ? '142 oila' : '38 oila',
              onTap: () => go('students'),
            ),
            RefMetricCard(
              label: ceo ? tr(context, 'kpi_nps') : tr(context, 'kpi_pending'),
              value: ceo ? '72' : '${store.pendingCount}',
              icon: ceo ? Icons.star_rounded : Icons.task_alt_rounded,
              tone: ceo ? RefMetricTone.accent : RefMetricTone.warning,
              detail: ceo ? 'Ota-onalar' : "To'lov · ta'til",
              onTap: () => go(ceo ? 'ai' : 'approvals'),
            ),
          ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RefLargeHeader(
          eyebrow: audit
              ? tr(context, 'audit_eyebrow')
              : tr(context, ceo ? 'dash_eyebrow_ceo' : 'dash_eyebrow_manager'),
          title: title,
          subtitle: subtitle,
          leading: RefPressable(
            onPressed: () => Navigator.of(
              context,
            ).push(sfPageRoute(AvatarPickerScreen(colors: c))),
            borderRadius: RefRadius.md,
            semanticLabel: 'Profil rasmi',
            child: SfAvatar(
              name: cfg.who,
              size: 38,
              color: cfg.accent(c),
              choice: store.avatarChoice,
            ),
          ),
          actions: [
            RefIconAction(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Xabarlar',
              onPressed: () => Navigator.of(context).push(
                sfPageRoute(SfTheme(colors: c, child: const _MessagesPage())),
              ),
            ),
            RefIconAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Bildirishnomalar',
              badge: 1,
              onPressed: () => _showNotifications(context),
            ),
            RefIconAction(
              icon: Icons.description_outlined,
              tooltip: audit
                  ? tr(context, 'btn_audit_report')
                  : tr(context, 'btn_report'),
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(ReportScreen(colors: c, role: cfg.role))),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RefPressable(
                onPressed: () =>
                    _snack(context, '🔎 ${tr(context, 'search_hint')}'),
                borderRadius: RefRadius.md,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: RefRadius.md,
                    border: Border.all(color: c.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 19, color: c.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(context, 'search_hint'),
                            style: RefType.ui(size: 13, color: c.muted),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: c.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!audit) ...[
                const SizedBox(height: 12),
                _ReferenceDashboardContext(showBranches: ceo),
              ],
              const SizedBox(height: 16),
              RefAdaptiveGrid(children: metrics),
              const SizedBox(height: 16),
              if (!audit)
                _ReferenceRevenuePanel(
                  revenue: revenue,
                  ceo: ceo,
                  onTap: () => Navigator.of(
                    context,
                  ).push(sfPageRoute(LedgerScreen(colors: c))),
                )
              else
                _ReferenceAuditSignals(onTap: () => go('anomalies')),
              const SizedBox(height: 12),
              _ReferenceAiInsight(
                quote: audit
                    ? 'Sebzorda 3 ta yuqori signal: davomat, naqd to‘lov va karta nomutanosibligi.'
                    : store.stats.aiQuote,
                onTap: () => go(
                  audit
                      ? 'anomalies'
                      : ceo
                      ? 'ai'
                      : 'approvals',
                ),
                audit: audit,
              ),
              const SizedBox(height: 20),
              if (audit)
                _ReferenceAuditQueue(onTap: () => go('anomalies'))
              else ...[
                _ReferenceTeacherRanking(store: store, colors: c),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: tr(context, 'card_branch_rank'),
                  subtitle: ceo
                      ? 'Filiallar bo‘yicha joriy ko‘rsatkich'
                      : 'Operatsion ustuvorliklar',
                ),
                const SizedBox(height: 8),
                _ReferenceBranchRank(
                  branches: store.branches,
                  colors: c,
                  onOpen: (branch) => Navigator.of(context).push(
                    sfPageRoute(
                      BranchWorkspaceScreen(branch: branch, colors: c),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: tr(context, 'card_attendance_health'),
                  subtitle: 'Bugungi holat',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      sfPageRoute(
                        SfTheme(
                          colors: c,
                          child: AttendanceScreen(colors: c),
                        ),
                      ),
                    ),
                    child: Text(
                      tr(context, 'link_all'),
                      style: RefType.ui(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ReferenceAttendanceHealth(
                  onTap: () => Navigator.of(context).push(
                    sfPageRoute(
                      SfTheme(
                        colors: c,
                        child: AttendanceScreen(colors: c),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceDashboardContext extends StatelessWidget {
  const _ReferenceDashboardContext({required this.showBranches});

  final bool showBranches;

  String _short(DateTime date) {
    const months = [
      'Yan',
      'Fev',
      'Mar',
      'Apr',
      'May',
      'Iyn',
      'Iyl',
      'Avg',
      'Sen',
      'Okt',
      'Noy',
      'Dek',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _chooseRange(BuildContext context, AppStore store) async {
    final c = SfTheme.of(context);
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: store.selectedRange,
      helpText: 'Hisobot davrini tanlang',
      saveText: 'Qo‘llash',
      cancelText: 'Bekor qilish',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: c.primary,
            surface: c.surface,
            onSurface: c.ink,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: c.surface,
            shape: const RoundedRectangleBorder(borderRadius: RefRadius.xl),
          ),
        ),
        child: child!,
      ),
    );
    if (value != null) store.setDateRange(value);
  }

  Future<void> _chooseBranch(BuildContext context, AppStore store) async {
    final c = SfTheme.of(context);
    final options = <String>[
      '__all',
      ...store.branches.map((branch) => branch.name),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: DraggableScrollableSheet(
          initialChildSize: .58,
          minChildSize: .36,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: RefRadius.pill,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Filialni tanlang',
                      style: RefType.ui(
                        size: 19,
                        weight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: options.isEmpty
                        ? Center(
                            child: Text(
                              'Filiallar topilmadi',
                              style: RefType.ui(size: 13, color: c.muted),
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final name = options[index];
                              final selected = name == store.selectedBranch;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RefStatusTile(
                                  icon: Icons.account_tree_rounded,
                                  title: name == '__all'
                                      ? 'Barcha filiallar'
                                      : name,
                                  subtitle: selected
                                      ? 'Tanlangan'
                                      : 'Hisobot doirasiga qo‘shish',
                                  tone: selected
                                      ? RefMetricTone.primary
                                      : RefMetricTone.neutral,
                                  onTap: () {
                                    store.setBranchScope(name);
                                    Navigator.of(sheetContext).pop();
                                  },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final items = <Widget>[
      _ReferenceContextAction(
        icon: Icons.date_range_rounded,
        label:
            '${_short(store.selectedRange.start)} — ${_short(store.selectedRange.end)}',
        onTap: () => _chooseRange(context, store),
      ),
    ];
    if (showBranches) {
      items.insert(
        0,
        _ReferenceContextAction(
          icon: Icons.account_tree_rounded,
          label: store.allBranchesSelected
              ? 'Barcha filiallar'
              : store.selectedBranch,
          onTap: () => _chooseBranch(context, store),
        ),
      );
    }
    if (store.hasCustomReportFilters) {
      items.add(
        _ReferenceContextAction(
          icon: Icons.restart_alt_rounded,
          label: 'Tiklash',
          onTap: store.resetReportFilters,
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class _ReferenceContextAction extends StatelessWidget {
  const _ReferenceContextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.md,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: RefRadius.md,
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c.primary),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 156),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: RefType.ui(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 17, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceRevenuePanel extends StatefulWidget {
  const _ReferenceRevenuePanel({
    required this.revenue,
    required this.ceo,
    required this.onTap,
  });

  final num revenue;
  final bool ceo;
  final VoidCallback onTap;

  @override
  State<_ReferenceRevenuePanel> createState() => _ReferenceRevenuePanelState();
}

class _ReferenceRevenuePanelState extends State<_ReferenceRevenuePanel> {
  int _months = 12;
  int? _selectedPoint;

  static const _monthlyRevenue = <double>[
    60,
    64,
    62,
    70,
    68,
    76,
    80,
    78,
    86,
    90,
    94,
    100,
  ];

  static final _dates = <DateTime>[
    DateTime(2025, 8, 20),
    DateTime(2025, 9, 20),
    DateTime(2025, 10, 20),
    DateTime(2025, 11, 20),
    DateTime(2025, 12, 20),
    DateTime(2026, 1, 20),
    DateTime(2026, 2, 20),
    DateTime(2026, 3, 20),
    DateTime(2026, 4, 20),
    DateTime(2026, 5, 20),
    DateTime(2026, 6, 20),
    DateTime(2026, 7, 20),
  ];

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final start = _months == 6 ? _monthlyRevenue.length - 6 : 0;
    final baseline = widget.ceo ? 1284000000 : 342000000;
    final scale = widget.revenue / baseline;
    final visible = _monthlyRevenue
        .sublist(start)
        .map((value) => value * 1e6 * scale)
        .toList();
    final dates = _dates.sublist(start);
    final spots = <FlSpot>[
      for (var index = 0; index < visible.length; index++)
        FlSpot(index.toDouble(), visible[index] / 1e6),
    ];
    final values = spots.map((spot) => spot.y).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) * .92).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.08).ceilToDouble();
    final horizontalInterval =
        ((maxY - minY) / 3).clamp(1, double.infinity).toDouble();
    return RefSurfaceCard(
      padding: EdgeInsets.zero,
      elevated: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.successSoft, c.surface, c.primarySoft],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RefPressable(
                onPressed: widget.onTap,
                borderRadius: RefRadius.md,
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: .72),
                        borderRadius: RefRadius.sm,
                      ),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: c.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daromad ko‘rinishi',
                            style: RefType.ui(
                              size: 14,
                              weight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            widget.ceo ? 'Barcha filiallar' : 'Joriy filial',
                            style: RefType.ui(size: 11, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: c.primary),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                fmtMoneyMln(widget.revenue),
                style: RefType.mono(
                  size: 28,
                  weight: FontWeight.w800,
                  color: c.success,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '+12.4% o‘tgan davrga nisbatan',
                style: RefType.ui(
                  size: 12,
                  weight: FontWeight.w700,
                  color: c.success,
                ),
              ),
              const SizedBox(height: 14),
              RefSegmentedControl<int>(
                values: const [6, 12],
                selected: _months,
                labelOf: (value) => '$value oy',
                onChanged: (value) => setState(() {
                  _months = value;
                  _selectedPoint = null;
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: horizontalInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: c.border.withValues(alpha: .8),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: _months == 12 ? 2 : 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 ||
                                index >= dates.length ||
                                value != index) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                '${dates[index].month.toString().padLeft(2, '0')}/${dates[index].year.toString().substring(2)}',
                                style: RefType.mono(
                                  size: 8.5,
                                  weight: FontWeight.w700,
                                  color: c.muted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: minY,
                          color: c.success.withValues(alpha: .24),
                          strokeWidth: 1,
                        ),
                        HorizontalLine(
                          y: maxY,
                          color: c.success.withValues(alpha: .16),
                          strokeWidth: 1,
                        ),
                      ],
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchCallback: (event, response) {
                        final touched = response?.lineBarSpots;
                        if (touched == null || touched.isEmpty) return;
                        final next = touched.first.spotIndex;
                        if (next != _selectedPoint) {
                          setState(() => _selectedPoint = next);
                        }
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => c.ink,
                        tooltipRoundedRadius: 10,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        tooltipMargin: 12,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touchedSpots) =>
                            touchedSpots.map((spot) {
                              final index = spot.spotIndex;
                              final amount = visible[index];
                              return LineTooltipItem(
                                '${_dateLabel(dates[index])}\n',
                                RefType.mono(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: c.bg,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Revenue: ${fmtMoney(amount)}',
                                    style: RefType.ui(
                                      size: 10.5,
                                      weight: FontWeight.w700,
                                      color: c.bg,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: .22,
                        color: c.success,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        showingIndicators: _selectedPoint == null
                            ? const []
                            : [_selectedPoint!],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: index == _selectedPoint ? 5 : 3.5,
                                color: c.surface,
                                strokeWidth: index == _selectedPoint ? 3 : 2,
                                strokeColor: c.success,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              c.success.withValues(alpha: .30),
                              c.success.withValues(alpha: .02),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceAiInsight extends StatelessWidget {
  const _ReferenceAiInsight({
    required this.quote,
    required this.onTap,
    required this.audit,
  });

  final String quote;
  final VoidCallback onTap;
  final bool audit;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.lg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.aiBg,
          ),
          borderRadius: RefRadius.lg,
          border: Border.all(color: c.aiBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: .6),
                  borderRadius: RefRadius.sm,
                ),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    audit ? Icons.shield_outlined : Icons.auto_awesome_rounded,
                    color: c.ai,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit ? 'AUDIT AI' : 'STRATEGIK AI',
                      style: RefType.eyebrow(color: c.ai, size: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quote,
                      style: RefType.display(
                        size: 16,
                        color: c.ink,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.arrow_forward_rounded, size: 18, color: c.ai),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceTeacherRanking extends StatelessWidget {
  const _ReferenceTeacherRanking({required this.store, required this.colors});

  final AppStore store;
  final SfColors colors;

  @override
  Widget build(BuildContext context) {
    final teachers = store.staff
        .where((member) => member.department.toLowerCase().contains('teach'))
        .take(3)
        .toList();
    final entries = teachers.isEmpty ? store.staff.take(3).toList() : teachers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefSectionHeader(
          title: 'O‘qituvchi reytingi',
          subtitle: 'Eng barqaror natija ko‘rsatganlar',
        ),
        const SizedBox(height: 8),
        RefSurfaceCard(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++)
                _ReferenceRankRow(
                  member: entries[index],
                  place: index + 1,
                  colors: colors,
                  last: index == entries.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceRankRow extends StatelessWidget {
  const _ReferenceRankRow({
    required this.member,
    required this.place,
    required this.colors,
    required this.last,
  });

  final StaffMember member;
  final int place;
  final SfColors colors;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tone = place == 1
        ? RefMetricTone.accent
        : place == 2
        ? RefMetricTone.primary
        : RefMetricTone.success;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: RefStatusTile(
        icon: place == 1
            ? Icons.workspace_premium_rounded
            : Icons.emoji_events_outlined,
        title: member.fullName,
        subtitle: '${member.branch} · ${member.subject}',
        tone: tone,
        trailing: RefPill(
          label: '#$place · ${99 - place}%',
          tone: place == 1 ? RefPillTone.accent : RefPillTone.success,
        ),
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(StaffDetailScreen(member: member, colors: colors))),
      ),
    );
  }
}

class _ReferenceBranchRank extends StatelessWidget {
  const _ReferenceBranchRank({
    required this.branches,
    required this.colors,
    required this.onOpen,
  });

  final List<Branch> branches;
  final SfColors colors;
  final ValueChanged<Branch> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final branch in branches) ...[
        RefStatusTile(
          icon: Icons.account_tree_rounded,
          title: branch.name,
          subtitle:
              '${fmtMoneyMln(branch.revenue)} · ${branch.students} o‘quvchi',
          tone: RefMetricTone.primary,
          trailing: RefPill(
            label: '${branch.attendance}%',
            tone: branch.attendance >= 92
                ? RefPillTone.success
                : branch.attendance >= 88
                ? RefPillTone.warning
                : RefPillTone.danger,
          ),
          onTap: () => onOpen(branch),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

class _ReferenceAttendanceHealth extends StatelessWidget {
  const _ReferenceAttendanceHealth({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: RefRadius.lg,
              ),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: Text(
                    '91%',
                    style: RefType.mono(
                      size: 19,
                      weight: FontWeight.w800,
                      color: c.success,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Davomat barqaror',
                    style: RefType.ui(
                      size: 14,
                      weight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '72% yaxshi · 19% kuzatuv · 9% e’tibor',
                    style: RefType.ui(size: 11.5, color: c.muted),
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: .91,
                    minHeight: 6,
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    color: c.success,
                    backgroundColor: c.surface3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _ReferenceAuditSignals extends StatelessWidget {
  const _ReferenceAuditSignals({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RefSectionHeader(
              title: 'Anomaliya signallari',
              subtitle: 'Oxirgi 12 kun',
              trailing: const RefPill(
                label: '12 ochiq',
                tone: RefPillTone.danger,
              ),
            ),
            const SizedBox(height: 14),
            Sparkline(
              data: const [4, 6, 3, 8, 5, 12, 7, 9, 6, 11, 8, 12],
              color: c.danger,
              height: 70,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Davomat · 5',
                    style: RefType.ui(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.danger,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Karta · 5',
                    style: RefType.ui(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.warn,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Moliya · 2',
                    style: RefType.ui(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceAuditQueue extends StatelessWidget {
  const _ReferenceAuditQueue({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const RefSectionHeader(
        title: 'So‘nggi signallar',
        subtitle: 'Ustuvor tekshiruvlar',
      ),
      const SizedBox(height: 8),
      RefStatusTile(
        icon: Icons.warning_amber_rounded,
        title: 'Davomat 100% · 21 kun',
        subtitle: 'Sebzor · yuqori signal',
        tone: RefMetricTone.danger,
        onTap: onTap,
      ),
      const SizedBox(height: 8),
      RefStatusTile(
        icon: Icons.auto_graph_rounded,
        title: '48 Up karta / hafta',
        subtitle: 'Mirobod · o‘rta signal',
        tone: RefMetricTone.warning,
        onTap: onTap,
      ),
      const SizedBox(height: 8),
      RefStatusTile(
        icon: Icons.receipt_long_rounded,
        title: 'Naqd · kvitansiyasiz',
        subtitle: 'Sebzor · yuqori signal',
        tone: RefMetricTone.danger,
        onTap: onTap,
      ),
    ],
  );
}

/// CEO-only decision feed at the bottom of the dashboard: teacher leaders and
/// recent operational history are both tappable, instead of static screenshots.
class _CeoDashboardExtras extends StatelessWidget {
  final SfColors colors;
  const _CeoDashboardExtras({required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final store = AppScope.of(context);
    final topStudents = [...store.students]
      ..sort((a, b) {
        final ratingOrder = studentRating(b).compareTo(studentRating(a));
        return ratingOrder != 0
            ? ratingOrder
            : b.attendance.compareTo(a.attendance);
      });
    Widget teacher(
      String name,
      String branch,
      String attendance,
      String rating, {
      bool last = false,
    }) => InkWell(
      onTap: () {
        final member = store.staff.firstWhere(
          (item) => item.fullName == name,
          orElse: () {
            final parts = name.split(' ');
            return StaffMember(
              firstName: parts.first,
              lastName: parts.skip(1).join(' '),
              username: parts.first.toLowerCase(),
              phone: '—',
              email: null,
              branch: branch,
              department: 'Teaching',
              subject: 'Education',
              qualification: 'Teacher',
              salaryType: 'Monthly',
              rate: '—',
              gender: '—',
              hireDate: '—',
            );
          },
        );
        Navigator.of(
          context,
        ).push(sfPageRoute(StaffDetailScreen(member: member, colors: c)));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SfAvatar(name: name, size: 29),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
            Text(
              branch,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 10,
                color: c.muted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              attendance,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: c.warn,
              ),
            ),
            const SizedBox(width: 8),
            Pill(rating, tone: PillTone.success),
          ],
        ),
      ),
    );
    Widget event(
      IconData icon,
      Color color,
      String title,
      String time, {
      bool last = false,
    }) => InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(sfPageRoute(ActivityHistoryScreen(colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 9.5,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        SfCard(
          child: Column(
            children: [
              const SfCardHeader('O‘qituvchilar reytingi · top'),
              teacher('Madina Halimova', 'Yunusobod', '87%', '★5'),
              teacher('Sevara Ibragimova', 'Chilonzor', '90%', '★5'),
              teacher('Munira Tosheva', 'Mirobod', '93%', '★5', last: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SfCard(
          child: Column(
            children: [
              SfCardHeader(
                'Eng yaxshi o‘quvchilar',
                link: 'Barchasi',
                onTap: () => Navigator.of(
                  context,
                ).push(sfPageRoute(TopStudentsScreen(colors: c))),
              ),
              for (int i = 0; i < topStudents.take(3).length; i++)
                _TopStudentPreviewRow(
                  student: topStudents[i],
                  last: i == topStudents.take(3).length - 1,
                  onTap: () => Navigator.of(context).push(
                    sfPageRoute(
                      StudentDetailScreen(student: topStudents[i], colors: c),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SfCard(
          child: Column(
            children: [
              const SfCardHeader('So‘nggi hodisalar'),
              event(
                Icons.trending_up_rounded,
                c.success,
                'Yangi to‘lov · 1.2 mln',
                '2 daq',
              ),
              event(
                Icons.notifications_active_rounded,
                c.warn,
                'Qarz eslatmasi yuborildi',
                '14 daq',
              ),
              event(
                Icons.flag_rounded,
                c.danger,
                'Audit flag · davomati past',
                '2 soat',
                last: true,
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
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(context, 'search_hint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 13,
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

/// Shared branch + calendar context for CEO reporting. It deliberately writes
/// to [AppStore], so every report and dashboard widget rebuilds against the
/// same selected branch and date window.
class _CeoContextFilter extends StatelessWidget {
  final bool showBranches;
  const _CeoContextFilter({required this.showBranches});

  String _shortDate(DateTime date) {
    const months = [
      'Yan',
      'Fev',
      'Mar',
      'Apr',
      'May',
      'Iyn',
      'Iyl',
      'Avg',
      'Sen',
      'Okt',
      'Noy',
      'Dek',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _chooseRange(BuildContext context, AppStore store) async {
    final c = SfTheme.of(context);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: store.selectedRange,
      helpText: 'Hisobot davrini tanlang',
      saveText: 'Qo‘llash',
      cancelText: 'Bekor qilish',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: c.primary,
            surface: c.surface,
            onSurface: c.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) store.setDateRange(range);
  }

  void _chooseBranch(BuildContext context, AppStore store) {
    final c = SfTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: _SheetShell(
          children: [
            Text(
              'Filialni tanlang',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in ['__all', ...store.branches.map((b) => b.name)])
              InkWell(
                onTap: () {
                  store.setBranchScope(item);
                  Navigator.of(sheetContext).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item == '__all' ? 'Barcha filiallar' : item,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                      ),
                      if (store.selectedBranch == item)
                        Icon(Icons.check_rounded, color: c.primary, size: 19),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final changed = store.hasCustomReportFilters;
    Widget action({
      required IconData icon,
      required String value,
      required VoidCallback onTap,
    }) => Expanded(
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 17, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        if (showBranches) ...[
          action(
            icon: Icons.account_tree_rounded,
            value: store.allBranchesSelected
                ? 'Barcha filiallar'
                : store.selectedBranch,
            onTap: () => _chooseBranch(context, store),
          ),
          const SizedBox(width: 8),
        ],
        action(
          icon: Icons.date_range_rounded,
          value:
              '${_shortDate(store.selectedRange.start)} — ${_shortDate(store.selectedRange.end)}',
          onTap: () => _chooseRange(context, store),
        ),
        if (changed) ...[
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Filtrlarni tiklash',
            onPressed: store.resetReportFilters,
            icon: Icon(Icons.restart_alt_rounded, color: c.muted),
          ),
        ],
      ],
    );
  }
}

/// Dashboard page header: dated eyebrow, big title, sub, and two action buttons.
class _DashHeader extends StatelessWidget {
  final String eyebrow, title, sub, reportLabel;
  final String? newLabel;
  final Color accent;
  final VoidCallback onReport;
  final VoidCallback? onNew;
  const _DashHeader({
    required this.eyebrow,
    required this.title,
    required this.sub,
    required this.reportLabel,
    this.newLabel,
    required this.accent,
    required this.onReport,
    this.onNew,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: c.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted),
        ),
        const SizedBox(height: 12),
        if (newLabel == null)
          SizedBox(
            width: double.infinity,
            child: _ActionBtn(
              icon: Icons.download_rounded,
              label: reportLabel,
              primary: false,
              accent: accent,
              onTap: onReport,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.download_rounded,
                  label: reportLabel,
                  primary: false,
                  accent: accent,
                  onTap: onReport,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.add_rounded,
                  label: newLabel!,
                  primary: true,
                  accent: accent,
                  onTap: onNew!,
                ),
              ),
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
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.primary,
    required this.accent,
    required this.onTap,
  });
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
              border: primary ? null : Border.all(color: c.border),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: primary ? Colors.white : c.ink2),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primary ? Colors.white : c.ink2,
                    ),
                  ),
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
  const _RevenueCard({
    required this.ceo,
    required this.rev,
    required this.color,
    required this.onLink,
  });
  @override
  State<_RevenueCard> createState() => _RevenueCardState();
}

class _RevenueCardState extends State<_RevenueCard> {
  static const List<double> _all = [
    820,
    860,
    910,
    890,
    960,
    1020,
    1080,
    1040,
    1140,
    1180,
    1220,
    1284,
  ];
  static const List<String> _labels = [
    'Iyn',
    'Iyl',
    'Avg',
    'Sen',
    'Okt',
    'Noy',
    'Dek',
    'Yan',
    'Fev',
    'Mar',
    'Apr',
    'May',
  ];
  int seg = 0; // 0 = 12 oy, 1 = 6 oy, 2 = YTD
  int? point;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final start = seg == 1
        ? 6
        : seg == 2
        ? 7
        : 0;
    final baseline = widget.ceo ? 1284000000 : 342000000;
    final scale = widget.rev / baseline;
    final data = _all.sublist(start).map((e) => e * 1e6 * scale).toList();
    final labels = _labels.sublist(start);
    final segLabels = [
      tr(context, 'seg_12mo'),
      tr(context, 'seg_6mo'),
      tr(context, 'seg_ytd'),
    ];
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
                    child: Text(
                      tr(
                        context,
                        widget.ceo ? 'card_rev_dynamics' : 'card_branch_rev',
                      ),
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 3; i++)
                        GestureDetector(
                          onTap: () => setState(() {
                            seg = i;
                            // A point selected in the 12-month view can be
                            // outside the 6-month/YTD data set.
                            point = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: seg == i ? c.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: seg == i
                                  ? Border.all(color: c.border)
                                  : null,
                            ),
                            child: Text(
                              segLabels[i],
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: seg == i ? c.ink : c.muted,
                              ),
                            ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                void pick(Offset position) {
                  final usable = constraints.maxWidth - 12;
                  final x = (position.dx - 6).clamp(0.0, usable);
                  final next = (x / usable * (data.length - 1)).round();
                  if (next != point) setState(() => point = next);
                }

                return MouseRegion(
                  onHover: (event) => pick(event.localPosition),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => pick(details.localPosition),
                    onLongPressEnd: (_) => setState(() => point = null),
                    child: Stack(
                      children: [
                        AreaChart(
                          color: widget.color,
                          height: 144,
                          data: data,
                          labels: labels,
                        ),
                        if (point != null && point! < data.length)
                          Positioned(
                            top: 6,
                            left: point! < data.length / 2 ? 8 : null,
                            right: point! >= data.length / 2 ? 8 : null,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: c.ink,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${labels[point!]} · ${fmtMoneyMln(data[point!])}',
                                  style: TextStyle(
                                    fontFamily: SfType.mono,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: c.bg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                _foot(
                  context,
                  tr(context, 'foot_forecast'),
                  fmtMoneyMln(widget.rev * 12.4),
                ),
                _foot(
                  context,
                  tr(context, 'foot_avg_check'),
                  fmtMoneyMln(680000),
                  border: true,
                ),
                _foot(context, tr(context, 'foot_pay_rate'), '94.2%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _foot(
    BuildContext context,
    String l,
    String v, {
    bool border = false,
  }) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: border ? BorderSide(color: c.border) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              v,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
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
          SfCardHeader(
            '${tr(context, 'card_approvals')} · ${store.pendingCount}',
            link: tr(context, 'link_all'),
            onTap: () => go('approvals'),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              child: Text(
                tr(context, 'no_requests'),
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 11.5,
                  color: c.muted,
                ),
              ),
            )
          else
            for (int i = 0; i < rows.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openApproval(context, store, rows[i], c),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: i < rows.length - 1
                          ? BorderSide(color: c.border)
                          : BorderSide.none,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.warnSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: c.warn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].title,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              rows[i].amount > 0
                                  ? '${rows[i].who} · ${fmtMoney(rows[i].amount)}'
                                  : rows[i].who,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 10.5,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.primary,
                        size: 20,
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
        _TopBar(
          cfg: cfg,
          hello: tr(context, 'greet_audit'),
          sub: tr(context, 'scope_audit'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchPill(
                onTap: () =>
                    _snack(context, '🔎 ${tr(context, 'search_hint')}'),
              ),
              const SizedBox(height: 12),
              _DashHeader(
                eyebrow: tr(context, 'audit_eyebrow'),
                title: tr(context, 'greet_audit'),
                sub: tr(context, 'audit_sub'),
                reportLabel: tr(context, 'btn_audit_report'),
                newLabel: tr(context, 'btn_new_case'),
                accent: accent,
                onReport: () => Navigator.of(context).push(
                  sfPageRoute(ReportScreen(colors: c, role: SfRole.audit)),
                ),
                onNew: () => _showCreateSheet(
                  context,
                  SettingsScope.of(context),
                  'create_case',
                ),
              ),
              const SizedBox(height: 14),
              _kpiGrid([
                _Kpi(
                  label: tr(context, 'kpi_open_flags'),
                  value: '12',
                  color: c.danger,
                  icon: Icons.flag_rounded,
                  trend: (up: false, v: '3'),
                  sub: '3 ta yuqori',
                  onTap: () => go('anomalies'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_active_cases'),
                  value: '8',
                  color: accent,
                  icon: Icons.push_pin_rounded,
                  sub: '2 ta jiddiy',
                  onTap: () => go('cases'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_anom_score'),
                  value: '2.4%',
                  color: c.warn,
                  sub: 'tranzaksiyalar',
                  onTap: () => go('anomalies'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_compliance'),
                  value: '96.8%',
                  color: c.success,
                  icon: Icons.shield_rounded,
                  trend: (up: true, v: '1.2%'),
                ),
                _Kpi(
                  label: tr(context, 'kpi_checked'),
                  value: '1 842',
                  sub: "o'quvchi yozuvi",
                  onTap: () => go('anomalies'),
                ),
              ]),
              const SizedBox(height: 12),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader(
                      tr(context, 'card_anom_signals'),
                      link: tr(context, 'link_all'),
                      onTap: () => go('anomalies'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: AreaChart(
                        color: c.danger,
                        height: 120,
                        data: const [
                          4,
                          6,
                          3,
                          8,
                          5,
                          12,
                          7,
                          9,
                          6,
                          11,
                          8,
                          12,
                        ].map((e) => e.toDouble()).toList(),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        children: [
                          _footStat(
                            context,
                            'Davomat anomaliyasi',
                            '5',
                            c.danger,
                          ),
                          _footStat(
                            context,
                            'Karta nomutanosib.',
                            '5',
                            c.warn,
                            border: true,
                          ),
                          _footStat(context, 'Moliya', '2', c.danger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SfAiCard(
                badge: 'Audit AI',
                quote:
                    'Sebzorda 3 ta yuqori signal: 100% davomat, kvitansiyasiz naqd, karta nomutanosibligi.',
                onTap: () => go('anomalies'),
              ),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader(
                      tr(context, 'card_recent_flags'),
                      link: tr(context, 'link_all'),
                      onTap: () => go('anomalies'),
                    ),
                    for (final f in const [
                      ['Davomat 100% · 21 kun', 'Sebzor', 'high'],
                      ['48 Up karta/hafta', 'Mirobod', 'med'],
                      ['Naqd · kvitansiyasiz', 'Sebzor', 'high'],
                    ])
                      _FlagRow(
                        title: f[0],
                        branch: f[1],
                        sev: f[2],
                        last:
                            f ==
                            const ['Naqd · kvitansiyasiz', 'Sebzor', 'high'],
                        onTap: () => go('anomalies'),
                      ),
                  ],
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader(
                      tr(context, 'card_branch_compliance'),
                      link: tr(context, 'link_all'),
                      onTap: () => go('cases'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: HBars(
                        rows: [
                          HBarRow(
                            'Yunusobod',
                            98,
                            '98%',
                            c.success,
                            onTap: () => go('cases'),
                          ),
                          HBarRow(
                            'Chilonzor',
                            97,
                            '97%',
                            c.success,
                            onTap: () => go('cases'),
                          ),
                          HBarRow(
                            'Mirobod',
                            95,
                            '95%',
                            c.warn,
                            onTap: () => go('cases'),
                          ),
                          HBarRow(
                            'Sebzor',
                            89,
                            '89%',
                            c.danger,
                            onTap: () => go('cases'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SfCard(
                child: Column(
                  children: [
                    SfCardHeader(tr(context, 'card_case_status')),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Row(
                        children: [
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
                                Text(
                                  tr(context, 'unit_total'),
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                LegendRow(
                                  c.danger,
                                  tr(context, 'legend_open_serious'),
                                  '3',
                                ),
                                LegendRow(
                                  c.warn,
                                  tr(context, 'legend_reviewing'),
                                  '5',
                                ),
                                LegendRow(
                                  c.success,
                                  tr(context, 'legend_closed'),
                                  '14',
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
          ),
        ),
      ],
    );
  }
}

/// A small label + coloured value cell used in dashboard chart footers.
Widget _footStat(
  BuildContext context,
  String label,
  String value,
  Color valueColor, {
  bool border = false,
}) {
  final c = SfTheme.of(context);
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.symmetric(
          vertical: border ? BorderSide(color: c.border) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FlagRow extends StatelessWidget {
  final String title, branch, sev;
  final bool last;
  final VoidCallback? onTap;
  const _FlagRow({
    required this.title,
    required this.branch,
    required this.sev,
    required this.last,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final high = sev == 'high';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: high ? c.danger : c.warn,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    branch,
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
              high ? 'Yuqori' : "O'rta",
              tone: high ? PillTone.danger : PillTone.warn,
            ),
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
  'left': (PillTone.neutral, 'Ketgan'),
};

String studentTeacher(Student student) {
  final group = student.group.toLowerCase();
  if (group.contains('ingliz') || group.contains('ielts')) {
    return 'Aziz Tursunov';
  }
  if (group.contains('fizika')) {
    return 'Shahzod Alimuhamedov';
  }
  return 'Nigora Karimova';
}

double studentRating(Student student) {
  final debtPenalty = student.debt > 0 ? .18 : 0.0;
  return (3.9 + student.attendance / 100 - debtPenalty)
      .clamp(3.5, 5.0)
      .toDouble();
}

int studentAverageScore(Student student) =>
    (student.attendance - (student.debt > 0 ? 5 : 1)).clamp(50, 100);

/// Maps "days since last parent call" to a tone + label key. Green ≤3 days,
/// amber ≤14, red beyond — the recency-of-contact signal the founder wants
/// front-and-centre on every student.
({PillTone tone, String key}) _callTone(int days) {
  if (days <= 3) return (tone: PillTone.success, key: 'call_recent');
  if (days <= 14) return (tone: PillTone.warn, key: 'call_mid');
  return (tone: PillTone.danger, key: 'call_old');
}

/// Human "3 kun oldin" / "bugun" label for a last-call day count.
String _callAgo(BuildContext context, int days) => days <= 0
    ? tr(context, 'call_never_d')
    : '$days ${tr(context, 'call_days_ago')}';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen>
    with AutomaticKeepAliveClientMixin {
  String query = '';
  final TextEditingController _referenceSearch = TextEditingController();
  int statusSel = 0; // all / debtor / paid / partial / risk / exited
  int callSel = 0; // all / recent / mid / overdue
  int branchSel = 0;
  int levelSel = 0;
  bool showFilters = false;

  bool _statusOk(Student s) => switch (statusSel) {
    1 => s.debt > 0,
    2 => s.pay == 'paid',
    3 => s.pay == 'partial',
    4 => s.attendance < 85 || s.debt >= 1000000,
    5 => s.pay == 'left',
    _ => true,
  };

  bool _callOk(Student s) {
    if (callSel == 0) return true;
    final d = studentCallDays(s);
    return switch (callSel) {
      1 => d <= 3,
      2 => d > 3 && d <= 14,
      3 => d > 14,
      _ => true,
    };
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _ReferenceStudentsPage(state: this);
  }

  /// Retained temporarily as an implementation reference while the route uses
  /// the new component composition above. It no longer contributes widgets to
  /// the rendered screen.
  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    super.build(context);
    final c = SfTheme.of(context);
    final all = [...AppScope.of(context).students, ...kExitedStudents];
    final branches = <String>[
      '__all',
      ...{for (final s in all) studentProfile(s).branch},
    ];
    final levels = <String>[
      '__all',
      ...{for (final s in all) studentProfile(s).level},
    ];
    if (branchSel >= branches.length) branchSel = 0;
    if (levelSel >= levels.length) levelSel = 0;
    final wantBranch = branches[branchSel];
    final wantLevel = levels[levelSel];
    final q = query.trim().toLowerCase();

    final list = all.where((s) {
      if (!_statusOk(s) || !_callOk(s)) return false;
      final p = studentProfile(s);
      if (wantBranch != '__all' && p.branch != wantBranch) return false;
      if (wantLevel != '__all' && p.level != wantLevel) return false;
      final searchable = [
        s.name,
        p.firstName,
        p.lastName,
        p.phone,
        s.phone ?? '',
        s.backupPhone ?? '',
        p.branch,
        s.branch ?? '',
        s.group,
        studentTeacher(s),
        p.level,
        p.studentId,
        s.studentNumber ?? '',
        s.username ?? '',
      ];
      if (q.isNotEmpty &&
          !searchable.any((value) => value.toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();

    final statusF = [
      tr(context, 'f_all'),
      tr(context, 'f_debtor'),
      tr(context, 'f_paid'),
      tr(context, 'f_partial'),
      tr(context, 'f_risky'),
      'Ketganlar',
    ];
    final callF = [
      tr(context, 'f_all'),
      tr(context, 'call_recent'),
      tr(context, 'call_mid'),
      tr(context, 'call_old'),
    ];
    final branchF = [
      for (final b in branches)
        b == '__all' ? tr(context, 'f_all_branches') : b,
    ];
    final levelF = [
      for (final l in levels) l == '__all' ? tr(context, 'f_all_levels') : l,
    ];
    final activeCount =
        (statusSel != 0 ? 1 : 0) +
        (callSel != 0 ? 1 : 0) +
        (branchSel != 0 ? 1 : 0) +
        (levelSel != 0 ? 1 : 0);

    // A floating SliverAppBar gives search the familiar Telegram/WhatsApp
    // behaviour: it leaves while the roster is read and returns immediately
    // when the user reverses direction. The roster itself is a lazy
    // SliverList, so adding a large student base does not build every card.
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: SfHead(
            eyebrow: "${list.length} ${tr(context, 'unit_student')}",
            title: tr(context, 'students_title'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          sliver: SliverToBoxAdapter(
            child: _CeoContextFilter(showBranches: false),
          ),
        ),
        SliverAppBar(
          floating: true,
          // Let the floating bar follow the scroll position rather than snap
          // into view.  This produces the quiet, continuous return motion
          // used by the reference workspace when the user reverses direction.
          snap: false,
          pinned: false,
          toolbarHeight: 62,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            children: [
              Expanded(
                child: _SearchField(
                  hint: tr(context, 'students_search'),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 8),
              _FilterToggle(
                active: showFilters,
                count: activeCount,
                onTap: () => setState(() => showFilters = !showFilters),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'O‘quvchi qabul qilish',
                onTap: () => Navigator.of(context).push(
                  sfPageRoute(AdmitStudentScreen(colors: SfTheme.of(context))),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: _pad,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  reverseDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.045),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                  ),
                  child: showFilters
                      ? Padding(
                          key: const ValueKey('student-filters-visible'),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _StudentFiltersPanel(
                            activeCount: activeCount,
                            groups: [
                              _StudentFilterGroup(
                                label: tr(context, 'filter_status'),
                                items: statusF,
                                selected: statusSel,
                                onSelect: (i) => setState(() => statusSel = i),
                              ),
                              _StudentFilterGroup(
                                label: tr(context, 'filter_call'),
                                items: callF,
                                selected: callSel,
                                onSelect: (i) => setState(() => callSel = i),
                              ),
                              _StudentFilterGroup(
                                label: tr(context, 'filter_branch'),
                                items: branchF,
                                selected: branchSel,
                                onSelect: (i) => setState(() => branchSel = i),
                              ),
                              _StudentFilterGroup(
                                label: tr(context, 'filter_level'),
                                items: levelF,
                                selected: levelSel,
                                onSelect: (i) => setState(() => levelSel = i),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('student-filters-hidden')),
                ),
                _StudentLifecycleCard(
                  students: all,
                  onOpen: (category, title) => Navigator.of(context).push(
                    sfPageRoute(
                      StudentCategoryScreen(
                        title: title,
                        category: category,
                        students: _studentsForFlow(all, category),
                        colors: SfTheme.of(context),
                      ),
                    ),
                  ),
                ),
                if (list.isEmpty) ...[
                  const SizedBox(height: 2),
                  _EmptyState(
                    icon: Icons.groups_rounded,
                    title: query.trim().isEmpty
                        ? 'Mos keladigan o‘quvchi yo‘q'
                        : 'Hech narsa topilmadi',
                    sub: query.trim().isEmpty
                        ? 'Boshqa filtrni tanlang.'
                        : 'So‘rovni o‘zgartirib ko‘ring.',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (list.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: list.length,
              itemBuilder: (context, index) => RepaintBoundary(
                child: SfCard(
                  margin: EdgeInsets.zero,
                  child: _StudentRow(s: list[index], last: true),
                ),
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _referenceSearch.dispose();
    super.dispose();
  }
}

/// New student workspace composition, adapted from the reference project's
/// cohort list, staff metric grid and segmented filter controls.  It consumes
/// the existing state object above, so filtering and navigation stay intact.
class _ReferenceStudentsPage extends StatelessWidget {
  const _ReferenceStudentsPage({required this.state});

  final _StudentsScreenState state;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final all = [...AppScope.of(context).students, ...kExitedStudents];
    final branches = <String>[
      '__all',
      ...{for (final student in all) studentProfile(student).branch},
    ];
    final levels = <String>[
      '__all',
      ...{for (final student in all) studentProfile(student).level},
    ];
    if (state.branchSel >= branches.length) state.branchSel = 0;
    if (state.levelSel >= levels.length) state.levelSel = 0;
    final wantedBranch = branches[state.branchSel];
    final wantedLevel = levels[state.levelSel];
    final query = state.query.trim().toLowerCase();
    final students = all.where((student) {
      if (!state._statusOk(student) || !state._callOk(student)) return false;
      final profile = studentProfile(student);
      if (wantedBranch != '__all' && profile.branch != wantedBranch)
        return false;
      if (wantedLevel != '__all' && profile.level != wantedLevel) return false;
      if (query.isEmpty) return true;
      return [
        student.name,
        profile.firstName,
        profile.lastName,
        profile.phone,
        student.phone ?? '',
        student.backupPhone ?? '',
        profile.branch,
        student.branch ?? '',
        student.group,
        studentTeacher(student),
        profile.level,
        profile.studentId,
        student.studentNumber ?? '',
        student.username ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    final statusLabels = [
      tr(context, 'f_all'),
      tr(context, 'f_debtor'),
      tr(context, 'f_paid'),
      tr(context, 'f_partial'),
      tr(context, 'f_risky'),
      'Ketganlar',
    ];
    final callLabels = [
      tr(context, 'f_all'),
      tr(context, 'call_recent'),
      tr(context, 'call_mid'),
      tr(context, 'call_old'),
    ];
    final branchLabels = [
      for (final branch in branches)
        branch == '__all' ? tr(context, 'f_all_branches') : branch,
    ];
    final levelLabels = [
      for (final level in levels)
        level == '__all' ? tr(context, 'f_all_levels') : level,
    ];
    final activeCount =
        (state.statusSel != 0 ? 1 : 0) +
        (state.callSel != 0 ? 1 : 0) +
        (state.branchSel != 0 ? 1 : 0) +
        (state.levelSel != 0 ? 1 : 0);
    final filters = [
      _StudentFilterGroup(
        label: tr(context, 'filter_status'),
        items: statusLabels,
        selected: state.statusSel,
        onSelect: (value) => state._update(() => state.statusSel = value),
      ),
      _StudentFilterGroup(
        label: tr(context, 'filter_call'),
        items: callLabels,
        selected: state.callSel,
        onSelect: (value) => state._update(() => state.callSel = value),
      ),
      _StudentFilterGroup(
        label: tr(context, 'filter_branch'),
        items: branchLabels,
        selected: state.branchSel,
        onSelect: (value) => state._update(() => state.branchSel = value),
      ),
      _StudentFilterGroup(
        label: tr(context, 'filter_level'),
        items: levelLabels,
        selected: state.levelSel,
        onSelect: (value) => state._update(() => state.levelSel = value),
      ),
    ];
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: RefLargeHeader(
            eyebrow: '${students.length} ${tr(context, 'unit_student')}',
            title: tr(context, 'students_title'),
            subtitle: 'O‘quvchi profillari, aloqa va holat nazorati',
            actions: [
              RefIconAction(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'O‘quvchi qabul qilish',
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(AdmitStudentScreen(colors: c))),
              ),
            ],
          ),
        ),
        SliverAppBar(
          floating: true,
          snap: false,
          pinned: false,
          toolbarHeight: 72,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            children: [
              Expanded(
                child: RefSearchField(
                  controller: state._referenceSearch,
                  hint: tr(context, 'students_search'),
                  onChanged: (value) =>
                      state._update(() => state.query = value),
                  suffix: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Tozalash',
                          onPressed: () => state._update(() {
                            state._referenceSearch.clear();
                            state.query = '';
                          }),
                          icon: Icon(Icons.close_rounded, color: c.muted),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              _ReferenceFilterToggle(
                active: state.showFilters,
                count: activeCount,
                onTap: () =>
                    state._update(() => state.showFilters = !state.showFilters),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          sliver: SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: RefMotion.resolve(context, RefMotion.standard),
              reverseDuration: RefMotion.resolve(context, RefMotion.quick),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -.045),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              ),
              child: state.showFilters
                  ? _ReferenceStudentFilters(
                      key: const ValueKey('reference-student-filters-open'),
                      activeCount: activeCount,
                      groups: filters,
                    )
                  : const SizedBox(
                      key: ValueKey('reference-student-filters-closed'),
                    ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          sliver: SliverToBoxAdapter(
            child: _ReferenceStudentFlow(
              students: all,
              onOpen: (category, title) => Navigator.of(context).push(
                sfPageRoute(
                  StudentCategoryScreen(
                    title: title,
                    category: category,
                    students: _studentsForFlow(all, category),
                    colors: c,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (students.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ReferenceStudentEmpty(hasQuery: query.isNotEmpty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            sliver: SliverList.builder(
              itemCount: students.length * 2 - 1,
              itemBuilder: (context, index) {
                if (index.isOdd) return const SizedBox(height: 10);
                final student = students[index ~/ 2];
                return RepaintBoundary(
                  child: RefStaggeredReveal(
                    order: index ~/ 2,
                    child: _ReferenceStudentCard(student: student),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ReferenceFilterToggle extends StatelessWidget {
  const _ReferenceFilterToggle({
    required this.active,
    required this.count,
    required this.onTap,
  });

  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final selected = active || count > 0;
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.md,
      semanticLabel: count == 0 ? 'Filter' : '$count ta faol filter',
      child: AnimatedContainer(
        duration: RefMotion.resolve(context, RefMotion.quick),
        width: count > 0 ? 62 : 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.surface2,
          borderRadius: RefRadius.md,
          border: Border.all(color: selected ? c.ink : c.border),
          boxShadow: selected ? RefShadows.soft : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 18, color: selected ? c.bg : c.ink2),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: RefType.mono(
                  size: 12,
                  weight: FontWeight.w800,
                  color: c.bg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferenceStudentFilters extends StatelessWidget {
  const _ReferenceStudentFilters({
    super.key,
    required this.activeCount,
    required this.groups,
  });

  final int activeCount;
  final List<_StudentFilterGroup> groups;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
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
                  color: c.primarySoft,
                  borderRadius: RefRadius.sm,
                ),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.tune_rounded, size: 18, color: c.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Filterlar',
                  style: RefType.ui(
                    size: 14,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              if (activeCount > 0)
                RefPill(label: '$activeCount faol', tone: RefPillTone.primary),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 620;
              final width = twoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final group in groups)
                    SizedBox(
                      width: width,
                      child: _ReferenceFilterGroup(group: group),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReferenceFilterGroup extends StatelessWidget {
  const _ReferenceFilterGroup({required this.group});

  final _StudentFilterGroup group;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: RefRadius.md,
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.label.toUpperCase(),
              style: RefType.eyebrow(color: c.muted, size: 9.5),
            ),
            const SizedBox(height: 7),
            RefSegmentedControl<int>(
              values: List<int>.generate(group.items.length, (index) => index),
              selected: group.selected,
              labelOf: (index) => group.items[index],
              onChanged: group.onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceStudentFlow extends StatelessWidget {
  const _ReferenceStudentFlow({required this.students, required this.onOpen});

  final List<Student> students;
  final void Function(StudentFlowCategory category, String title) onOpen;

  @override
  Widget build(BuildContext context) {
    final categories = <(String, StudentFlowCategory, IconData, RefMetricTone)>[
      (
        'New',
        StudentFlowCategory.newlyAdmitted,
        Icons.fiber_new_rounded,
        RefMetricTone.primary,
      ),
      (
        'Active',
        StudentFlowCategory.active,
        Icons.groups_2_rounded,
        RefMetricTone.success,
      ),
      (
        'Left',
        StudentFlowCategory.left,
        Icons.person_off_rounded,
        RefMetricTone.danger,
      ),
      (
        'Graduated',
        StudentFlowCategory.graduated,
        Icons.workspace_premium_rounded,
        RefMetricTone.accent,
      ),
      (
        'In Risk',
        StudentFlowCategory.risk,
        Icons.warning_amber_rounded,
        RefMetricTone.warning,
      ),
      (
        'In Debt',
        StudentFlowCategory.debt,
        Icons.account_balance_wallet_outlined,
        RefMetricTone.danger,
      ),
    ];
    return RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RefSectionHeader(
            title: 'Student Flow · period',
            subtitle: 'O‘quvchi holati · joriy davr',
            trailing: const RefPill(label: 'Bugun', tone: RefPillTone.primary),
          ),
          const SizedBox(height: 12),
          RefAdaptiveGrid(
            minCellWidth: 142,
            children: [
              for (final item in categories)
                RefMetricCard(
                  key: ValueKey('student-flow-${item.$2.name}'),
                  label: item.$1,
                  value: '${_studentsForFlow(students, item.$2).length}',
                  icon: item.$3,
                  tone: item.$4,
                  uppercaseLabel: false,
                  onTap: () => onOpen(item.$2, item.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferenceStudentEmpty extends StatelessWidget {
  const _ReferenceStudentEmpty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface2,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 66,
                height: 66,
                child: Icon(Icons.search_rounded, color: c.muted, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'Hech narsa topilmadi' : 'Mos keladigan o‘quvchi yo‘q',
              style: RefType.ui(
                size: 17,
                weight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'So‘rov yoki filtrlarni o‘zgartirib ko‘ring.',
              textAlign: TextAlign.center,
              style: RefType.ui(size: 12.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceStudentCard extends StatelessWidget {
  const _ReferenceStudentCard({required this.student});

  final Student student;

  RefPillTone _paymentTone(PillTone tone) => switch (tone) {
    PillTone.success => RefPillTone.success,
    PillTone.danger => RefPillTone.danger,
    PillTone.warn => RefPillTone.warning,
    PillTone.primary => RefPillTone.primary,
    PillTone.accent => RefPillTone.accent,
    PillTone.neutral => RefPillTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final profile = studentProfile(student);
    final attendanceColor = student.attendance >= 92
        ? c.success
        : student.attendance >= 85
        ? c.warn
        : c.danger;
    final call = _callTone(studentCallDays(student));
    final payment = _studentTones[student.pay]!;
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(StudentDetailScreen(student: student, colors: c))),
      borderRadius: RefRadius.lg,
      semanticLabel: 'O‘quvchi ${student.name}',
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SfAvatar(name: student.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 15,
                          weight: FontWeight.w800,
                          color: c.ink,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.branch} · ${student.group}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 11, color: c.muted),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          RefPill(
                            label: student.pay == 'left'
                                ? 'Ketgan'
                                : payment.$2,
                            tone: student.pay == 'left'
                                ? RefPillTone.neutral
                                : _paymentTone(payment.$1),
                          ),
                          RefPill(
                            label: profile.level,
                            tone: RefPillTone.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: attendanceColor.withValues(alpha: .11),
                    borderRadius: RefRadius.md,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${student.attendance}%',
                          style: RefType.mono(
                            size: 14,
                            weight: FontWeight.w800,
                            color: attendanceColor,
                          ),
                        ),
                        Text(
                          'DAVOMAT',
                          style: RefType.eyebrow(color: c.muted, size: 7.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: RefRadius.md,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      size: 15,
                      color: call.tone == PillTone.success
                          ? c.success
                          : call.tone == PillTone.warn
                          ? c.warn
                          : c.danger,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        student.pay == 'left'
                            ? studentExitReason(student)
                            : '${tr(context, call.key)} · ${_callAgo(context, studentCallDays(student))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.ink2,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
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

/// Filter button with an active-count badge (used beside the search box).
class _FilterToggle extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _FilterToggle({
    required this.active,
    required this.count,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final on = active || count > 0;
    return Semantics(
      button: true,
      label: count == 0 ? 'Filter' : '$count ta faol filter',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? c.ink : c.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? Colors.transparent : c.border),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.13),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: on ? c.bg : c.muted),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.bg,
                    ),
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

/// The four existing filters are presented as one compact control surface.
/// Its layout is responsive, while every option continues to call the same
/// selection callbacks that the former loose chip rows used.
class _StudentFilterGroup {
  final String label;
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const _StudentFilterGroup({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
}

class _StudentFiltersPanel extends StatelessWidget {
  final int activeCount;
  final List<_StudentFilterGroup> groups;
  const _StudentFiltersPanel({required this.activeCount, required this.groups});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SfCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.tune_rounded, size: 17, color: c.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Filterlar',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      color: c.ink,
                    ),
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$activeCount faol',
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.bg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 84,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) =>
                      _StudentFilterTile(group: groups[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentFilterTile extends StatelessWidget {
  final _StudentFilterGroup group;
  const _StudentFilterTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
      decoration: BoxDecoration(
        color: c.surface2.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label.toUpperCase(),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _FilterChips(
              items: group.items,
              selected: group.selected,
              onSelect: group.onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

/// Student Flow is an inbox, not a decorative counter. Only tapping the large
/// number opens a dedicated, drill-down list; choosing a row there opens the
/// student's complete profile.
enum StudentFlowCategory { newlyAdmitted, active, left, graduated, risk, debt }

List<Student> _studentsForFlow(
  List<Student> all,
  StudentFlowCategory category,
) {
  final active = all.where((student) => student.pay != 'left').toList();
  return switch (category) {
    StudentFlowCategory.newlyAdmitted => active.take(3).toList(),
    StudentFlowCategory.active => active,
    StudentFlowCategory.left =>
      all.where((student) => student.pay == 'left').toList(),
    StudentFlowCategory.graduated =>
      active
          .where((student) => student.attendance >= 95 && student.debt == 0)
          .toList(),
    StudentFlowCategory.risk =>
      active
          .where(
            (student) => student.attendance < 85 || student.debt >= 1000000,
          )
          .toList(),
    StudentFlowCategory.debt =>
      active.where((student) => student.debt > 0).toList(),
  };
}

class _StudentLifecycleCard extends StatelessWidget {
  final List<Student> students;
  final void Function(StudentFlowCategory category, String title) onOpen;
  const _StudentLifecycleCard({required this.students, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final categories = <(String, StudentFlowCategory, Color)>[
      ('New', StudentFlowCategory.newlyAdmitted, c.primary),
      ('Active', StudentFlowCategory.active, c.success),
      ('Left', StudentFlowCategory.left, c.danger),
      ('Graduated', StudentFlowCategory.graduated, c.accent),
      ('In Risk', StudentFlowCategory.risk, c.warn),
      ('In Debt', StudentFlowCategory.debt, c.danger),
    ];
    return SfCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.primarySoft, c.surface],
              ),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.groups_2_rounded,
                    size: 20,
                    color: c.surface,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Flow · period',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'O‘quvchilar holati',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    'Bugun',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.primaryInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 82,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final item = categories[index];
                final count = _studentsForFlow(students, item.$2).length;
                return _StudentFlowMetric(
                  label: item.$1,
                  value: '$count',
                  color: item.$3,
                  category: item.$2,
                  onTap: () => onOpen(item.$2, item.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFlowMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final StudentFlowCategory category;
  final VoidCallback onTap;
  const _StudentFlowMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: ValueKey('student-flow-${category.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.105),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: 0.19)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final profile = studentProfile(s);
    final aColor = s.attendance >= 92
        ? c.success
        : s.attendance >= 85
        ? c.warn
        : c.danger;
    final days = studentCallDays(s);
    final call = _callTone(days);
    final payment = _studentTones[s.pay]!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(StudentDetailScreen(student: s, colors: c))),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: last ? BorderSide.none : BorderSide(color: c.border),
            ),
          ),
          child: Row(
            children: [
              SfAvatar(name: s.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.18,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.branch} • ${s.group}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Pill(
                          s.pay == 'left' ? 'Ketgan' : payment.$2,
                          tone: s.pay == 'left' ? PillTone.neutral : payment.$1,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_in_talk_rounded,
                                size: 12,
                                color: call.tone == PillTone.success
                                    ? c.success
                                    : call.tone == PillTone.warn
                                    ? c.warn
                                    : c.danger,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.pay == 'left'
                                      ? studentExitReason(s)
                                      : '${tr(context, call.key)} · ${_callAgo(context, days)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: c.muted,
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
              const SizedBox(width: 10),
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: aColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aColor.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    Text(
                      'DAVOMAT',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.attendance}%',
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: aColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) =>
      _ReferenceStudentDetailPage(student: student, colors: colors);

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = colors;
    final s = student;
    final p = studentProfile(s);
    final username =
        s.username ??
        '@${p.firstName.toLowerCase()}.${p.lastName.toLowerCase()}';
    final aColor = s.attendance >= 92
        ? c.success
        : s.attendance >= 85
        ? c.warn
        : c.danger;
    final t = _studentTones[s.pay]!;
    final callDays = studentCallDays(s);
    final call = _callTone(callDays);
    final callColor = call.tone == PillTone.success
        ? c.success
        : call.tone == PillTone.warn
        ? c.warn
        : c.danger;
    // Synthesise an 8-week attendance trend ending near the current value.
    final base = s.attendance.toDouble();
    final spark = <double>[
      base - 7,
      base - 3,
      base - 5,
      base - 1,
      base - 3,
      base + 1,
      base - 2,
      base,
    ].map((v) => v.clamp(40.0, 100.0)).toList();
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
            tr(context, 'tab_students'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SfSurfaceCard(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.primarySoft, c.surface],
                  ),
                ),
                child: Row(
                  children: [
                    SfAvatar(name: s.name, size: 62),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.group,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Pill(t.$2, tone: t.$1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (s.pay == 'left') ...[
              SfSurfaceCard(
                color: c.dangerSoft,
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_off_rounded, size: 19, color: c.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ta’limdan chiqish sababi',
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: c.danger,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            studentExitReason(s),
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 11.5,
                              color: c.ink2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ketgan sana · ${studentExitDate(s)}',
                            style: TextStyle(
                              fontFamily: SfType.mono,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: c.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Call-status banner — green/amber/red by how long since the last
            // parent call. Tapping places a (demo) call to the father.
            SfSurfaceCard(
              color: callColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: callColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.call_rounded, size: 17, color: callColor),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, call.key),
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: callColor,
                          ),
                        ),
                        Text(
                          '${tr(context, 'call_last')} · ${_callAgo(context, callDays)}',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10.5,
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
            Row(
              children: [
                Expanded(
                  child: _DetailStat(
                    tr(context, 'stat_attendance'),
                    '${s.attendance}%',
                    aColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DetailStat(
                    tr(context, 'stat_debt'),
                    s.debt > 0 ? fmtMoneyShort(s.debt) : '0',
                    s.debt > 0 ? c.danger : c.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'stu_trend').toUpperCase(),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Sparkline(data: spark, color: aColor, height: 46),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Personal info
            _setSec(c, tr(context, 'stu_personal')),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(tr(context, 'stu_fname'), p.firstName),
                  _InfoRow(tr(context, 'stu_lname'), p.lastName),
                  _InfoRow('Username', username),
                  _InfoRow(
                    tr(context, 'stu_age'),
                    '${p.age} ${tr(context, 'stu_years')}',
                  ),
                  _InfoRow(tr(context, 'stu_level'), p.level),
                  _InfoRow(tr(context, 'stu_id'), p.studentId, mono: true),
                  _InfoRow(tr(context, 'stu_group'), s.group),
                  _InfoRow(tr(context, 'stu_branch'), p.branch),
                  _InfoRow(
                    tr(context, 'stu_enrolled'),
                    p.enrolled,
                    mono: true,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Contacts & parents
            _setSec(c, tr(context, 'stu_contacts')),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(
                    tr(context, 'stu_phone'),
                    p.phone,
                    mono: true,
                    onTap: () => _launchPhoneCall(context, p.phone),
                  ),
                  _InfoRow(
                    '${tr(context, 'stu_father')} · ${p.fatherName}',
                    p.fatherPhone,
                    mono: true,
                    onTap: () => _launchPhoneCall(context, p.fatherPhone),
                  ),
                  _InfoRow(
                    '${tr(context, 'stu_mother')} · ${p.motherName}',
                    p.motherPhone,
                    mono: true,
                    last: true,
                    onTap: () => _launchPhoneCall(context, p.motherPhone),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'TA’LIM TARIXI'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Qabul qilingan', p.enrolled, mono: true),
                  _InfoRow('Filial', p.branch),
                  _InfoRow('Guruh', s.group),
                  _InfoRow(
                    s.pay == 'left' ? 'Ketgan sana' : 'Joriy holat',
                    s.pay == 'left' ? studentExitDate(s) : 'Faol o‘qiyapti',
                    mono: s.pay == 'left',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'NATIJALAR VA O‘QISH'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('O‘qituvchi', studentTeacher(s)),
                  _InfoRow(
                    'Reyting',
                    '★ ${studentRating(s).toStringAsFixed(1)} / 5.0',
                  ),
                  _InfoRow('O‘rtacha baho', '${studentAverageScore(s)}%'),
                  _InfoRow('Uy vazifalari', '18 / 20 topshirilgan'),
                  _InfoRow(
                    'Imtihonlar',
                    '3 ta · oxirgisi ${studentAverageScore(s)}%',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'DAVOMAT TARIXI'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(
                    'Bugun',
                    s.attendance >= 85 ? 'Qatnashdi' : 'Kechikdi',
                  ),
                  _InfoRow('Kecha', 'Qatnashdi'),
                  _InfoRow(
                    'Oxirgi 30 kun',
                    '${s.attendance}% · ${s.attendance >= 90 ? 'barqaror' : 'e’tibor kerak'}',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'TO‘LOVLAR TARIXI'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(
                    'Iyul 2026',
                    s.debt > 0
                        ? 'Kutilmoqda · ${fmtMoney(s.debt)}'
                        : 'To‘langan',
                    mono: s.debt > 0,
                  ),
                  _InfoRow('Iyun 2026', 'To‘langan · 600 000 so‘m'),
                  _InfoRow('May 2026', 'To‘langan · 600 000 so‘m', last: true),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'O‘QITUVCHI IZOHlari'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(
                    'Bugun',
                    'Darsda faol, uy vazifasini vaqtida topshirdi.',
                  ),
                  _InfoRow(
                    '08.07.2026',
                    'Keyingi mavzu bo‘yicha qo‘shimcha mashq tavsiya qilindi.',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, 'SO‘NGGI XABARLAR'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Ota-ona', 'Rahmat, uy vazifasini nazorat qilamiz.'),
                  _InfoRow(
                    'Administrator',
                    'Keyingi to‘lov muddati 20-iyul.',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SheetAction(
                    icon: Icons.call_rounded,
                    label: tr(context, 'stu_call'),
                    primary: true,
                    onTap: () => _launchPhoneCall(context, p.fatherPhone),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetAction(
                    icon: Icons.notifications_active_rounded,
                    label: s.debt > 0
                        ? tr(context, 'stu_remind')
                        : tr(context, 'stu_message'),
                    primary: false,
                    onTap: () => _snack(
                      context,
                      s.debt > 0
                          ? '🔔 To‘lov eslatmasi yuborildi (demo)'
                          : '✉️ Xabar yuborildi (demo)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Personal cabinet → direct message (Discord-style DM with the family).
            SfButton(
              icon: Icons.forum_rounded,
              label: tr(context, 'stu_cabinet'),
              primary: true,
              onTap: () => Navigator.of(context).push(
                sfPageRoute(
                  SfTheme(
                    colors: c,
                    child: StudentChatScreen(student: s, colors: c),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full student detail composition adapted from the reference student profile:
/// an editorial hero, metric grid, quick actions and sectioned surface cards.
/// The data and all previous actions are passed through unchanged.
class _ReferenceStudentDetailPage extends StatelessWidget {
  const _ReferenceStudentDetailPage({
    required this.student,
    required this.colors,
  });

  final Student student;
  final SfColors colors;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final p = studentProfile(s);
    final username =
        s.username ??
        '@${p.firstName.toLowerCase()}.${p.lastName.toLowerCase()}';
    final attendanceColor = s.attendance >= 92
        ? colors.success
        : s.attendance >= 85
        ? colors.warn
        : colors.danger;
    final callDays = studentCallDays(s);
    final call = _callTone(callDays);
    final callColor = call.tone == PillTone.success
        ? colors.success
        : call.tone == PillTone.warn
        ? colors.warn
        : colors.danger;
    final payment = _studentTones[s.pay]!;
    final trend = <double>[
      s.attendance.toDouble() - 7,
      s.attendance.toDouble() - 3,
      s.attendance.toDouble() - 5,
      s.attendance.toDouble() - 1,
      s.attendance.toDouble() - 3,
      s.attendance.toDouble() + 1,
      s.attendance.toDouble() - 2,
      s.attendance.toDouble(),
    ].map((value) => value.clamp(40, 100).toDouble()).toList();
    return SfTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Column(
          children: [
            RefNavHeader(
              title: s.name,
              subtitle: '${p.branch} · ${s.group}',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                RefIconAction(
                  icon: Icons.forum_outlined,
                  tooltip: tr(context, 'stu_cabinet'),
                  onPressed: () => Navigator.of(context).push(
                    sfPageRoute(
                      SfTheme(
                        colors: colors,
                        child: StudentChatScreen(student: s, colors: colors),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                children: [
                  RefSurfaceCard(
                    elevated: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.primarySoft, colors.surface],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SfAvatar(name: s.name, size: 64),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: RefType.ui(
                                          size: 20,
                                          weight: FontWeight.w800,
                                          color: colors.ink,
                                          letterSpacing: -.35,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        username,
                                        style: RefType.mono(
                                          size: 10.5,
                                          color: colors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          RefPill(
                                            label: s.group,
                                            tone: RefPillTone.primary,
                                          ),
                                          RefPill(
                                            label: p.level,
                                            tone: RefPillTone.accent,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                RefPill(
                                  label: s.pay == 'left'
                                      ? 'Ketgan'
                                      : payment.$2,
                                  tone: _referencePillTone(payment.$1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 17),
                            RefAdaptiveGrid(
                              minCellWidth: 118,
                              spacing: 8,
                              children: [
                                RefMetricCard(
                                  label: tr(context, 'stat_attendance'),
                                  value: '${s.attendance}%',
                                  icon: Icons.how_to_reg_rounded,
                                  tone: s.attendance >= 92
                                      ? RefMetricTone.success
                                      : s.attendance >= 85
                                      ? RefMetricTone.warning
                                      : RefMetricTone.danger,
                                ),
                                RefMetricCard(
                                  label: tr(context, 'stat_debt'),
                                  value: s.debt > 0
                                      ? fmtMoneyShort(s.debt)
                                      : '0',
                                  icon: Icons.account_balance_wallet_outlined,
                                  tone: s.debt > 0
                                      ? RefMetricTone.danger
                                      : RefMetricTone.success,
                                ),
                                RefMetricCard(
                                  label: 'Reyting',
                                  value: studentRating(s).toStringAsFixed(1),
                                  icon: Icons.star_rounded,
                                  tone: RefMetricTone.accent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RefAdaptiveGrid(
                    minCellWidth: 102,
                    spacing: 8,
                    children: [
                      _ReferenceQuickAction(
                        icon: Icons.call_rounded,
                        label: tr(context, 'stu_call'),
                        onTap: () => _launchPhoneCall(context, p.fatherPhone),
                      ),
                      _ReferenceQuickAction(
                        icon: Icons.notifications_active_rounded,
                        label: s.debt > 0
                            ? tr(context, 'stu_remind')
                            : tr(context, 'stu_message'),
                        onTap: () => _snack(
                          context,
                          s.debt > 0
                              ? '🔔 To‘lov eslatmasi yuborildi (demo)'
                              : '✉️ Xabar yuborildi (demo)',
                        ),
                      ),
                      _ReferenceQuickAction(
                        icon: Icons.forum_rounded,
                        label: tr(context, 'stu_cabinet'),
                        onTap: () => Navigator.of(context).push(
                          sfPageRoute(
                            SfTheme(
                              colors: colors,
                              child: StudentChatScreen(
                                student: s,
                                colors: colors,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (s.pay == 'left') ...[
                    RefStatusTile(
                      icon: Icons.person_off_rounded,
                      title: 'Ta’limdan chiqish sababi',
                      subtitle:
                          '${studentExitReason(s)} · ${studentExitDate(s)}',
                      tone: RefMetricTone.danger,
                    ),
                    const SizedBox(height: 10),
                  ],
                  RefStatusTile(
                    icon: Icons.phone_in_talk_rounded,
                    title: tr(context, call.key),
                    subtitle:
                        '${tr(context, 'call_last')} · ${_callAgo(context, callDays)}',
                    tone: callColor == colors.success
                        ? RefMetricTone.success
                        : callColor == colors.warn
                        ? RefMetricTone.warning
                        : RefMetricTone.danger,
                    onTap: () => _launchPhoneCall(context, p.fatherPhone),
                  ),
                  const SizedBox(height: 18),
                  RefSectionHeader(
                    title: tr(context, 'stu_trend'),
                    subtitle: 'Oxirgi 8 hafta',
                  ),
                  const SizedBox(height: 8),
                  RefSurfaceCard(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAVOMAT',
                          style: RefType.eyebrow(
                            color: colors.muted,
                            size: 9.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Sparkline(
                          data: trend,
                          color: attendanceColor,
                          height: 52,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: tr(context, 'stu_personal'),
                    rows: [
                      _ReferenceDataRow(tr(context, 'stu_fname'), p.firstName),
                      _ReferenceDataRow(tr(context, 'stu_lname'), p.lastName),
                      _ReferenceDataRow('Username', username, mono: true),
                      _ReferenceDataRow(
                        tr(context, 'stu_age'),
                        '${p.age} ${tr(context, 'stu_years')}',
                      ),
                      _ReferenceDataRow(tr(context, 'stu_level'), p.level),
                      _ReferenceDataRow(
                        tr(context, 'stu_id'),
                        p.studentId,
                        mono: true,
                      ),
                      _ReferenceDataRow(tr(context, 'stu_group'), s.group),
                      _ReferenceDataRow(tr(context, 'stu_branch'), p.branch),
                      _ReferenceDataRow(
                        tr(context, 'stu_enrolled'),
                        p.enrolled,
                        mono: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: tr(context, 'stu_contacts'),
                    rows: [
                      _ReferenceDataRow(
                        tr(context, 'stu_phone'),
                        p.phone,
                        mono: true,
                        onTap: () => _launchPhoneCall(context, p.phone),
                      ),
                      _ReferenceDataRow(
                        '${tr(context, 'stu_father')} · ${p.fatherName}',
                        p.fatherPhone,
                        mono: true,
                        onTap: () => _launchPhoneCall(context, p.fatherPhone),
                      ),
                      _ReferenceDataRow(
                        '${tr(context, 'stu_mother')} · ${p.motherName}',
                        p.motherPhone,
                        mono: true,
                        onTap: () => _launchPhoneCall(context, p.motherPhone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: 'NATIJALAR VA O‘QISH',
                    rows: [
                      _ReferenceDataRow('O‘qituvchi', studentTeacher(s)),
                      _ReferenceDataRow(
                        'Reyting',
                        '★ ${studentRating(s).toStringAsFixed(1)} / 5.0',
                      ),
                      _ReferenceDataRow(
                        'O‘rtacha baho',
                        '${studentAverageScore(s)}%',
                      ),
                      const _ReferenceDataRow(
                        'Uy vazifalari',
                        '18 / 20 topshirilgan',
                      ),
                      _ReferenceDataRow(
                        'Imtihonlar',
                        '3 ta · oxirgisi ${studentAverageScore(s)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: 'DAVOMAT TARIXI',
                    rows: [
                      _ReferenceDataRow(
                        'Bugun',
                        s.attendance >= 85 ? 'Qatnashdi' : 'Kechikdi',
                      ),
                      const _ReferenceDataRow('Kecha', 'Qatnashdi'),
                      _ReferenceDataRow(
                        'Oxirgi 30 kun',
                        '${s.attendance}% · ${s.attendance >= 90 ? 'barqaror' : 'e’tibor kerak'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: 'TO‘LOVLAR TARIXI',
                    rows: [
                      _ReferenceDataRow(
                        'Iyul 2026',
                        s.debt > 0
                            ? 'Kutilmoqda · ${fmtMoney(s.debt)}'
                            : 'To‘langan',
                        mono: s.debt > 0,
                      ),
                      const _ReferenceDataRow(
                        'Iyun 2026',
                        'To‘langan · 600 000 so‘m',
                      ),
                      const _ReferenceDataRow(
                        'May 2026',
                        'To‘langan · 600 000 so‘m',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: 'O‘QITUVCHI IZOHLARI',
                    rows: const [
                      _ReferenceDataRow(
                        'Bugun',
                        'Darsda faol, uy vazifasini vaqtida topshirdi.',
                      ),
                      _ReferenceDataRow(
                        '08.07.2026',
                        'Keyingi mavzu bo‘yicha qo‘shimcha mashq tavsiya qilindi.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ReferenceDetailSection(
                    title: 'SO‘NGGI XABARLAR',
                    rows: const [
                      _ReferenceDataRow(
                        'Ota-ona',
                        'Rahmat, uy vazifasini nazorat qilamiz.',
                      ),
                      _ReferenceDataRow(
                        'Administrator',
                        'Keyingi to‘lov muddati 20-iyul.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: RefButton(
                      label: tr(context, 'stu_call'),
                      leading: Icons.call_rounded,
                      onPressed: () => _launchPhoneCall(context, p.fatherPhone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RefButton(
                      label: tr(context, 'stu_cabinet'),
                      kind: RefButtonKind.soft,
                      leading: Icons.forum_rounded,
                      onPressed: () => Navigator.of(context).push(
                        sfPageRoute(
                          SfTheme(
                            colors: colors,
                            child: StudentChatScreen(
                              student: s,
                              colors: colors,
                            ),
                          ),
                        ),
                      ),
                    ),
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

RefPillTone _referencePillTone(PillTone tone) => switch (tone) {
  PillTone.success => RefPillTone.success,
  PillTone.danger => RefPillTone.danger,
  PillTone.warn => RefPillTone.warning,
  PillTone.primary => RefPillTone.primary,
  PillTone.accent => RefPillTone.accent,
  PillTone.neutral => RefPillTone.neutral,
};

class _ReferenceQuickAction extends StatelessWidget {
  const _ReferenceQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.md,
      semanticLabel: label,
      child: RefSurfaceCard(
        radius: RefRadius.md,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: c.primary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RefType.ui(
                size: 10.5,
                weight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceDataRow {
  const _ReferenceDataRow(
    this.label,
    this.value, {
    this.mono = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onTap;
}

class _ReferenceDetailSection extends StatelessWidget {
  const _ReferenceDetailSection({required this.title, required this.rows});

  final String title;
  final List<_ReferenceDataRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefSectionHeader(title: title),
        const SizedBox(height: 8),
        RefSurfaceCard(
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++)
                _ReferenceProfileLine(
                  row: rows[index],
                  last: index == rows.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceProfileLine extends StatelessWidget {
  const _ReferenceProfileLine({required this.row, required this.last});

  final _ReferenceDataRow row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(row.label, style: RefType.ui(size: 12, color: c.muted)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: row.mono
                  ? RefType.mono(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: row.onTap == null ? c.ink : c.primary,
                    )
                  : RefType.ui(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: row.onTap == null ? c.ink : c.primary,
                    ),
            ),
          ),
          if (row.onTap != null) ...[
            const SizedBox(width: 5),
            Icon(Icons.call_rounded, size: 14, color: c.primary),
          ],
        ],
      ),
    );
    final bordered = DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: content,
    );
    return row.onTap == null
        ? bordered
        : RefPressable(
            onPressed: row.onTap,
            borderRadius: BorderRadius.zero,
            child: bordered,
          );
  }
}

/// Drill-down list opened by a Student Flow number. The category stays visible
/// in the title, and every row leads to the same complete student profile.
class StudentCategoryScreen extends StatelessWidget {
  final String title;
  final StudentFlowCategory category;
  final List<Student> students;
  final SfColors colors;
  const StudentCategoryScreen({
    super.key,
    required this.title,
    required this.category,
    required this.students,
    required this.colors,
  });

  String get _subtitle => switch (category) {
    StudentFlowCategory.newlyAdmitted => 'Yaqinda qabul qilingan o‘quvchilar',
    StudentFlowCategory.active => 'Hozir ta’lim olayotgan o‘quvchilar',
    StudentFlowCategory.left => 'Ta’limni tark etgan o‘quvchilar',
    StudentFlowCategory.graduated => 'Yakunlagan o‘quvchilar',
    StudentFlowCategory.risk => 'Diqqat talab qiladigan o‘quvchilar',
    StudentFlowCategory.debt => 'To‘lov qarzdorligi mavjud o‘quvchilar',
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              '${students.length} ta o‘quvchi',
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _subtitle,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 14),
            if (students.isEmpty)
              _EmptyState(
                icon: Icons.groups_rounded,
                title: 'Ro‘yxat bo‘sh',
                sub: 'Tanlangan davr uchun o‘quvchi topilmadi.',
              )
            else
              SfCard(
                child: Column(
                  children: [
                    for (int index = 0; index < students.length; index++)
                      _StudentRow(
                        s: students[index],
                        last: index == students.length - 1,
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

/// CEO drill-down for the dashboard's top-student preview. The dashboard is a
/// compact ranking; this route exposes the operational context for every
/// student and keeps the complete profile one tap away.
class TopStudentsScreen extends StatelessWidget {
  final SfColors colors;
  const TopStudentsScreen({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final students = [...AppScope.of(context).students]
      ..sort((a, b) {
        final ratingOrder = studentRating(b).compareTo(studentRating(a));
        return ratingOrder != 0
            ? ratingOrder
            : b.attendance.compareTo(a.attendance);
      });
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Eng yaxshi o‘quvchilar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: students.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${students.length} o‘quvchi · reyting, baholar va o‘qish holati',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12,
                    color: c.muted,
                  ),
                ),
              );
            }
            final student = students[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopStudentCard(student: student),
            );
          },
        ),
      ),
    );
  }
}

class _TopStudentPreviewRow extends StatelessWidget {
  final Student student;
  final bool last;
  final VoidCallback onTap;
  const _TopStudentPreviewRow({
    required this.student,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SfAvatar(name: student.name, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    '${student.group} · ${studentTeacher(student)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              '${student.attendance}%',
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.success,
              ),
            ),
            const SizedBox(width: 8),
            Pill(
              '★ ${studentRating(student).toStringAsFixed(1)}',
              tone: PillTone.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStudentCard extends StatelessWidget {
  final Student student;
  const _TopStudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final profile = studentProfile(student);
    final username =
        student.username ??
        '@${profile.firstName.toLowerCase()}.${profile.lastName.toLowerCase()}';
    final payment = _studentTones[student.pay]!;
    return SfCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(StudentDetailScreen(student: student, colors: c))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SfAvatar(name: student.name, size: 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          username,
                          style: TextStyle(
                            fontFamily: SfType.mono,
                            fontSize: 10.5,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    '★ ${studentRating(student).toStringAsFixed(1)}',
                    tone: PillTone.success,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _TopStudentData('Branch', profile.branch),
              _TopStudentData('Group', student.group),
              _TopStudentData('Teacher', studentTeacher(student)),
              _TopStudentData('Attendance', '${student.attendance}%'),
              _TopStudentData(
                'Average score',
                '${studentAverageScore(student)}%',
              ),
              _TopStudentData('Payment status', payment.$2),
              _TopStudentData(
                'Study history',
                '${profile.enrolled} · ${student.pay == 'left' ? 'completed' : 'active'}',
                last: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStudentData extends StatelessWidget {
  final String label, value;
  final bool last;
  const _TopStudentData(this.label, this.value, {this.last = false});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : BorderSide(color: c.border.withValues(alpha: .72)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 10.5,
                color: c.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11.5,
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

/// Discord-style direct-message page with a student/family — message bubbles,
/// a composer with quick actions, and reactions on the latest reply.
class StudentChatScreen extends StatefulWidget {
  final Student student;
  final SfColors colors;
  const StudentChatScreen({
    super.key,
    required this.student,
    required this.colors,
  });
  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final List<ChatMsg> _msgs = [
    ChatMsg(
      'Assalomu alaykum! ${studentProfile(widget.student).firstName} bo‘yicha yangilik bormi?',
      mine: false,
    ),
    const ChatMsg('Bugungi dars uchun rahmat 🙏', mine: false),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _ctrl.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _msgs.add(ChatMsg(text.trim(), mine: true));
      _msgs.add(ChatMsg(_familyReply(text.trim()), mine: false));
    });
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _familyReply(String q) {
    final s = q.toLowerCase();
    if (s.contains('qarz') || s.contains('to') || s.contains('pul')) {
      return "Tushunarli, bu hafta to'lovni amalga oshiramiz. Rahmat!";
    }
    if (s.contains('davomat') || s.contains('kel')) {
      return "Ertaga albatta keladi, ogohlantirdik 👍";
    }
    return "Rahmat, ma'lumot uchun! Aloqada bo'lamiz.";
  }

  @override
  Widget build(BuildContext context) => _referenceBuild(context);

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = widget.colors;
    final p = studentProfile(widget.student);
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
          title: Semantics(
            button: true,
            label: '${tr(context, 'chat_profile')} · ${widget.student.name}',
            child: InkWell(
              key: const ValueKey('student-chat-profile-header'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                sfPageRoute(
                  ChatCabinetScreen(student: widget.student, colors: c),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        SfAvatar(name: widget.student.name, size: 34),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: c.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            '${p.branch} · ${tr(context, 'online')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 10,
                              color: c.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.call_rounded, size: 20, color: c.primary),
              onPressed: () => _launchPhoneCall(context, p.fatherPhone),
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: c.muted),
              onPressed: () =>
                  _snack(context, 'Profil · qidirish · mute (demo)'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                itemCount: _msgs.length,
                itemBuilder: (_, i) =>
                    _bubble(c, _msgs[i], i == _msgs.length - 1),
              ),
            ),
            // Quick replies (Discord-style)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final qr in [
                    "To'lov eslatmasi",
                    'Dars jadvali',
                    'Rahmat 🙏',
                    'Yig‘ilish',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _send(qr),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: c.border),
                          ),
                          child: Text(
                            qr,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.ink2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                8,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 22,
                      color: c.muted,
                    ),
                    onPressed: () =>
                        _snack(context, 'Fayl · rasm · ovoz (demo)'),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          color: c.ink,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                          hintText: tr(context, 'dm_hint'),
                          hintStyle: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 13,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        size: 17,
                        color: Colors.white,
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

  Widget _referenceBuild(BuildContext context) {
    final c = widget.colors;
    final p = studentProfile(widget.student);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            RefNavHeader(
              title: widget.student.name,
              subtitle: '${p.branch} · ${tr(context, 'online')}',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                RefIconAction(
                  key: const ValueKey('student-chat-profile-header'),
                  icon: Icons.person_outline_rounded,
                  tooltip: tr(context, 'chat_profile'),
                  onPressed: () => Navigator.of(context).push(
                    sfPageRoute(
                      ChatCabinetScreen(student: widget.student, colors: c),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                itemCount: _msgs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => Align(
                  alignment: _msgs[index].mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .76,
                    ),
                    child: RefChatBubble(
                      text: _msgs[index].text,
                      mine: _msgs[index].mine,
                      time: index.isEven ? '10:24' : '10:26',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final reply in [
                    "To'lov eslatmasi",
                    'Dars jadvali',
                    'Rahmat 🙏',
                    'Yig‘ilish',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: RefPressable(
                        onPressed: () => _send(reply),
                        borderRadius: RefRadius.pill,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: RefRadius.pill,
                            border: Border.all(color: c.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              reply,
                              style: RefType.ui(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: c.ink2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            RefComposer(
              controller: _ctrl,
              hint: tr(context, 'dm_hint'),
              onSend: _send,
              onAttach: () => _snack(context, 'Fayl · rasm · ovoz (demo)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(SfColors c, ChatMsg m, bool last) {
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: m.mine ? c.primary : c.surface,
          border: m.mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(m.mine ? 14 : 4),
            bottomRight: Radius.circular(m.mine ? 4 : 14),
          ),
        ),
        child: Text(
          m.text,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 13,
            height: 1.35,
            color: m.mine ? Colors.white : c.ink,
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  Navigator.of(context).maybePop();
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        backgroundColor: const Color(0xFF3A332A),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
}

class _DetailStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DetailStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SfSurfaceCard(
      color: c.surface2,
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label-left / value-right row used in the student profile cards. Tappable
/// rows (phones) show a thin chevron + call hint.
class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool mono, last;
  final VoidCallback? onTap;
  const _InfoRow(
    this.label,
    this.value, {
    this.mono = false,
    this.last = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final row = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                fontSize: 12.5,
                color: c.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono ? SfType.mono : SfType.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: onTap != null ? c.primary : c.ink,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.call_rounded, size: 13, color: c.primary),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });
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
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : c.ink2,
                ),
              ),
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
  int sel = 0; // kind / severity filter
  int branchSel = 0; // branch filter
  String query = '';

  bool _matchKind(Anomaly a) {
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
    // Unique branches → the dynamic branch filter row.
    final branches = <String>[
      '__all',
      ...{for (final a in store.anomalies) a.branch},
    ];
    if (branchSel >= branches.length) {
      branchSel = 0;
    }
    final wantBranch = branches[branchSel];
    final q = query.trim().toLowerCase();
    final list = store.anomalies.where((a) {
      if (!_matchKind(a)) return false;
      if (wantBranch != '__all' && a.branch != wantBranch) {
        return false;
      }
      if (q.isNotEmpty &&
          !a.title.toLowerCase().contains(q) &&
          !a.branch.toLowerCase().contains(q) &&
          !a.kind.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    final kinds = [
      tr(context, 'f_all'),
      tr(context, 'f_high'),
      tr(context, 'f_attendance'),
      tr(context, 'f_card'),
      tr(context, 'f_finance'),
    ];
    final branchLabels = [
      for (final b in branches)
        b == '__all' ? tr(context, 'f_all_branches') : b,
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow:
              '${store.anomalies.length} ${tr(context, 'unit_open_signal')}',
          title: tr(context, 'anomalies_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _SearchField(
                hint: tr(context, 'audit_search_hint'),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 10),
              _FilterChips(
                items: kinds,
                selected: sel,
                onSelect: (i) => setState(() => sel = i),
              ),
              const SizedBox(height: 8),
              _FilterChips(
                items: branchLabels,
                selected: branchSel,
                onSelect: (i) => setState(() => branchSel = i),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.flag_rounded,
                  title: 'Signal yo‘q',
                  sub: 'Bu filtr bo‘yicha anomaliya topilmadi.',
                )
              else
                SfCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < list.length; i++)
                        _AnomalyRow(
                          a: list[i],
                          last: i == list.length - 1,
                          store: store,
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

class _AnomalyRow extends StatelessWidget {
  final Anomaly a;
  final bool last;
  final AppStore store;
  const _AnomalyRow({required this.a, required this.last, required this.store});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final dot = a.sev == 'high'
        ? c.danger
        : a.sev == 'med'
        ? c.warn
        : c.muted;
    final scoreColor = a.score >= 80
        ? c.danger
        : a.score >= 60
        ? c.warn
        : c.muted;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          SfTheme(
            colors: c,
            child: AnomalyDetailScreen(a: a, store: store, colors: c),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${a.branch} · ',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          color: c.muted,
                        ),
                      ),
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
                          a.kind,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: c.ink2,
                          ),
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
                  '${a.score}',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                  ),
                ),
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
          ],
        ),
      ),
    );
  }
}

/// Full audit-anomaly page (was a bottom sheet) — header band with the AI
/// score, a "what / why / recommendation" breakdown, and the two resolutions.
class AnomalyDetailScreen extends StatelessWidget {
  final Anomaly a;
  final AppStore store;
  final SfColors colors;
  const AnomalyDetailScreen({
    super.key,
    required this.a,
    required this.store,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final sevColor = a.sev == 'high'
        ? c.danger
        : a.sev == 'med'
        ? c.warn
        : c.muted;
    final scoreColor = a.score >= 80
        ? c.danger
        : a.score >= 60
        ? c.warn
        : c.success;
    final sevLabel = a.sev == 'high'
        ? 'Yuqori'
        : a.sev == 'med'
        ? "O'rta"
        : 'Past';
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
            tr(context, 'anomalies_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Header band with the AI score on the right.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sevColor.withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.flag_rounded, size: 22, color: sevColor),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Pill(
                              sevLabel,
                              tone: a.sev == 'high'
                                  ? PillTone.danger
                                  : a.sev == 'med'
                                  ? PillTone.warn
                                  : PillTone.neutral,
                            ),
                            const SizedBox(width: 6),
                            Pill(a.kind, tone: PillTone.neutral),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${a.score}',
                        style: TextStyle(
                          fontFamily: SfType.mono,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, tr(context, 'anom_details')),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(tr(context, 'stu_branch'), a.branch),
                  _InfoRow(tr(context, 'anom_kind'), a.kind),
                  _InfoRow(tr(context, 'anom_sev'), sevLabel),
                  _InfoRow(
                    tr(context, 'anom_score'),
                    '${a.score} / 100',
                    mono: true,
                  ),
                  _InfoRow(
                    tr(context, 'anom_detected'),
                    'Bugun · AI monitoring',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, tr(context, 'anom_why')),
            SfCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _anomalyWhy(a),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12.5,
                    height: 1.5,
                    color: c.ink2,
                  ),
                ),
              ),
            ),
            _setSec(c, tr(context, 'anom_reco')),
            SfCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 17,
                      color: c.ai,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _anomalyReco(a),
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          height: 1.5,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
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
          child: Row(
            children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.push_pin_rounded,
                  label: 'Holatga aylantirish',
                  primary: true,
                  onTap: () {
                    store.anomalyToCase(a);
                    Navigator.of(context).maybePop();
                    _snack(
                      context,
                      '📌 Yangi audit holati ochildi',
                      bg: const Color(0xFF4F7B3B),
                    );
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
                    Navigator.of(context).maybePop();
                    _snack(context, '✓ Signal yopildi');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deterministic "why flagged" explanation per anomaly kind.
String _anomalyWhy(Anomaly a) {
  switch (a.kind) {
    case 'Davomat':
      return "${a.branch} filialida bu guruh 21 kun ketma-ket 100% davomat ko'rsatdi. "
          "Statistik jihatdan bu kam uchraydi — qo'lda belgilangan davomat ehtimoli bor.";
    case 'Karta':
      return "Bir hafta ichida 48 ta karta o'tkazmasi qayd etildi — o'rtacha ko'rsatkichdan "
          "ancha yuqori. Takroriy yoki bog'liq to'lovlar bo'lishi mumkin.";
    case 'Moliya':
      return "Naqd pul kvitansiyasiz qabul qilingan. Har bir som ledgerda iz qoldirishi shart — "
          "kvitansiyasiz yozuv anti-fraud qoidasini buzadi.";
    case 'Kirish':
      return "Tungi vaqtda profil o'zgartirildi. Odatdagi ish vaqtidan tashqari kirish — "
          "shubhali harakat sifatida belgilandi.";
    default:
      return "So'rovnoma o'rtacha 30 soniyada to'ldirilgan — bu javoblar puxta o'ylanmaganini "
          "ko'rsatishi mumkin. Ma'lumot sifati tekshirilsin.";
  }
}

/// Deterministic recommended next step per anomaly kind.
String _anomalyReco(Anomaly a) {
  switch (a.kind) {
    case 'Davomat':
      return "Kamera tahlilini solishtiring va o'qituvchi bilan suhbatlashing.";
    case 'Karta':
      return "To'lov kanallarini ko'rib chiqing va takroriy o'tkazmalarni tasdiqlang.";
    case 'Moliya':
      return "Naqd qabul qilgan xodimdan kvitansiya talab qiling va holat oching.";
    case 'Kirish':
      return "Kirish jurnalini tekshiring va parolni almashtirishni so'rang.";
    default:
      return "So'rovnomani qayta o'tkazing yoki javoblarni qo'lda tasdiqlang.";
  }
}

// ── Approvals (manager) ────────────────────────────────────────────────
// A decision is deliberately made only on the detail route. The list is an
// inbox: tapping a request opens its full context, so an accidental tap can
// never approve or reject a request.
Future<void> _openApproval(
  BuildContext context,
  AppStore store,
  Approval item,
  SfColors colors,
) async {
  final decision = await Navigator.of(
    context,
  ).push<bool>(sfPageRoute(ApprovalDetailScreen(item: item, colors: colors)));
  if (decision == null || !context.mounted) return;
  store.resolve(item, approved: decision);
  final posted = decision && item.amount > 0;
  sfSnack(
    context,
    decision
        ? (posted
              ? '✓ Tasdiqlandi · ${fmtMoney(item.amount)} kassa daftariga yozildi'
              : '✓ "${item.title}" tasdiqlandi')
        : '✗ "${item.title}" rad etildi',
    bg: decision ? const Color(0xFF4F7B3B) : const Color(0xFF8A4232),
  );
}

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final items = store.approvals;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: '${items.length} ${tr(context, 'unit_request')}',
          title: tr(context, 'approvals_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              if (items.isEmpty)
                _EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Hammasi tasdiqlangan',
                  sub: "Yangi so'rov kelganda shu yerda ko'rinadi.",
                )
              else
                for (final it in items)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => _openApproval(context, store, it, c),
                      child: Container(
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
                              Container(width: 4, color: it.rail),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  it.title,
                                                  style: TextStyle(
                                                    fontFamily: SfType.ui,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: c.ink,
                                                  ),
                                                ),
                                                Text(
                                                  it.who,
                                                  style: TextStyle(
                                                    fontFamily: SfType.ui,
                                                    fontSize: 10.5,
                                                    color: c.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (it.amount > 0)
                                            Text(
                                              '${it.inflow ? '+' : '−'}${fmtMoney(it.amount)}',
                                              style: TextStyle(
                                                fontFamily: SfType.mono,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: it.inflow
                                                    ? c.success
                                                    : c.ink,
                                              ),
                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          it.sub,
                                          style: TextStyle(
                                            fontFamily: SfType.ui,
                                            fontSize: 11.5,
                                            color: c.ink2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'Batafsil ko‘rish',
                                            style: TextStyle(
                                              fontFamily: SfType.ui,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: c.primary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: c.primary,
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
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class ApprovalDetailScreen extends StatelessWidget {
  final Approval item;
  final SfColors colors;
  const ApprovalDetailScreen({
    super.key,
    required this.item,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final type = item.amount > 0 ? 'Moliyaviy so‘rov' : 'Operatsion so‘rov';
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'So‘rov tafsilotlari',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  if (item.amount > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${item.inflow ? '+' : '−'}${fmtMoney(item.amount)}',
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: item.inflow ? c.success : c.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Yuborgan', item.who),
                  _InfoRow('Yaratilgan vaqt', '17 Iyl 2026 · 14:30'),
                  _InfoRow('So‘rov turi', type),
                  _InfoRow('Tavsif', item.sub),
                  _InfoRow(
                    'Bog‘liq ma’lumot',
                    item.amount > 0
                        ? 'Kassa va o‘quvchi hisobi'
                        : 'Filial operatsiyasi',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Qaror',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ApprBtn(
                    label: tr(context, 'btn_reject'),
                    primary: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ApprBtn(
                    label: tr(context, 'btn_approve'),
                    primary: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
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
          child: Text(
            label,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: primary ? const Color(0xFFFFFCF5) : c.ink2,
            ),
          ),
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
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: c.success),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 11.5,
              color: c.muted,
            ),
          ),
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
  const _FilterChips({
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final on = i == selected;
          return Semantics(
            button: true,
            selected: on,
            label: items[i],
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: on ? c.ink : c.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: on ? c.ink : c.borderStrong.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Text(
                    items[i],
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: on ? c.bg : c.ink2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A pill search box used on list screens (anomalies, students, …).
class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => SfTextField(
    hint: hint,
    prefixIcon: Icons.search_rounded,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
  );
}

/// Rounded bottom-sheet container with a drag handle.
class _SheetShell extends StatelessWidget {
  final List<Widget> children;
  const _SheetShell({required this.children});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
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
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            ...children,
          ],
        ),
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
          title: Text(
            'Kassa daftari',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
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
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JORIY QOLDIQ',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmtMoney(store.balance),
                          style: TextStyle(
                            fontFamily: SfType.mono,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FlowStat(
                                label: 'Kirim',
                                value: store.inflowTotal,
                                color: c.success,
                                up: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FlowStat(
                                label: 'Chiqim',
                                value: store.outflowTotal,
                                color: c.danger,
                                up: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SfCard(
                    child: Column(
                      children: [
                        const SfCardHeader('Harakatlar'),
                        for (int i = 0; i < store.ledger.length; i++)
                          _LedgerRow(
                            e: store.ledger[i],
                            last: i == store.ledger.length - 1,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    "Har bir yozuv o'zgarmas — pulni yo'qotib bo'lmaydi.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10.5,
                      color: c.muted2,
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

class _FlowStat extends StatelessWidget {
  final String label;
  final num value;
  final Color color;
  final bool up;
  const _FlowStat({
    required this.label,
    required this.value,
    required this.color,
    required this.up,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: c.muted,
                  ),
                ),
                Text(
                  fmtMoneyShort(value),
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
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

class _LedgerRow extends StatelessWidget {
  final LedgerEntry e;
  final bool last;
  const _LedgerRow({required this.e, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(sfPageRoute(LedgerEntryScreen(entry: e, colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
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
                color: (e.inflow ? c.success : c.danger).withValues(
                  alpha: 0.14,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                e.inflow ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16,
                color: e.inflow ? c.success : c.danger,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${e.who} · ',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          color: c.muted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          e.channel,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: c.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e.inflow ? '+' : '−'}${fmtMoneyShort(e.amount)}',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: e.inflow ? c.success : c.ink,
                  ),
                ),
                Text(
                  e.time,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9,
                    color: c.muted,
                  ),
                ),
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
  const LedgerEntryScreen({
    super.key,
    required this.entry,
    required this.colors,
  });

  Widget _row(BuildContext context, String k, String v, {bool last = false}) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              color: c.muted,
            ),
          ),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
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
          title: Text(
            tr(context, 'tx_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Hero amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      e.inflow
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 26,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${e.inflow ? '+' : '−'}${fmtMoney(e.amount)}',
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Pill(
                    e.inflow
                        ? tr(context, 'tx_inflow')
                        : tr(context, 'tx_outflow'),
                    tone: e.inflow ? PillTone.success : PillTone.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
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
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 20, color: c.success),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'tx_confirmed'),
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.success,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(context, 'tx_immutable'),
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 11,
                            color: c.ink2,
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
    );
  }
}

// ── Branches (CEO ranking detail) ──────────────────────────────────────
class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});
  @override
  Widget build(BuildContext context) => const _ReferenceBranchesPage();

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = SfTheme.of(context);
    final branches = AppScope.of(context).branches;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: '${branches.length} ${tr(context, 'unit_branch')}',
          title: tr(context, 'branches_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              for (int i = 0; i < branches.length; i++)
                Builder(
                  builder: (context) {
                    final b = branches[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SfTap(
                        scale: 0.985,
                        child: SfSurfaceCard(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                sfPageRoute(
                                  BranchWorkspaceScreen(branch: b, colors: c),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(22),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      13,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          b.mark.withValues(alpha: 0.16),
                                          c.surface,
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: b.mark,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: b.mark.withValues(
                                                  alpha: 0.25,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: SfStar(
                                              size: 19,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                b.name,
                                                style: TextStyle(
                                                  fontFamily: SfType.ui,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.18,
                                                  color: c.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${fmtMoney(b.revenue)}/oy',
                                                style: TextStyle(
                                                  fontFamily: SfType.ui,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: c.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Pill(
                                          '${b.trend >= 0 ? '↑' : '↓'}${b.trend.abs()}%',
                                          tone: b.trend >= 4
                                              ? PillTone.success
                                              : b.trend >= 0
                                              ? PillTone.warn
                                              : PillTone.danger,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.surface2.withValues(alpha: 0.58),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: c.border.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _branchStat(
                                          context,
                                          '${b.students}',
                                          "o'quvchi",
                                          c.ink,
                                        ),
                                        _branchStat(
                                          context,
                                          '${b.attendance}%',
                                          'davomat',
                                          b.attendance >= 92
                                              ? c.success
                                              : c.warn,
                                          border: true,
                                        ),
                                        _branchStat(
                                          context,
                                          fmtMoneyShort(b.revenue),
                                          'daromad',
                                          c.ink,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _branchStat(
    BuildContext context,
    String value,
    String label,
    Color color, {
    bool border = false,
  }) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: border ? BorderSide(color: c.border) : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceBranchesPage extends StatelessWidget {
  const _ReferenceBranchesPage();

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final branches = AppScope.of(context).branches;
    final totalStudents = branches.fold<int>(
      0,
      (sum, branch) => sum + branch.students,
    );
    final averageAttendance = branches.isEmpty
        ? 0
        : (branches.fold<int>(0, (sum, branch) => sum + branch.attendance) /
                  branches.length)
              .round();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RefLargeHeader(
          eyebrow: '${branches.length} ${tr(context, 'unit_branch')}',
          title: tr(context, 'branches_title'),
          subtitle: 'Filiallarni tanlang va operatsion ko‘rsatkichlarni oching',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RefAdaptiveGrid(
                minCellWidth: 152,
                children: [
                  RefMetricCard(
                    label: 'Filiallar',
                    value: '${branches.length}',
                    icon: Icons.account_tree_rounded,
                    tone: RefMetricTone.primary,
                  ),
                  RefMetricCard(
                    label: 'O‘quvchilar',
                    value: '$totalStudents',
                    icon: Icons.groups_rounded,
                    tone: RefMetricTone.success,
                  ),
                  RefMetricCard(
                    label: 'O‘rtacha davomat',
                    value: '$averageAttendance%',
                    icon: Icons.how_to_reg_rounded,
                    tone: averageAttendance >= 92
                        ? RefMetricTone.success
                        : RefMetricTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const RefSectionHeader(
                title: 'Filiallar ro‘yxati',
                subtitle: 'Daromad, davomat va trend',
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < branches.length; index++) ...[
                RefStaggeredReveal(
                  order: index,
                  child: _ReferenceBranchCard(
                    branch: branches[index],
                    colors: c,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceBranchCard extends StatelessWidget {
  const _ReferenceBranchCard({required this.branch, required this.colors});

  final Branch branch;
  final SfColors colors;

  @override
  Widget build(BuildContext context) {
    final trendTone = branch.trend >= 4
        ? RefPillTone.success
        : branch.trend >= 0
        ? RefPillTone.warning
        : RefPillTone.danger;
    return RefPressable(
      onPressed: () => Navigator.of(context).push(
        sfPageRoute(BranchWorkspaceScreen(branch: branch, colors: colors)),
      ),
      borderRadius: RefRadius.lg,
      semanticLabel: 'Filial ${branch.name}',
      child: RefSurfaceCard(
        padding: EdgeInsets.zero,
        elevated: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [branch.mark.withValues(alpha: .16), colors.surface],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: branch.mark,
                        borderRadius: RefRadius.md,
                        boxShadow: [
                          BoxShadow(
                            color: branch.mark.withValues(alpha: .24),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.account_tree_rounded,
                          size: 23,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: RefType.ui(
                              size: 16,
                              weight: FontWeight.w800,
                              color: colors.ink,
                              letterSpacing: -.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${fmtMoney(branch.revenue)}/oy · ${branch.students} o‘quvchi',
                            style: RefType.ui(size: 11.5, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    RefPill(
                      label:
                          '${branch.trend >= 0 ? '↑' : '↓'}${branch.trend.abs()}%',
                      tone: trendTone,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                RefAdaptiveGrid(
                  minCellWidth: 92,
                  spacing: 7,
                  children: [
                    _ReferenceBranchMetric(
                      label: 'O‘QUVCHI',
                      value: '${branch.students}',
                      color: colors.ink,
                    ),
                    _ReferenceBranchMetric(
                      label: 'DAVOMAT',
                      value: '${branch.attendance}%',
                      color: branch.attendance >= 92
                          ? colors.success
                          : branch.attendance >= 88
                          ? colors.warn
                          : colors.danger,
                    ),
                    _ReferenceBranchMetric(
                      label: 'DAROMAD',
                      value: fmtMoneyShort(branch.revenue),
                      color: colors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filial ish maydonini ochish',
                        style: RefType.ui(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceBranchMetric extends StatelessWidget {
  const _ReferenceBranchMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: .76),
        borderRadius: RefRadius.md,
        border: Border.all(color: c.border.withValues(alpha: .8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RefType.mono(
                size: 13.5,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: RefType.eyebrow(size: 8, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
void _showBranchSheet(BuildContext context, Branch b) {
  final c = SfTheme.of(context);
  // Synthesise a 8-point revenue trend ending at the branch's current trend sign.
  final base = b.revenue / 1e6;
  final spark = [
    base * 0.82,
    base * 0.86,
    base * 0.84,
    base * 0.9,
    base * 0.93,
    base * 0.97,
    base * (b.trend >= 0 ? 0.99 : 1.02),
    base,
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SfTheme(
      colors: c,
      child: _SheetShell(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: b.mark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SfStar(size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'Filial · ${b.students} o‘quvchi',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Pill(
                '${b.trend >= 0 ? '↑' : '↓'}${b.trend.abs()}%',
                tone: b.trend >= 4
                    ? PillTone.success
                    : b.trend >= 0
                    ? PillTone.warn
                    : PillTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAROMAD · 8 OY',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Sparkline(
                  data: spark,
                  color: b.trend >= 0 ? c.success : c.danger,
                  height: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DetailStat(
                  'Daromad/oy',
                  fmtMoneyShort(b.revenue),
                  c.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailStat(
                  'Davomat',
                  '${b.attendance}%',
                  b.attendance >= 92 ? c.success : c.warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _DetailStat("O'quvchi", '${b.students}', c.ink)),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailStat(
                  'Trend',
                  '${b.trend >= 0 ? '+' : ''}${b.trend}%',
                  b.trend >= 0 ? c.success : c.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Full mobile branch workspace. It replaces the old read-only bottom sheet
/// when a CEO needs to review, configure, pause or export one branch.
class BranchWorkspaceScreen extends StatefulWidget {
  final Branch branch;
  final SfColors colors;
  const BranchWorkspaceScreen({
    super.key,
    required this.branch,
    required this.colors,
  });
  @override
  State<BranchWorkspaceScreen> createState() => _BranchWorkspaceScreenState();
}

class _BranchWorkspaceScreenState extends State<BranchWorkspaceScreen> {
  bool paused = false;

  Future<void> _confirmPause() async {
    final language = SettingsScope.of(context).lang;
    final words = switch (language) {
      SfLang.ru => (
        'Приостановить филиал?',
        'Вы уверены, что хотите приостановить работу филиала?',
        'Отмена',
        'Приостановить',
      ),
      SfLang.en => (
        'Pause branch?',
        'Are you sure you want to pause this branch?',
        'Cancel',
        'Pause',
      ),
      _ => (
        'Filialni pauzaga qo‘yish?',
        'Haqiqatan ham filial ishini pauzaga qo‘ymoqchimisiz?',
        'Bekor qilish',
        'Pauza',
      ),
    };
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final c = widget.colors;
        return SfTheme(
          colors: c,
          child: AlertDialog(
            backgroundColor: c.surface,
            title: Text(
              words.$1,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            content: Text(
              words.$2,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 13,
                color: c.ink2,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  words.$3,
                  style: TextStyle(fontFamily: SfType.ui, color: c.muted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  words.$4,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontWeight: FontWeight.w800,
                    color: c.danger,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (answer == true && mounted) {
      setState(() => paused = true);
      AppScope.of(context).logActivity(
        icon: Icons.pause_circle_filled_rounded,
        title: 'Filial pauzaga qo‘yildi',
        detail: widget.branch.name,
        kind: 'branch',
      );
      _snack(
        context,
        language == SfLang.en
            ? 'Branch paused'
            : language == SfLang.ru
            ? 'Филиал приостановлен'
            : 'Filial pauzaga qo‘yildi',
        bg: widget.colors.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final b = widget.branch;
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
            b.name,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Report',
              icon: Icon(Icons.download_rounded, color: c.ink2),
              onPressed: () {
                AppScope.of(context).setBranchScope(b.name);
                _showReportFormatPicker(context, SfRole.ceo, colors: c);
              },
            ),
            IconButton(
              tooltip: 'Configure',
              icon: Icon(Icons.tune_rounded, color: c.ink2),
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(BranchConfigureScreen(branch: b, colors: c))),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [b.mark, b.mark.withValues(alpha: 0.68)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: SfStar(size: 22, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          paused
                              ? 'Pauzada · qayta faollashtirish kerak'
                              : 'Faol filial · barcha ko‘rsatkichlar yangilanadi',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    paused ? 'PAUZA' : 'FAOL',
                    tone: paused ? PillTone.danger : PillTone.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _kpiGrid([
              _Kpi(
                label: 'Daromad',
                value: fmtMoneyMln(b.revenue),
                color: c.success,
                icon: Icons.payments_rounded,
                trend: (up: b.trend >= 0, v: '${b.trend.abs()}%'),
              ),
              _Kpi(
                label: 'O‘quvchilar',
                value: '${b.students}',
                icon: Icons.groups_rounded,
              ),
              _Kpi(
                label: 'Xodimlar',
                value: '${(b.students / 31).round()}',
                icon: Icons.badge_rounded,
              ),
              _Kpi(
                label: 'Davomat',
                value: '${b.attendance}%',
                color: b.attendance >= 92 ? c.success : c.warn,
                icon: Icons.fact_check_rounded,
              ),
            ]),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  const SfCardHeader('Davomat / karta salomatligi'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Yaxshi: 72%\nO‘rtacha: 19%\nPast: 9%',
                          child: Donut(
                            size: 92,
                            thickness: 14,
                            segments: [
                              DonutSegment(72, c.success),
                              DonutSegment(19, c.warn),
                              DonutSegment(9, c.danger),
                            ],
                            // This State's build context is above the local
                            // SfTheme wrapper. Build the label from the known
                            // route colours instead of calling _mono(context).
                            center: Text(
                              '${b.attendance}%',
                              style: TextStyle(
                                fontFamily: SfType.mono,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              LegendRow(c.success, 'Yaxshi (>90%)', '72%'),
                              LegendRow(c.warn, 'O‘rtacha (80–90%)', '19%'),
                              LegendRow(c.danger, 'Past (<80%)', '9%'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  const SfCardHeader('O‘qituvchilar reytingi · top'),
                  _branchTeacherRow(
                    c,
                    'Madina Halimova',
                    'Matematika',
                    '87%',
                    '★ 5',
                  ),
                  _branchTeacherRow(
                    c,
                    'Sevara Ibragimova',
                    'Ingliz tili',
                    '90%',
                    '★ 5',
                  ),
                  _branchTeacherRow(
                    c,
                    'Munira Tosheva',
                    'Fizika',
                    '93%',
                    '★ 5',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  const SfCardHeader('So‘nggi hodisalar'),
                  _branchEventRow(
                    c,
                    Icons.trending_up_rounded,
                    'Yangi to‘lov · 1.2 mln',
                    '2 daqiqa',
                    c.success,
                  ),
                  _branchEventRow(
                    c,
                    Icons.notifications_active_rounded,
                    'Qarz eslatmasi yuborildi',
                    '14 daqiqa',
                    c.warn,
                  ),
                  _branchEventRow(
                    c,
                    Icons.flag_rounded,
                    'Audit flag · davomati past',
                    '2 soat',
                    c.danger,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SfButton(
                    icon: Icons.tune_rounded,
                    label: 'Configure',
                    primary: false,
                    onTap: () => Navigator.of(context).push(
                      sfPageRoute(BranchConfigureScreen(branch: b, colors: c)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SfButton(
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    label: paused ? 'Faollashtirish' : 'Pauza',
                    primary: true,
                    onTap: paused
                        ? () => setState(() => paused = false)
                        : _confirmPause,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchTeacherRow(
    SfColors c,
    String name,
    String subject,
    String attendance,
    String rating, {
    bool last = false,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: BoxDecoration(
      border: Border(
        bottom: last ? BorderSide.none : BorderSide(color: c.border),
      ),
    ),
    child: Row(
      children: [
        SfAvatar(name: name, size: 31),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              Text(
                subject,
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
          attendance,
          style: TextStyle(
            fontFamily: SfType.mono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.success,
          ),
        ),
        const SizedBox(width: 8),
        Pill(rating, tone: PillTone.success),
      ],
    ),
  );

  Widget _branchEventRow(
    SfColors c,
    IconData icon,
    String title,
    String time,
    Color color, {
    bool last = false,
  }) => InkWell(
    onTap: () => _snack(context, '$title · $time'),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 9.5,
              color: c.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class BranchConfigureScreen extends StatefulWidget {
  final Branch branch;
  final SfColors colors;
  const BranchConfigureScreen({
    super.key,
    required this.branch,
    required this.colors,
  });
  @override
  State<BranchConfigureScreen> createState() => _BranchConfigureScreenState();
}

class _BranchConfigureScreenState extends State<BranchConfigureScreen> {
  String staff = 'Madina Halimova';
  late String target = widget.branch.name;
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: '${widget.branch.name} · Configure',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SfCard(
            child: Column(
              children: [
                const SfCardHeader('Filial ma’lumotlari'),
                _InfoRow('Menejer', 'Dilnoza Yo‘ldosheva'),
                _InfoRow(
                  'Xodimlar',
                  '${(widget.branch.students / 31).round()}',
                ),
                _InfoRow('Xonalar', '12'),
                _InfoRow('Ish vaqti', '08:00 — 21:00', last: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'XODIMNI FILIALGA O‘TKAZISH',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 8),
          SfCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: staff,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Xodim'),
                  items:
                      const [
                            'Madina Halimova',
                            'Sevara Ibragimova',
                            'Munira Tosheva',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => staff = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Yangi filial'),
                  items: AppScope.of(context).branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.name,
                          child: Text(b.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => target = v!),
                ),
                const SizedBox(height: 14),
                SfButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Xodimni o‘tkazish',
                  primary: true,
                  onTap: () => _snack(context, '$staff → $target'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final active = store.cases
        .where((cs) => store.statusOf(cs) != 'closed')
        .length;
    final filters = [
      tr(context, 'f_all'),
      tr(context, 'f_open'),
      tr(context, 'f_review'),
      tr(context, 'f_closed'),
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: '$active ${tr(context, 'unit_active_case')}',
          title: tr(context, 'cases_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _FilterChips(
                items: filters,
                selected: sel,
                onSelect: (i) => setState(() => sel = i),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.push_pin_rounded,
                  title: 'Holat yo‘q',
                  sub: 'Bu holat bo‘yicha yozuv yo‘q.',
                )
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
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          SfTheme(
            colors: c,
            child: CaseDetailScreen(cs: cs, store: store, colors: c),
          ),
        ),
      ),
      child: Container(
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
                width: 4,
                color: cs.sev == 'high'
                    ? c.danger
                    : cs.sev == 'med'
                    ? c.warn
                    : c.muted,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            cs.id,
                            style: TextStyle(
                              fontFamily: SfType.mono,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.muted,
                            ),
                          ),
                          const Spacer(),
                          Pill(meta.$2, tone: meta.$1),
                          const SizedBox(width: 6),
                          Pill(
                            cs.sev == 'high'
                                ? 'Yuqori'
                                : cs.sev == 'med'
                                ? "O'rta"
                                : 'Past',
                            tone: cs.sev == 'high'
                                ? PillTone.danger
                                : cs.sev == 'med'
                                ? PillTone.warn
                                : PillTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cs.title,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
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
    );
  }
}

/// Full audit-case page (was a bottom sheet) — header, details, a timeline and
/// the status switcher that updates live.
class CaseDetailScreen extends StatefulWidget {
  final AuditCase cs;
  final AppStore store;
  final SfColors colors;
  const CaseDetailScreen({
    super.key,
    required this.cs,
    required this.store,
    required this.colors,
  });
  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final cs = widget.cs;
    final store = widget.store;
    final status = store.statusOf(cs);
    final meta = _caseStatusMeta[status]!;
    final sevColor = cs.sev == 'high'
        ? c.danger
        : cs.sev == 'med'
        ? c.warn
        : c.muted;
    final sevLabel = cs.sev == 'high'
        ? 'Yuqori'
        : cs.sev == 'med'
        ? "O'rta"
        : 'Past';
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
            cs.id,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sevColor.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(meta.$2, tone: meta.$1),
                      const SizedBox(width: 6),
                      Pill(
                        sevLabel,
                        tone: cs.sev == 'high'
                            ? PillTone.danger
                            : cs.sev == 'med'
                            ? PillTone.warn
                            : PillTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    cs.title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, tr(context, 'anom_details')),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(tr(context, 'anom_kind'), cs.id, mono: true),
                  _InfoRow(tr(context, 'case_status_label'), meta.$2),
                  _InfoRow(tr(context, 'anom_sev'), sevLabel, last: true),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, tr(context, 'case_timeline')),
            SfCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _caseStep(
                      c,
                      Icons.flag_rounded,
                      c.danger,
                      'Signal aniqlandi',
                      'AI monitoring · avtomatik',
                      true,
                    ),
                    _caseStep(
                      c,
                      Icons.push_pin_rounded,
                      c.warn,
                      'Holat ochildi',
                      'Audit guruhi',
                      true,
                    ),
                    _caseStep(
                      c,
                      Icons.search_rounded,
                      c.primary,
                      'Tekshiruv',
                      status == 'review' || status == 'closed'
                          ? 'Jarayonda'
                          : 'Kutilmoqda',
                      status == 'review' || status == 'closed',
                    ),
                    _caseStep(
                      c,
                      Icons.check_circle_rounded,
                      c.success,
                      'Yopilgan',
                      status == 'closed' ? 'Hal qilindi' : 'Kutilmoqda',
                      status == 'closed',
                      last: true,
                    ),
                  ],
                ),
              ),
            ),
            _setSec(c, tr(context, 'case_change_status')),
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
                      primary: status == entry.key,
                      onTap: () {
                        store.setCaseStatus(cs, entry.key);
                        setState(() {});
                        _snack(
                          context,
                          '✓ ${cs.id} → ${entry.value.$2}',
                          bg: const Color(0xFF4F7B3B),
                        );
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

  Widget _caseStep(
    SfColors c,
    IconData icon,
    Color col,
    String title,
    String sub,
    bool done, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done ? col.withValues(alpha: 0.16) : c.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: done ? col : c.muted2),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: done ? c.ink : c.muted,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    color: c.muted,
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
  bool _historyOpen = false;

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
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
            : "6 o'quvchi ketish belgisini ko'rsatmoqda.",
      ),
      (
        'O\'sish',
        'success',
        ceo
            ? 'Ingliz B2 to\'lgan — yangi guruh \$4.2k/oy.'
            : "Kutish ro'yxatida 14 o'quvchi bor.",
      ),
      (
        'Moliya',
        'warn',
        ceo
            ? '142 oila qarzdor. 38 tasi 30+ kun.'
            : '38 oila qarzdor (22.4 mln).',
      ),
    ];
    final mainCol = Column(
      children: [
        // Top bar with the history (☰) button on the left and a new-chat (+).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _AiIconBtn(
                icon: Icons.menu_rounded,
                onTap: () => setState(() => _historyOpen = true),
              ),
              const Spacer(),
              _AiIconBtn(
                icon: Icons.add_comment_rounded,
                onTap: () {
                  store.newConversation();
                  setState(() => _historyOpen = false);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              SfHead(
                eyebrow: tr(context, 'ai_eyebrow'),
                title: tr(context, 'ai_title'),
              ),
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
                            ins.$2 == 'danger'
                                ? 'Yuqori'
                                : ins.$2 == 'warn'
                                ? "O'rta"
                                : 'Imkon',
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
                          for (final p in [
                            'Churn sabablari',
                            'Daromad prognozi',
                            'Reyting',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => _send(store, p),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.aiBg.first,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: c.aiBorder),
                                  ),
                                  child: Text(
                                    p,
                                    style: TextStyle(
                                      fontFamily: SfType.ui,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: c.ai,
                                    ),
                                  ),
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
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(store),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      color: c.ink,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: tr(context, 'ai_hint'),
                      hintStyle: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 13,
                        color: c.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _send(store),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final w = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        mainCol,
        // Scrim
        IgnorePointer(
          ignoring: !_historyOpen,
          child: AnimatedOpacity(
            opacity: _historyOpen ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => setState(() => _historyOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        // Sliding conversation-history panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: _historyOpen ? 0 : -(w * 0.8),
          top: 0,
          bottom: 0,
          width: w * 0.8,
          child: _AiHistoryPanel(
            store: store,
            colors: c,
            onSelect: (i) {
              store.selectConversation(i);
              setState(() => _historyOpen = false);
            },
            onNew: () {
              store.newConversation();
              setState(() => _historyOpen = false);
            },
            onClose: () => setState(() => _historyOpen = false),
          ),
        ),
      ],
    );
  }
}

/// Round icon button used in the AI top bar.
class _AiIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AiIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 18, color: c.ink2),
      ),
    );
  }
}

/// ChatGPT-style left panel listing saved AI conversations.
class _AiHistoryPanel extends StatelessWidget {
  final AppStore store;
  final SfColors colors;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew, onClose;
  const _AiHistoryPanel({
    required this.store,
    required this.colors,
    required this.onSelect,
    required this.onNew,
    required this.onClose,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: c.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: c.ai),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'ai_history'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close_rounded, size: 20, color: c.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GestureDetector(
                onTap: onNew,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr(context, 'ai_new_chat'),
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: store.conversations.length,
                itemBuilder: (_, i) {
                  final conv = store.conversations[i];
                  final active = i == store.activeConv;
                  final preview = conv.turns.isEmpty
                      ? tr(context, 'ai_empty_chat')
                      : conv.turns.last.text;
                  return InkWell(
                    onTap: () => onSelect(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active ? c.surface2 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: active ? Border.all(color: c.border) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: active ? c.ai : c.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conv.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: SfType.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                Text(
                                  preview,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          gradient: mine
              ? null
              : LinearGradient(
                  colors: c.aiBg,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: mine ? c.primary : null,
          border: mine ? null : Border.all(color: c.aiBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(mine ? 13 : 4),
            bottomRight: Radius.circular(mine ? 4 : 13),
          ),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            fontFamily: mine ? SfType.ui : SfType.display,
            fontStyle: mine ? FontStyle.normal : FontStyle.italic,
            fontSize: mine ? 13 : 14.5,
            height: 1.35,
            color: mine ? Colors.white : c.ink,
          ),
        ),
      ),
    );
  }
}

// ── Groups (Sardor) ────────────────────────────────────────────────────
/// Aggregated info for one teaching group (derived from the student list).
class GroupInfo {
  final String name, branch, level, teacher, schedule;
  final int count, avgAtt, debtors;
  final String status;
  const GroupInfo(
    this.name,
    this.branch,
    this.level,
    this.teacher,
    this.schedule,
    this.count,
    this.avgAtt,
    this.debtors,
  ) : status = 'active';

  const GroupInfo.withStatus(
    this.name,
    this.branch,
    this.level,
    this.teacher,
    this.schedule,
    this.count,
    this.avgAtt,
    this.debtors,
    this.status,
  );
}

const _kTeachers = [
  'Nigora Karimova',
  'Bobur Aliyev',
  'Malika Yusupova',
  'Sardor Tursunov',
  'Feruza Rashidova',
  'Jasur Komilov',
  'Kamola Sobirova',
];
const _kSchedules = [
  'Du·Cho·Ju · 10:00',
  'Se·Pa·Sha · 14:00',
  'Du·Cho·Ju · 16:00',
  'Se·Pa · 18:00',
  'Ju·Sha · 09:00',
];

List<GroupInfo> _groupsFrom(
  List<Student> students, [
  List<ManagedGroup> extraGroups = const [],
]) {
  final byName = <String, List<Student>>{};
  for (final s in students) {
    byName.putIfAbsent(s.group, () => []).add(s);
  }
  final out = <GroupInfo>[];
  for (final entry in byName.entries) {
    final ss = entry.value;
    final h = _gseed(entry.key);
    final p = studentProfile(ss.first);
    final avg = (ss.fold<int>(0, (a, s) => a + s.attendance) / ss.length)
        .round();
    final debtors = ss.where((s) => s.debt > 0).length;
    out.add(
      GroupInfo(
        entry.key,
        p.branch,
        p.level,
        _kTeachers[h % _kTeachers.length],
        _kSchedules[h % _kSchedules.length],
        ss.length,
        avg,
        debtors,
      ),
    );
  }
  for (final group in extraGroups) {
    if (byName.containsKey(group.name)) continue;
    out.add(
      GroupInfo.withStatus(
        group.name,
        group.branch,
        group.level,
        group.teacher,
        group.schedule,
        0,
        0,
        0,
        group.status,
      ),
    );
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

int _gseed(String s) {
  var h = 0;
  for (final r in s.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return h;
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String query = '';
  int branchSel = 0;
  int levelSel = 0;
  int teacherSel = 0;
  int statusSel = 0;
  bool showFilters = false;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final students = store.students;
    final groups = _groupsFrom(students, store.extraGroups);
    final branches = <String>[
      '__all',
      ...{for (final g in groups) g.branch},
    ];
    final levels = <String>[
      '__all',
      ...{for (final g in groups) g.level},
    ];
    final teachers = <String>[
      '__all',
      ...{for (final g in groups) g.teacher},
    ];
    if (branchSel >= branches.length) branchSel = 0;
    if (levelSel >= levels.length) levelSel = 0;
    if (teacherSel >= teachers.length) teacherSel = 0;
    final wantBranch = branches[branchSel];
    final wantLevel = levels[levelSel];
    final wantTeacher = teachers[teacherSel];
    final q = query.trim().toLowerCase();
    final list = groups.where((g) {
      if (wantBranch != '__all' && g.branch != wantBranch) return false;
      if (wantLevel != '__all' && g.level != wantLevel) return false;
      if (wantTeacher != '__all' && g.teacher != wantTeacher) return false;
      if (statusSel == 1 && g.status != 'active') return false;
      if (statusSel == 2 && g.status != 'paused') return false;
      if (statusSel == 3 && g.status != 'closed') return false;
      if (statusSel == 4 && g.count < 2) return false;
      if (q.isNotEmpty &&
          !g.name.toLowerCase().contains(q) &&
          !g.teacher.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    final branchF = [
      for (final b in branches)
        b == '__all' ? tr(context, 'f_all_branches') : b,
    ];
    final levelF = [
      for (final l in levels) l == '__all' ? tr(context, 'f_all_levels') : l,
    ];
    final teacherF = [
      for (final t in teachers) t == '__all' ? 'Barcha o‘qituvchilar' : t,
    ];
    final active =
        (branchSel != 0 ? 1 : 0) +
        (levelSel != 0 ? 1 : 0) +
        (teacherSel != 0 ? 1 : 0) +
        (statusSel != 0 ? 1 : 0);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: '${groups.length} ${tr(context, 'unit_group')}',
          title: tr(context, 'groups_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CeoContextFilter(showBranches: false),
              const SizedBox(height: 10),
              _GroupStatusSummary(
                groups: groups,
                onSelect: (index) => setState(() => statusSel = index),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      hint: tr(context, 'groups_search'),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterToggle(
                    active: showFilters,
                    count: active,
                    onTap: () => setState(() => showFilters = !showFilters),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(
                    icon: Icons.add_rounded,
                    tooltip: 'Yangi guruh',
                    onTap: () => Navigator.of(
                      context,
                    ).push(sfPageRoute(GroupCreateScreen(colors: c))),
                  ),
                ],
              ),
              if (showFilters) ...[
                const SizedBox(height: 10),
                Text(
                  tr(context, 'filter_branch').toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 6),
                _FilterChips(
                  items: branchF,
                  selected: branchSel,
                  onSelect: (i) => setState(() => branchSel = i),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'filter_level').toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 6),
                _FilterChips(
                  items: levelF,
                  selected: levelSel,
                  onSelect: (i) => setState(() => levelSel = i),
                ),
                const SizedBox(height: 8),
                Text(
                  'O‘QITUVCHI'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 6),
                _FilterChips(
                  items: teacherF,
                  selected: teacherSel,
                  onSelect: (i) => setState(() => teacherSel = i),
                ),
                const SizedBox(height: 8),
                _FilterChips(
                  items: const [
                    'Hammasi',
                    'Faol',
                    'Pauzada',
                    'Yopilgan',
                    '2+ o‘quvchi',
                  ],
                  selected: statusSel,
                  onSelect: (i) => setState(() => statusSel = i),
                ),
              ],
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.workspaces_rounded,
                  title: 'Guruh yo‘q',
                  sub: 'Boshqa filtrni tanlang.',
                )
              else
                for (final g in list) _GroupCard(g: g, colors: c),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupInfo g;
  final SfColors colors;
  const _GroupCard({required this.g, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final attColor = g.avgAtt >= 92
        ? c.success
        : g.avgAtt >= 85
        ? c.warn
        : c.danger;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          SfTheme(
            colors: c,
            child: GroupDetailScreen(group: g, colors: c),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                    color: c.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.workspaces_rounded,
                    size: 19,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        '${g.branch} · ${g.level}',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill(
                  '${g.avgAtt}%',
                  tone: g.avgAtt >= 92
                      ? PillTone.success
                      : g.avgAtt >= 85
                      ? PillTone.warn
                      : PillTone.danger,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _gStat(
                  c,
                  Icons.person_rounded,
                  '${g.count}',
                  tr(context, 'unit_student'),
                ),
                _gStat(
                  c,
                  Icons.school_rounded,
                  g.teacher.split(' ').first,
                  tr(context, 'group_teacher'),
                ),
                _gStat(
                  c,
                  Icons.trending_down_rounded,
                  '${g.debtors}',
                  tr(context, 'f_debtor'),
                  color: g.debtors > 0 ? c.danger : c.success,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: c.muted),
                const SizedBox(width: 5),
                Text(
                  g.schedule,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 11,
                    color: c.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tr(context, 'group_avg')} ',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    color: c.muted,
                  ),
                ),
                Text(
                  '${g.avgAtt}%',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: attColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gStat(
    SfColors c,
    IconData icon,
    String value,
    String label, {
    Color? color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? c.muted),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color ?? c.ink,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 8.5,
                  color: c.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Group detail — header stats + the students belonging to the group.
class GroupDetailScreen extends StatelessWidget {
  final GroupInfo group;
  final SfColors colors;
  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final g = group;
    final members = AppScope.of(
      context,
    ).students.where((s) => s.group == g.name).toList();
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
            g.name,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${g.branch} · ${g.level} · ${g.schedule}',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, tr(context, 'anom_details')),
            SfCard(
              child: Column(
                children: [
                  _InfoRow(tr(context, 'group_teacher'), g.teacher),
                  _InfoRow(tr(context, 'stu_branch'), g.branch),
                  _InfoRow(tr(context, 'stu_level'), g.level),
                  _InfoRow(
                    tr(context, 'group_avg'),
                    '${g.avgAtt}%',
                    mono: true,
                  ),
                  _InfoRow(
                    tr(context, 'f_debtor'),
                    '${g.debtors}',
                    mono: true,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _setSec(c, '${members.length} ${tr(context, 'unit_student')}'),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < members.length; i++)
                    _StudentRow(s: members[i], last: i == members.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact circular action used in list toolbars.
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Interactive group status counters. Tapping one applies the matching filter
/// in the group list, so the summary is useful rather than decorative.
class _GroupStatusSummary extends StatelessWidget {
  final List<GroupInfo> groups;
  final ValueChanged<int> onSelect;
  const _GroupStatusSummary({required this.groups, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final active = groups.where((g) => g.status == 'active').length;
    final paused = groups.where((g) => g.status == 'paused').length;
    final closed = groups.where((g) => g.status == 'closed').length;
    final entries = [
      ('Faol', active, c.success, 1),
      ('Pauzada', paused, c.warn, 2),
      ('Yopilgan', closed, c.danger, 3),
    ];
    return Row(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          Expanded(
            child: InkWell(
              onTap: () => onSelect(entries[i].$4),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Text(
                      '${entries[i].$2}',
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: entries[i].$3,
                      ),
                    ),
                    Text(
                      entries[i].$1,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < entries.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

InputDecoration _managedInputDecoration(SfColors c, String label) =>
    InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: SfType.ui,
        fontSize: 12,
        color: c.muted,
      ),
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.danger, width: 1.6),
      ),
    );

class _ManagedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool requiredField;
  final int maxLines;
  const _ManagedTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.requiredField = false,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, color: c.ink),
        validator: requiredField
            ? (v) => v == null || v.trim().isEmpty ? 'Majburiy maydon' : null
            : null,
        decoration: _managedInputDecoration(c, label),
      ),
    );
  }
}

/// Full-screen admission page. It retains the fields entered by the CEO in
/// the in-memory AppStore until an API is connected.
class AdmitStudentScreen extends StatefulWidget {
  final SfColors colors;
  const AdmitStudentScreen({super.key, required this.colors});
  @override
  State<AdmitStudentScreen> createState() => _AdmitStudentScreenState();
}

class _AdmitStudentScreenState extends State<AdmitStudentScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _number = TextEditingController();
  final _phone = TextEditingController();
  final _backup = TextEditingController();
  final _parentName = TextEditingController();
  final _parentPhone = TextEditingController();
  final _parentBackup = TextEditingController();
  final _username = TextEditingController();
  String _branch = 'Yunusobod';
  String _group = '__none';
  String _gender = 'Male';

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _number,
      _phone,
      _backup,
      _parentName,
      _parentPhone,
      _parentBackup,
      _username,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final store = AppScope.of(context);
    final selectedGroup = _group == '__none' ? 'Qabul · yangi' : _group;
    store.addStudent(
      Student(
        '${_last.text.trim()} ${_first.text.trim()}',
        selectedGroup,
        100,
        'paid',
        0,
        studentNumber: _number.text.trim(),
        phone: _phone.text.trim(),
        backupPhone: _backup.text.trim().isEmpty ? null : _backup.text.trim(),
        parentName: _parentName.text.trim(),
        parentPhone: _parentPhone.text.trim(),
        parentBackupPhone: _parentBackup.text.trim().isEmpty
            ? null
            : _parentBackup.text.trim(),
        branch: _branch,
        username: _username.text.trim(),
        gender: _gender,
      ),
      branch: _branch,
    );
    Navigator.of(context).pop();
    _snack(
      context,
      'O‘quvchi muvaffaqiyatli qabul qilindi',
      bg: widget.colors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final groups = _groupsFrom(
      store.students,
      store.extraGroups,
    ).where((g) => g.branch == _branch).map((g) => g.name).toList();
    if (_group != '__none' && !groups.contains(_group)) _group = '__none';
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'O‘quvchi qabul qilish',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _setSec(c, 'O‘QUVCHI MA’LUMOTLARI'),
              _ManagedTextField(
                controller: _first,
                label: 'Ism',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _last,
                label: 'Familiya',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _number,
                label: 'Student number',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _phone,
                label: 'Telefon raqami',
                keyboardType: TextInputType.phone,
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _backup,
                label: 'Zaxira telefon (ixtiyoriy)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 4),
              _setSec(c, 'OTA-ONA'),
              _ManagedTextField(
                controller: _parentName,
                label: 'Ota-ona ismi',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _parentPhone,
                label: 'Ota-ona telefoni',
                keyboardType: TextInputType.phone,
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _parentBackup,
                label: 'Ikkinchi telefon (ixtiyoriy)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 4),
              _setSec(c, 'O‘QISH'),
              _ManagedSelect<String>(
                label: 'Filial',
                value: _branch,
                items: [for (final b in store.branches) b.name],
                onChanged: (v) => setState(() {
                  _branch = v;
                  _group = '__none';
                }),
              ),
              const SizedBox(height: 11),
              _ManagedSelect<String>(
                label: 'Guruh (ixtiyoriy)',
                value: _group,
                items: ['__none', ...groups],
                display: (v) => v == '__none' ? 'Guruh biriktirilmagan' : v,
                onChanged: (v) => setState(() => _group = v),
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: _username,
                label: 'Username',
                requiredField: true,
              ),
              _ManagedSelect<String>(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female'],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.check_rounded,
              label: 'O‘quvchini yaratish',
              primary: true,
              onTap: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagedSelect<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T)? display;
  const _ManagedSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.display,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, color: c.ink),
      decoration: _managedInputDecoration(c, label),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(display?.call(item) ?? '$item'),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Full mobile creation page for a teaching group. New groups appear in the
/// group screen immediately, including their status and branch filters.
class GroupCreateScreen extends StatefulWidget {
  final SfColors colors;
  const GroupCreateScreen({super.key, required this.colors});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _schedule = TextEditingController(text: 'Du · Cho · Ju · 16:00');
  String _branch = 'Yunusobod';
  String _teacher = _kTeachers.first;
  String _level = 'Intermediate';
  String _status = 'active';

  @override
  void dispose() {
    _name.dispose();
    _schedule.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    AppScope.of(context).addGroup(
      ManagedGroup(
        name: _name.text.trim(),
        branch: _branch,
        teacher: _teacher,
        schedule: _schedule.text.trim(),
        level: _level,
        status: _status,
      ),
    );
    Navigator.of(context).pop();
    _snack(context, 'Yangi guruh yaratildi', bg: widget.colors.success);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Yangi guruh',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _ManagedTextField(
                controller: _name,
                label: 'Guruh nomi',
                requiredField: true,
              ),
              _ManagedSelect(
                label: 'Filial',
                value: _branch,
                items: [for (final b in store.branches) b.name],
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox(height: 11),
              _ManagedSelect(
                label: 'O‘qituvchi',
                value: _teacher,
                items: _kTeachers,
                onChanged: (v) => setState(() => _teacher = v),
              ),
              const SizedBox(height: 11),
              _ManagedSelect(
                label: 'Daraja',
                value: _level,
                items: const ['Beginner', 'Intermediate', 'Advanced'],
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: _schedule,
                label: 'Jadval',
                requiredField: true,
              ),
              _ManagedSelect(
                label: 'Holat',
                value: _status,
                items: const ['active', 'paused', 'closed'],
                display: (v) => switch (v) {
                  'active' => 'Faol',
                  'paused' => 'Pauzada',
                  _ => 'Yopilgan',
                },
                onChanged: (v) => setState(() => _status = v),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.add_rounded,
              label: 'Guruh yaratish',
              primary: true,
              onTap: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standalone wrappers used from the full-section menu. The bottom tabs keep
/// their compact layout, while these routes have a proper mobile app bar.
class StudentsWorkspaceScreen extends StatelessWidget {
  final SfColors colors;
  const StudentsWorkspaceScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) => SfScaffold(
    colors: colors,
    title: 'O‘quvchilar',
    body: const StudentsScreen(),
  );
}

class GroupsWorkspaceScreen extends StatelessWidget {
  final SfColors colors;
  const GroupsWorkspaceScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) =>
      SfScaffold(colors: colors, title: 'Guruhlar', body: const GroupsScreen());
}

class HrWorkspaceScreen extends StatefulWidget {
  final SfColors colors;
  const HrWorkspaceScreen({super.key, required this.colors});
  @override
  State<HrWorkspaceScreen> createState() => _HrWorkspaceScreenState();
}

class _HrWorkspaceScreenState extends State<HrWorkspaceScreen> {
  final Map<String, String> _stage = {
    'Olimjon Rashidov': 'Applied',
    'Dilnoza Aliyeva': 'Applied',
    'Madina Tosheva': 'Interview',
    'Jasur Nazarov': 'Interview',
    'Nilufar Yusupova': 'Accepted',
    'Bekzod Aliyev': 'Rejected',
  };
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final candidateNames = _stage.keys
        .where((name) => name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    const stages = ['Applied', 'Interview', 'Accepted', 'Rejected'];
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'HR · Xodimlar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Create staff',
              icon: Icon(Icons.person_add_alt_1_rounded, color: c.primary),
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            _SearchField(
              hint: 'Xodim yoki nomzod qidirish',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SfStatTile(
                    'Jami xodim',
                    '${store.staff.length}',
                    c.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SfStatTile('Nomzodlar', '${_stage.length}', c.warn),
                ),
                const SizedBox(width: 8),
                Expanded(child: SfStatTile('Vakansiya', '7', c.danger)),
              ],
            ),
            const SizedBox(height: 16),
            _setSec(c, 'HIRING KANBAN · KARTANI USHLAB KO‘CHIRING'),
            SizedBox(
              height: 310,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final stage = stages[index];
                  final entries = candidateNames
                      .where((n) => _stage[n] == stage)
                      .toList();
                  return _HiringColumn(
                    title: stage,
                    people: entries,
                    tone: index == 0
                        ? c.primary
                        : index == 1
                        ? c.warn
                        : index == 2
                        ? c.success
                        : c.danger,
                    onDrop: (name) => setState(() => _stage[name] = stage),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, 'XODIMLAR'),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < store.staff.length; i++)
                    _StaffRow(
                      member: store.staff[i],
                      last: i == store.staff.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Create staff',
              primary: true,
              onTap: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ),
        ),
      ),
    );
  }
}

class _HiringColumn extends StatelessWidget {
  final String title;
  final List<String> people;
  final Color tone;
  final ValueChanged<String> onDrop;
  const _HiringColumn({
    required this.title,
    required this.people,
    required this.tone,
    required this.onDrop,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? tone.withValues(alpha: 0.10)
              : c.surface2,
          border: Border.all(color: candidates.isNotEmpty ? tone : c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
                Text(
                  '${people.length}',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 11,
                    color: c.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Expanded(
              child: ListView(
                children: [
                  for (final person in people)
                    _CandidateCard(name: person, tone: tone),
                  if (people.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text(
                          'Kartani bu yerga tashlang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 10.5,
                            color: c.muted,
                          ),
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
}

class _CandidateCard extends StatelessWidget {
  final String name;
  final Color tone;
  const _CandidateCard({required this.name, required this.tone});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final card = Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SfAvatar(name: name, size: 25, color: tone),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return LongPressDraggable<String>(
      data: name,
      // The drag feedback is inserted into Flutter's root Overlay. It is no
      // longer below the page's SfTheme, so provide the same theme explicitly.
      feedback: SfTheme(
        colors: c,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 160,
            child: Opacity(opacity: 0.88, child: card),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;
  final bool last;
  const _StaffRow({required this.member, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(StaffDetailScreen(member: member, colors: c))),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.surface2.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: c.border.withValues(alpha: 0.72)),
          ),
          child: Row(
            children: [
              SfAvatar(name: member.fullName, size: 40, color: c.primary),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${member.department} · ${member.branch}',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10.5,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: c.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create Staff / Create Teacher full-screen flow. It collects the requested
/// account, employment, subject and salary data before inserting a staff card.
class StaffCreateScreen extends StatefulWidget {
  final SfColors colors;
  const StaffCreateScreen({super.key, required this.colors});
  @override
  State<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends State<StaffCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _birthday = TextEditingController();
  final _hireDate = TextEditingController();
  final _subject = TextEditingController();
  final _qualification = TextEditingController();
  final _rate = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _gender = 'Male';
  String _branch = 'Yunusobod';
  String _department = 'Matematika';
  String _salary = 'Monthly';

  @override
  void dispose() {
    for (final c in [
      _username,
      _first,
      _last,
      _phone,
      _email,
      _birthday,
      _hireDate,
      _subject,
      _qualification,
      _rate,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _date(TextEditingController target) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (value != null) {
      setState(
        () => target.text =
            '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}',
      );
    }
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_password.text != _confirm.text) {
      _snack(context, 'Parollar bir xil emas', bg: widget.colors.danger);
      return;
    }
    AppScope.of(context).addStaff(
      StaffMember(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        username: _username.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        branch: _branch,
        department: _department,
        subject: _subject.text.trim(),
        qualification: _qualification.text.trim(),
        salaryType: _salary,
        rate: _rate.text.trim(),
        gender: _gender,
        hireDate: _hireDate.text.trim(),
      ),
    );
    Navigator.of(context).pop();
    _snack(context, 'Xodim yaratildi', bg: widget.colors.success);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final branches = AppScope.of(context).branches.map((b) => b.name).toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Create staff',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _setSec(c, 'ACCOUNT'),
              _ManagedTextField(
                controller: _username,
                label: 'Username',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _first,
                label: 'First name',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _last,
                label: 'Last name',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _phone,
                label: 'Phone',
                keyboardType: TextInputType.phone,
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _email,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              _DateInput(
                label: 'Birthday',
                controller: _birthday,
                onTap: () => _date(_birthday),
              ),
              const SizedBox(height: 11),
              _ManagedSelect(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female'],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),
              _setSec(c, 'EMPLOYMENT'),
              _ManagedSelect(
                label: 'Branch',
                value: _branch,
                items: branches,
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox(height: 11),
              _ManagedSelect(
                label: 'Department',
                value: _department,
                items: const [
                  'Matematika',
                  'English',
                  'Science',
                  'Reception',
                  'Marketing',
                ],
                onChanged: (v) => setState(() => _department = v),
              ),
              const SizedBox(height: 11),
              _DateInput(
                label: 'Hire date',
                controller: _hireDate,
                onTap: () => _date(_hireDate),
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: _subject,
                label: 'Subject',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _qualification,
                label: 'Qualifications',
                requiredField: true,
              ),
              _ManagedSelect(
                label: 'Salary type',
                value: _salary,
                items: const ['Monthly', 'Hourly'],
                onChanged: (v) => setState(() => _salary = v),
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: _rate,
                label: 'Rate',
                keyboardType: TextInputType.number,
                requiredField: true,
              ),
              const SizedBox(height: 4),
              _setSec(c, 'SECURITY'),
              _ManagedTextField(
                controller: _password,
                label: 'New password',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: _confirm,
                label: 'Confirm password',
                requiredField: true,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.check_rounded,
              label: 'Create staff',
              primary: true,
              onTap: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final bool requiredField;
  final IconData icon;
  const _DateInput({
    required this.label,
    required this.controller,
    required this.onTap,
    this.requiredField = false,
    this.icon = Icons.calendar_month_rounded,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IgnorePointer(
        child: TextFormField(
          controller: controller,
          style: TextStyle(fontFamily: SfType.ui, color: c.ink),
          validator: requiredField
              ? (value) => value == null || value.trim().isEmpty
                    ? 'Majburiy maydon'
                    : null
              : null,
          decoration: _managedInputDecoration(c, label).copyWith(
            suffixIcon: Icon(icon, color: c.primary),
          ),
        ),
      ),
    );
  }
}

class StaffDetailScreen extends StatelessWidget {
  final StaffMember member;
  final SfColors colors;
  const StaffDetailScreen({
    super.key,
    required this.member,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            member.fullName,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: SfAvatar(
                name: member.fullName,
                size: 78,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 9),
            Center(
              child: Text(
                member.fullName,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Username', member.username),
                  _InfoRow('Phone', member.phone),
                  _InfoRow('Email', member.email ?? '—'),
                  _InfoRow('Gender', member.gender),
                  _InfoRow('Branch', member.branch),
                  _InfoRow('Department', member.department),
                  _InfoRow('Subject', member.subject),
                  _InfoRow('Qualifications', member.qualification),
                  _InfoRow(
                    'Salary',
                    '${member.salaryType} · ${member.rate}',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SfStatTile('Guruhlar', '2', c.primary)),
                const SizedBox(width: 8),
                Expanded(child: SfStatTile('O‘quvchilar', '34', c.success)),
                const SizedBox(width: 8),
                Expanded(child: SfStatTile('Davomat', '93%', c.warn)),
              ],
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  const SfCardHeader('Guruhlar va ko‘rsatkichlar'),
                  _InfoRow(
                    '1-guruh',
                    '${member.subject} · Dushanba / Chorshanba',
                  ),
                  _InfoRow(
                    '2-guruh',
                    '${member.subject} · Seshanba / Payshanba',
                  ),
                  _InfoRow('Reyting', '★ 4.9 · yuqori natija', last: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SfButton(
              icon: Icons.password_rounded,
              label: 'Parolni o‘zgartirish',
              primary: false,
              onTap: () => _snack(
                context,
                'Parolni o‘zgartirish sahifasi API bilan faollashadi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeachersWorkspaceScreen extends StatefulWidget {
  final SfColors colors;
  const TeachersWorkspaceScreen({super.key, required this.colors});
  @override
  State<TeachersWorkspaceScreen> createState() =>
      _TeachersWorkspaceScreenState();
}

class _TeachersWorkspaceScreenState extends State<TeachersWorkspaceScreen> {
  String query = '';
  int filter = 0;
  final TextEditingController _referenceSearch = TextEditingController();

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    return _ReferenceTeachersPage(state: this);
  }

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = widget.colors;
    final staff = AppScope.of(context).staff.where((member) {
      final isTeacher = member.subject.toLowerCase() != 'operations';
      if (filter == 1 && !isTeacher) return false;
      if (filter == 2 && member.salaryType != 'Monthly') return false;
      final q = query.toLowerCase();
      return q.isEmpty ||
          member.fullName.toLowerCase().contains(q) ||
          member.department.toLowerCase().contains(q);
    }).toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'O‘qituvchilar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.person_add_alt_1_rounded, color: c.primary),
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            _SearchField(
              hint: 'O‘qituvchi qidirish',
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 9),
            _FilterChips(
              items: const ['Hammasi', 'O‘qituvchi', 'Oylik'],
              selected: filter,
              onSelect: (v) => setState(() => filter = v),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < staff.length; i++)
                    _StaffRow(member: staff[i], last: i == staff.length - 1),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'O‘qituvchi qo‘shish',
              primary: true,
              onTap: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _referenceSearch.dispose();
    super.dispose();
  }
}

class _ReferenceTeachersPage extends StatelessWidget {
  const _ReferenceTeachersPage({required this.state});

  final _TeachersWorkspaceScreenState state;

  @override
  Widget build(BuildContext context) {
    final c = state.widget.colors;
    final teachers = AppScope.of(context).staff.where((member) {
      final isTeacher = member.subject.toLowerCase() != 'operations';
      if (state.filter == 1 && !isTeacher) return false;
      if (state.filter == 2 && member.salaryType != 'Monthly') return false;
      final q = state.query.toLowerCase();
      return q.isEmpty ||
          member.fullName.toLowerCase().contains(q) ||
          member.department.toLowerCase().contains(q);
    }).toList();
    final teachingCount = AppScope.of(context).staff
        .where((member) => member.subject.toLowerCase() != 'operations')
        .length;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            RefLargeHeader(
              eyebrow: '$teachingCount XODIM',
              title: 'O‘qituvchilar',
              subtitle: 'Jamoa, yo‘nalish va natijalarni boshqaring',
              actions: [
                RefIconAction(
                  icon: Icons.person_add_alt_1_rounded,
                  tooltip: 'O‘qituvchi qo‘shish',
                  onPressed: () => Navigator.of(
                    context,
                  ).push(sfPageRoute(StaffCreateScreen(colors: c))),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                children: [
                  _ReferenceDashboardContext(showBranches: false),
                  const SizedBox(height: 12),
                  RefSearchField(
                    controller: state._referenceSearch,
                    hint: 'O‘qituvchi qidirish',
                    onChanged: (value) =>
                        state._update(() => state.query = value),
                    suffix: state.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Tozalash',
                            onPressed: () => state._update(() {
                              state._referenceSearch.clear();
                              state.query = '';
                            }),
                            icon: Icon(Icons.close_rounded, color: c.muted),
                          ),
                  ),
                  const SizedBox(height: 10),
                  RefSegmentedControl<int>(
                    values: const [0, 1, 2],
                    selected: state.filter,
                    labelOf: (value) =>
                        const ['Hammasi', 'O‘qituvchi', 'Oylik'][value],
                    onChanged: (value) =>
                        state._update(() => state.filter = value),
                  ),
                  const SizedBox(height: 16),
                  RefAdaptiveGrid(
                    minCellWidth: 152,
                    children: [
                      RefMetricCard(
                        label: 'Jami',
                        value: '${teachers.length}',
                        icon: Icons.groups_rounded,
                        tone: RefMetricTone.primary,
                      ),
                      RefMetricCard(
                        label: 'Reyting',
                        value: '4.8',
                        icon: Icons.star_rounded,
                        tone: RefMetricTone.accent,
                        detail: 'Jamoa o‘rtachasi',
                      ),
                      RefMetricCard(
                        label: 'Oylik',
                        value:
                            '${teachers.where((member) => member.salaryType == 'Monthly').length}',
                        icon: Icons.payments_outlined,
                        tone: RefMetricTone.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  RefSectionHeader(
                    title: 'Jamoa ro‘yxati',
                    subtitle: '${teachers.length} ta mos natija',
                  ),
                  const SizedBox(height: 8),
                  if (teachers.isEmpty)
                    _ReferenceStudentEmpty(hasQuery: state.query.isNotEmpty)
                  else
                    for (var index = 0; index < teachers.length; index++) ...[
                      RefStaggeredReveal(
                        order: index,
                        child: _ReferenceTeacherCard(
                          member: teachers[index],
                          colors: c,
                          rank: index + 1,
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: RefButton(
                label: 'O‘qituvchi qo‘shish',
                block: true,
                leading: Icons.person_add_alt_1_rounded,
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(StaffCreateScreen(colors: c))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceTeacherCard extends StatelessWidget {
  const _ReferenceTeacherCard({
    required this.member,
    required this.colors,
    required this.rank,
  });

  final StaffMember member;
  final SfColors colors;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final rating = (4.9 - (rank - 1) * .12).clamp(4.2, 4.9);
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(StaffDetailScreen(member: member, colors: colors))),
      borderRadius: RefRadius.lg,
      semanticLabel: 'O‘qituvchi ${member.fullName}',
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Column(
          children: [
            Row(
              children: [
                SfAvatar(name: member.fullName, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 15,
                          weight: FontWeight.w800,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${member.subject} · ${member.branch}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                RefPill(
                  label: '#$rank',
                  tone: rank == 1 ? RefPillTone.accent : RefPillTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            RefAdaptiveGrid(
              minCellWidth: 94,
              spacing: 7,
              children: [
                _ReferenceTeacherMetric(
                  label: 'REYTING',
                  value: rating.toStringAsFixed(1),
                  color: colors.accentInk,
                  icon: Icons.star_rounded,
                ),
                _ReferenceTeacherMetric(
                  label: 'DAVOMAT',
                  value: '${99 - rank}%',
                  color: colors.success,
                  icon: Icons.how_to_reg_rounded,
                ),
                _ReferenceTeacherMetric(
                  label: 'STATUS',
                  value: member.salaryType,
                  color: colors.primary,
                  icon: Icons.verified_user_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceTeacherMetric extends StatelessWidget {
  const _ReferenceTeacherMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: RefRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RefType.mono(
                size: 12.5,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: RefType.eyebrow(size: 7.5, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

/// CEO comparison screen. Two branch selectors drive every metric in the
/// comparison table, so it can be extended to server values later.
class BranchComparisonScreen extends StatefulWidget {
  final SfColors colors;
  const BranchComparisonScreen({super.key, required this.colors});
  @override
  State<BranchComparisonScreen> createState() => _BranchComparisonScreenState();
}

class _BranchComparisonScreenState extends State<BranchComparisonScreen> {
  String? a;
  String? b;
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final branches = AppScope.of(context).branches;
    if (branches.isEmpty) return const SizedBox.shrink();
    a ??= branches.first.name;
    b ??= branches.length > 1 ? branches[1].name : branches.first.name;
    final first = branches.firstWhere((item) => item.name == a);
    final second = branches.firstWhere((item) => item.name == b);
    final rows = [
      (
        'O‘quvchilar',
        '${first.students}',
        '${second.students}',
        Icons.groups_rounded,
      ),
      (
        'Daromad',
        fmtMoneyMln(first.revenue),
        fmtMoneyMln(second.revenue),
        Icons.payments_rounded,
      ),
      (
        'Davomat',
        '${first.attendance}%',
        '${second.attendance}%',
        Icons.fact_check_rounded,
      ),
      (
        'Xodimlar',
        '${(first.students / 31).round()}',
        '${(second.students / 31).round()}',
        Icons.badge_rounded,
      ),
      (
        'Teacher rating',
        first.attendance >= 92 ? '4.9' : '4.6',
        second.attendance >= 92 ? '4.9' : '4.5',
        Icons.star_rounded,
      ),
    ];
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Branch comparison',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ManagedSelect(
                    label: 'Branch A',
                    value: a!,
                    items: [for (final branch in branches) branch.name],
                    onChanged: (v) => setState(() => a = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManagedSelect(
                    label: 'Branch B',
                    value: b!,
                    items: [for (final branch in branches) branch.name],
                    onChanged: (v) => setState(() => b = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            first.name,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontWeight: FontWeight.w800,
                              color: first.mark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            second.name,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontWeight: FontWeight.w800,
                              color: second.mark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (int i = 0; i < rows.length; i++)
                    _ComparisonRow(
                      label: rows[i].$1,
                      left: rows[i].$2,
                      right: rows[i].$3,
                      icon: rows[i].$4,
                      last: i == rows.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, 'DAROMAD TENDENSIYASI'),
            SfCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    LegendRow(
                      first.mark,
                      first.name,
                      fmtMoneyMln(first.revenue),
                    ),
                    LegendRow(
                      second.mark,
                      second.name,
                      fmtMoneyMln(second.revenue),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: AreaChart(
                        data: [
                          first.revenue / 1e6,
                          second.revenue / 1e6,
                          (first.revenue + second.revenue) / 2e6,
                          first.revenue / 1e6 * 1.04,
                        ],
                        color: c.primary,
                      ),
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

class _ComparisonRow extends StatelessWidget {
  final String label, left, right;
  final IconData icon;
  final bool last;
  const _ComparisonRow({
    required this.label,
    required this.left,
    required this.right,
    required this.icon,
    required this.last,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: c.muted),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      color: c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityHistoryScreen extends StatefulWidget {
  final SfColors colors;
  const ActivityHistoryScreen({super.key, required this.colors});
  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    const kinds = ['Hammasi', 'student', 'group', 'staff', 'payment', 'audit'];
    final items = filter == 0
        ? store.activities
        : store.activities.where((item) => item.kind == kinds[filter]).toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'History',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            _FilterChips(
              items: const [
                'Hammasi',
                'O‘quvchi',
                'Guruh',
                'Xodim',
                'To‘lov',
                'Audit',
              ],
              selected: filter,
              onSelect: (v) => setState(() => filter = v),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _ActivityRow(event: items[i], last: i == items.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEvent event;
  final bool last;
  const _ActivityRow({required this.event, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(sfPageRoute(ActivityDetailScreen(event: event, colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
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
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(event.icon, size: 17, color: c.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    event.detail,
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
            Text(
              event.time,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 9.5,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityDetailScreen extends StatelessWidget {
  final ActivityEvent event;
  final SfColors colors;
  const ActivityDetailScreen({
    super.key,
    required this.event,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Event details',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SfCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 18),
                Icon(event.icon, size: 34, color: c.primary),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  event.detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow('Vaqt', event.time, last: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ParentsWorkspaceScreen extends StatefulWidget {
  final SfColors colors;
  const ParentsWorkspaceScreen({super.key, required this.colors});
  @override
  State<ParentsWorkspaceScreen> createState() => _ParentsWorkspaceScreenState();
}

class _ParentsWorkspaceScreenState extends State<ParentsWorkspaceScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final children = [...AppScope.of(context).students, ...kExitedStudents];
    final byParent = <String, List<Student>>{};
    for (final student in children) {
      byParent
          .putIfAbsent(studentProfile(student).fatherName, () => [])
          .add(student);
    }
    final entries = byParent.entries.where((entry) {
      final q = query.toLowerCase();
      return q.isEmpty ||
          entry.key.toLowerCase().contains(q) ||
          entry.value.any((s) => s.name.toLowerCase().contains(q));
    }).toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Ota-onalar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            _SearchField(
              hint: 'Ota-ona yoki farzand qidirish',
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < entries.length; i++)
                    _ParentRow(
                      name: entries[i].key,
                      children: entries[i].value,
                      last: i == entries.length - 1,
                      colors: c,
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

class _ParentRow extends StatelessWidget {
  final String name;
  final List<Student> children;
  final bool last;
  final SfColors colors;
  const _ParentRow({
    required this.name,
    required this.children,
    required this.last,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          ParentDetailScreen(name: name, children: children, colors: c),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SfAvatar(name: name, size: 34, color: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    '${children.length} farzand · ${studentProfile(children.first).phone}',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10.5,
                      color: c.muted,
                    ),
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

class ParentDetailScreen extends StatelessWidget {
  final String name;
  final List<Student> children;
  final SfColors colors;
  const ParentDetailScreen({
    super.key,
    required this.name,
    required this.children,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final profile = studentProfile(children.first);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            name,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Full name', name),
                  _InfoRow('Phone', profile.fatherPhone),
                  _InfoRow('Branch', profile.branch, last: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, 'FARZANDLARI · ${children.length}'),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++)
                    _StudentRow(s: children[i], last: i == children.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DepartmentsWorkspaceScreen extends StatefulWidget {
  final SfColors colors;
  const DepartmentsWorkspaceScreen({super.key, required this.colors});
  @override
  State<DepartmentsWorkspaceScreen> createState() =>
      _DepartmentsWorkspaceScreenState();
}

class _DepartmentsWorkspaceScreenState
    extends State<DepartmentsWorkspaceScreen> {
  String query = '';

  Future<void> _create() async {
    final result = await Navigator.of(context).push<DepartmentRecord>(
      sfPageRoute(DepartmentCreateScreen(colors: widget.colors)),
    );
    if (result != null && mounted) {
      AppScope.of(context).addDepartment(result);
    }
  }

  Future<void> _delete(DepartmentRecord department) async {
    final c = widget.colors;
    final hasStaff = AppScope.of(
      context,
    ).staffForDepartment(department).isNotEmpty;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Delete ${department.name}?',
          style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w800),
        ),
        content: Text(
          hasStaff
              ? 'This department still has employees. Transfer or dismiss them first.'
              : 'The department history will be removed from this local preview.',
          style: TextStyle(fontFamily: SfType.ui, color: c.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: hasStaff
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      setState(() => AppScope.of(context).departments.remove(department));
      AppScope.of(context).logActivity(
        icon: Icons.delete_outline_rounded,
        title: 'Bo‘lim o‘chirildi',
        detail: department.name,
        kind: 'staff',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final list = store.departments
        .where(
          (d) =>
              d.name.toLowerCase().contains(query.toLowerCase()) ||
              d.manager.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Departments',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_rounded, color: c.primary),
              onPressed: _create,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SearchField(
              hint: 'Department yoki manager qidirish',
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            for (final department in list)
              _DepartmentCard(
                department: department,
                staffCount: store.staffForDepartment(department).length,
                onDelete: () => _delete(department),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.add_rounded,
              label: 'New department',
              primary: true,
              onTap: _create,
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final DepartmentRecord department;
  final int staffCount;
  final VoidCallback onDelete;
  const _DepartmentCard({
    required this.department,
    required this.staffCount,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          sfPageRoute(
            DepartmentDetailScreen(department: department, colors: c),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.folder_rounded, color: c.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      '${department.manager} · $staffCount xodim',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10.5,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: c.danger,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DepartmentCreateScreen extends StatefulWidget {
  final SfColors colors;
  const DepartmentCreateScreen({super.key, required this.colors});
  @override
  State<DepartmentCreateScreen> createState() => _DepartmentCreateScreenState();
}

class _DepartmentCreateScreenState extends State<DepartmentCreateScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final manager = TextEditingController();
  final description = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    manager.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'New department',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ManagedTextField(
                controller: name,
                label: 'Department name',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: manager,
                label: 'Manager',
                requiredField: true,
              ),
              _ManagedTextField(
                controller: description,
                label: 'Description',
                requiredField: true,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.check_rounded,
              label: 'Create department',
              primary: true,
              onTap: () {
                if (form.currentState!.validate()) {
                  Navigator.of(context).pop(
                    DepartmentRecord(
                      name: name.text.trim(),
                      manager: manager.text.trim(),
                      description: description.text.trim(),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class DepartmentDetailScreen extends StatefulWidget {
  final DepartmentRecord department;
  final SfColors colors;
  const DepartmentDetailScreen({
    super.key,
    required this.department,
    required this.colors,
  });
  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  Future<void> _transfer(StaffMember member, AppStore store) async {
    final targets = store.departments
        .where((department) => department.name != widget.department.name)
        .toList(growable: false);
    if (targets.isEmpty) return;
    final target = await showModalBottomSheet<DepartmentRecord>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: widget.colors,
        child: _SheetShell(
          children: [
            Text(
              '${member.fullName} ni ko‘chirish',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.colors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final department in targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.folder_rounded,
                  color: widget.colors.primary,
                ),
                title: Text(
                  department.name,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.ink,
                  ),
                ),
                subtitle: Text(
                  department.manager,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    color: widget.colors.muted,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(department),
              ),
          ],
        ),
      ),
    );
    if (target != null && mounted) {
      store.transferStaff(member, target);
      _snack(context, '✓ ${member.fullName} → ${target.name}');
    }
  }

  Future<void> _appointManager(AppStore store) async {
    final candidates = store.staff;
    if (candidates.isEmpty) {
      _snack(context, 'Avval HR bo‘limiga xodim qo‘shing');
      return;
    }
    final selected = await showModalBottomSheet<StaffMember>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: widget.colors,
        child: _SheetShell(
          children: [
            Text(
              'Yangi rahbarni tanlang',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.colors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final member in candidates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SfAvatar(name: member.fullName, size: 34),
                title: Text(
                  member.fullName,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.ink,
                  ),
                ),
                subtitle: Text(
                  '${member.qualification} · ${member.department}',
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    color: widget.colors.muted,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(member),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      store.appointDepartmentManager(widget.department, selected);
      _snack(context, '✓ ${selected.fullName} rahbar etib tayinlandi');
    }
  }

  Future<void> _dismiss(StaffMember member, AppStore store) async {
    final c = widget.colors;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          '${member.fullName} bo‘shatilsinmi?',
          style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Xodim barcha Department va HR ro‘yxatlaridan olib tashlanadi.',
          style: TextStyle(fontFamily: SfType.ui, color: c.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Bo‘shatish', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      store.dismissStaff(member);
      _snack(context, '✓ ${member.fullName} ishdan bo‘shatildi');
    }
  }

  int _studentsForDepartment(AppStore store) {
    return store.students.where((student) {
      final group = student.group.toLowerCase();
      if (widget.department.name == 'English') {
        return group.contains('ingliz') || group.contains('ielts');
      }
      if (widget.department.name == 'Reception') return false;
      return !group.contains('ingliz') && !group.contains('ielts');
    }).length;
  }

  double _ratingForDepartment(AppStore store) {
    final students = _studentsForDepartment(store);
    if (students == 0) return 4.7;
    final relevant = store.students.where((student) {
      final group = student.group.toLowerCase();
      return widget.department.name == 'English'
          ? group.contains('ingliz') || group.contains('ielts')
          : widget.department.name == 'Reception'
          ? false
          : !group.contains('ingliz') && !group.contains('ielts');
    });
    final average =
        relevant.fold<int>(0, (sum, student) => sum + student.attendance) /
        students;
    return (4 + (average - 80) / 100).clamp(4.0, 5.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final staff = store.staffForDepartment(widget.department);
    final students = _studentsForDepartment(store);
    final groups = students == 0
        ? 0
        : store.students
              .where((student) {
                final group = student.group.toLowerCase();
                return widget.department.name == 'English'
                    ? group.contains('ingliz') || group.contains('ielts')
                    : widget.department.name == 'Reception'
                    ? false
                    : !group.contains('ingliz') && !group.contains('ielts');
              })
              .map((student) => student.group)
              .toSet()
              .length;
    final teacherCount = staff
        .where((member) => member.subject != 'Operations')
        .length;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            widget.department.name,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.manage_accounts_rounded, color: c.primary),
              tooltip: 'Yangi rahbar',
              onPressed: () => _appointManager(store),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Manager', widget.department.manager),
                  _InfoRow(
                    'Description',
                    widget.department.description,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, 'DEPARTMENT STATISTICS'),
            Row(
              children: [
                Expanded(
                  child: _DetailStat('Xodimlar', '${staff.length}', c.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailStat(
                    'O‘rtacha reyting',
                    '★ ${_ratingForDepartment(store).toStringAsFixed(1)}',
                    c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('O‘quvchilar', '$students'),
                  _InfoRow('O‘qituvchilar', '$teacherCount'),
                  _InfoRow('Guruhlar', '$groups', last: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _setSec(c, 'TEACHERS / STAFF'),
            if (staff.isEmpty)
              _EmptyState(
                icon: Icons.badge_outlined,
                title: 'Xodimlar yo‘q',
                sub: 'HR dan xodim qo‘shing yoki boshqa bo‘limdan ko‘chiring.',
              )
            else
              SfCard(
                child: Column(
                  children: [
                    for (int i = 0; i < staff.length; i++)
                      _DepartmentStaffRow(
                        member: staff[i],
                        manager: widget.department.manager == staff[i].fullName,
                        last: i == staff.length - 1,
                        onTransfer: () => _transfer(staff[i], store),
                        onDismiss: () => _dismiss(staff[i], store),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            _setSec(c, 'O‘ZGARISHLAR TARIXI'),
            SfCard(
              child: Column(
                children: [
                  if (widget.department.history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Hali o‘zgarishlar yo‘q',
                        style: TextStyle(fontFamily: SfType.ui, color: c.muted),
                      ),
                    )
                  else
                    for (int i = 0; i < widget.department.history.length; i++)
                      _DepartmentHistoryRow(
                        change: widget.department.history[i],
                        last: i == widget.department.history.length - 1,
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

class _DepartmentStaffRow extends StatelessWidget {
  final StaffMember member;
  final bool manager;
  final bool last;
  final VoidCallback onTransfer;
  final VoidCallback onDismiss;
  const _DepartmentStaffRow({
    required this.member,
    required this.manager,
    required this.last,
    required this.onTransfer,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          SfAvatar(name: member.fullName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                    ),
                    if (manager) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: c.accent,
                      ),
                    ],
                  ],
                ),
                Text(
                  '${member.qualification} · ${member.subject}',
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, color: c.muted),
            onSelected: (action) {
              if (action == 'transfer') onTransfer();
              if (action == 'dismiss') onDismiss();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'transfer',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.swap_horiz_rounded),
                  title: Text('Boshqa bo‘limga ko‘chirish'),
                ),
              ),
              const PopupMenuItem(
                value: 'dismiss',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_remove_rounded, color: Colors.red),
                  title: Text('Ishdan bo‘shatish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepartmentHistoryRow extends StatelessWidget {
  final DepartmentChange change;
  final bool last;
  const _DepartmentHistoryRow({required this.change, required this.last});

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
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(change.icon, size: 16, color: c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.title,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  change.detail,
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
            change.time,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 9.5,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

enum MeetingStatus { today, scheduled, completed }

/// A meeting remains small enough for the demo data layer, but now carries the
/// information a manager needs to actually run it: status, RSVP progress,
/// agenda, owner and format.
class MeetingDraft {
  final String title, date, time, location, participants, description;
  final MeetingStatus status;
  final int confirmedParticipants;
  final List<String> agenda;
  final String owner;
  final String format;
  final int durationMinutes;
  final bool notifyParticipants;

  const MeetingDraft(
    this.title,
    this.date,
    this.time,
    this.location,
    this.participants,
    this.description, {
    this.status = MeetingStatus.scheduled,
    this.confirmedParticipants = 0,
    this.agenda = const [],
    this.owner = 'Dilnoza Yo‘ldosheva',
    this.format = 'Ofisda',
    this.durationMinutes = 60,
    this.notifyParticipants = true,
  });

  int get participantCount {
    final match = RegExp(r'\d+').firstMatch(participants);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  String get key => '$title|$date|$time';
}

String _meetingStatusLabel(MeetingStatus status) => switch (status) {
  MeetingStatus.today => 'Bugun',
  MeetingStatus.scheduled => 'Rejalashtirilgan',
  MeetingStatus.completed => 'Yakunlangan',
};

PillTone _meetingStatusTone(MeetingStatus status) => switch (status) {
  MeetingStatus.today => PillTone.primary,
  MeetingStatus.scheduled => PillTone.accent,
  MeetingStatus.completed => PillTone.success,
};

IconData _meetingStatusIcon(MeetingStatus status) => switch (status) {
  MeetingStatus.today => Icons.alarm_rounded,
  MeetingStatus.scheduled => Icons.event_available_rounded,
  MeetingStatus.completed => Icons.task_alt_rounded,
};

class MeetingsWorkspaceScreen extends StatefulWidget {
  final SfColors colors;
  const MeetingsWorkspaceScreen({super.key, required this.colors});
  @override
  State<MeetingsWorkspaceScreen> createState() =>
      _MeetingsWorkspaceScreenState();
}

class _MeetingsWorkspaceScreenState extends State<MeetingsWorkspaceScreen> {
  final List<MeetingDraft> meetings = [
    const MeetingDraft(
      'Haftalik filial yig‘ilishi',
      '19.07.2026',
      '17:00',
      'Konferens zal',
      'Butun filial · 16',
      'Haftalik ko‘rsatkichlar va keyingi haftaga mas’ullar.',
      status: MeetingStatus.today,
      confirmedParticipants: 12,
      agenda: [
        'Davomat va to‘lovlar bo‘yicha yakun',
        'Xavf ostidagi guruhlar',
        'Keyingi haftaga mas’ullar',
      ],
      durationMinutes: 75,
    ),
    const MeetingDraft(
      'Matematika · metodik kengash',
      '20.07.2026',
      '14:00',
      'Zoom',
      'Matematika bo‘limi · 12',
      'Yangi modul, imtihon natijalari va dars kuzatuvi.',
      confirmedParticipants: 8,
      agenda: [
        'Iyul moduliga tayyorgarlik',
        '9-B natijalari',
        'Ochiq darslar jadvali',
      ],
      owner: 'Nigora Karimova',
      format: 'Onlayn',
      durationMinutes: 60,
    ),
    const MeetingDraft(
      'Sotuv natijalari · oylik',
      '23.07.2026',
      '11:00',
      '301-xona',
      'Sotuv va marketing · 5',
      'Iyul voronkasi, konversiya va yangi kanallar.',
      confirmedParticipants: 4,
      agenda: [
        'Lidlar manbasi',
        'Konversiya rejasi',
        'Avgust kampaniyasi',
      ],
      owner: 'Gulnora Saidova',
      durationMinutes: 45,
    ),
    const MeetingDraft(
      'Yangi o‘qituvchilar treningi',
      '16.07.2026',
      '10:00',
      'O‘quv zal',
      'Tanlangan jamoa · 6',
      'Onboarding yakunlandi, materiallar yuborildi.',
      status: MeetingStatus.completed,
      confirmedParticipants: 6,
      agenda: [
        'Platformaga kirish',
        'Davomat standarti',
        'Ota-ona bilan aloqa',
      ],
      owner: 'Dilnoza Yo‘ldosheva',
      durationMinutes: 90,
    ),
  ];
  final Set<String> _remindersSent = <String>{};
  int _filter = 0;

  List<MeetingDraft> get _visibleMeetings => switch (_filter) {
    1 => meetings.where((meeting) => meeting.status == MeetingStatus.today).toList(),
    2 => meetings
        .where((meeting) => meeting.status != MeetingStatus.completed)
        .toList(),
    3 => meetings
        .where((meeting) => meeting.status == MeetingStatus.completed)
        .toList(),
    _ => meetings,
  };

  Future<void> _create() async {
    final result = await Navigator.of(context).push<MeetingDraft>(
      sfPageRoute(MeetingCreateScreen(colors: widget.colors)),
    );
    if (result != null && mounted) {
      setState(() => meetings.insert(0, result));
      _snack(
        context,
        result.notifyParticipants
            ? 'Yig‘ilish rejalashtirildi, eslatma yuboriladi'
            : 'Yig‘ilish rejalashtirildi',
        bg: widget.colors.success,
      );
    }
  }

  Future<void> _open(MeetingDraft meeting) => Navigator.of(context).push(
    sfPageRoute(
      MeetingDetailScreen(
        meeting: meeting,
        colors: widget.colors,
        reminderSent: _remindersSent.contains(meeting.key),
        onReminderSent: () => setState(() => _remindersSent.add(meeting.key)),
        onCancel: meeting.status == MeetingStatus.completed
            ? null
            : () => setState(() => meetings.remove(meeting)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final todayCount = meetings
        .where((meeting) => meeting.status == MeetingStatus.today)
        .length;
    final upcomingCount = meetings
        .where((meeting) => meeting.status != MeetingStatus.completed)
        .length;
    final confirmations = meetings.fold<int>(
      0,
      (total, meeting) => total + meeting.confirmedParticipants,
    );
    final visible = _visibleMeetings;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Yig‘ilishlar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_rounded, color: c.primary),
              onPressed: _create,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.primary, c.primary.withValues(alpha: .7)],
                ),
                borderRadius: BorderRadius.circular(20),
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
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Jamoa ritmi nazorat ostida',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yig‘ilish, qatnashuvchilar va keyingi qadamlarni bitta joyda boshqaring.',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: .87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MeetingSummaryCell(
                    label: 'BUGUN',
                    value: '$todayCount',
                    icon: Icons.alarm_rounded,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MeetingSummaryCell(
                    label: 'KELGUSI',
                    value: '$upcomingCount',
                    icon: Icons.event_available_rounded,
                    color: c.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MeetingSummaryCell(
                    label: 'TASDIQLADI',
                    value: '$confirmations',
                    icon: Icons.how_to_reg_rounded,
                    color: c.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'KO‘RINISH',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final item in const [
                  (0, 'Barchasi'),
                  (1, 'Bugun'),
                  (2, 'Kelgusi'),
                  (3, 'Yakunlangan'),
                ])
                  FilterChip(
                    label: Text(item.$2),
                    selected: _filter == item.$1,
                    onSelected: (_) => setState(() => _filter = item.$1),
                    showCheckmark: false,
                    selectedColor: c.primarySoft,
                    backgroundColor: c.surface,
                    side: BorderSide(
                      color: _filter == item.$1 ? c.primary : c.border,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _filter == item.$1 ? c.primaryInk : c.ink2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YIG‘ILISHLAR',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .55,
                      color: c.muted,
                    ),
                  ),
                ),
                Text(
                  '${visible.length} ta',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const _EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Bu ko‘rinishda yig‘ilish yo‘q',
                sub: 'Yangi uchrashuvni rejalashtiring yoki boshqa filtrni tanlang.',
              )
            else
              for (final meeting in visible)
                _MeetingCard(
                  meeting: meeting,
                  reminderSent: _remindersSent.contains(meeting.key),
                  onTap: () => _open(meeting),
                ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.event_available_rounded,
              label: 'Schedule meeting',
              primary: true,
              onTap: _create,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingDraft meeting;
  final bool reminderSent;
  final VoidCallback onTap;
  const _MeetingCard({
    required this.meeting,
    required this.reminderSent,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final day = meeting.date.split('.').first;
    final total = meeting.participantCount;
    final confirmed = total == 0
        ? 0.0
        : (meeting.confirmedParticipants / total).clamp(0, 1).toDouble();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.primary,
                      ),
                    ),
                    Text(
                      meeting.date.split('.').elementAtOrNull(1) ?? '',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: c.primaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pill(
                          _meetingStatusLabel(meeting.status),
                          tone: _meetingStatusTone(meeting.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meeting.time} · ${meeting.location} · ${meeting.format}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10.5,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 14, color: c.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${meeting.confirmedParticipants}/$total tasdiqladi · ${meeting.participants}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: c.ink2,
                            ),
                          ),
                        ),
                        if (reminderSent)
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 15,
                            color: c.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: confirmed,
                        minHeight: 5,
                        color: c.success,
                        backgroundColor: c.surface2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingSummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MeetingSummaryCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class MeetingDetailScreen extends StatefulWidget {
  final MeetingDraft meeting;
  final SfColors colors;
  final bool reminderSent;
  final VoidCallback onReminderSent;
  final VoidCallback? onCancel;
  const MeetingDetailScreen({
    super.key,
    required this.meeting,
    required this.colors,
    required this.reminderSent,
    required this.onReminderSent,
    this.onCancel,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late bool _reminderSent = widget.reminderSent;

  void _copyInvite() {
    final meeting = widget.meeting;
    Clipboard.setData(
      ClipboardData(
        text: '${meeting.title}\n${meeting.date} · ${meeting.time}\n${meeting.location}\n${meeting.participants}',
      ),
    );
    _snack(context, 'Taklifnoma buferga nusxalandi');
  }

  Future<void> _cancelMeeting() async {
    final c = widget.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SfTheme(
        colors: c,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'Yig‘ilishni bekor qilasizmi?',
            style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w800, color: c.ink),
          ),
          content: Text(
            'Qatnashuvchilarga alohida xabar yuborish kerak bo‘ladi.',
            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.ink2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Yo‘q', style: TextStyle(fontFamily: SfType.ui, color: c.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Bekor qilish', style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w800, color: c.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      widget.onCancel?.call();
      Navigator.of(context).pop();
      _snack(context, 'Yig‘ilish bekor qilindi', bg: c.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final meeting = widget.meeting;
    final total = meeting.participantCount;
    final progress = total == 0
        ? 0.0
        : (meeting.confirmedParticipants / total).clamp(0, 1).toDouble();
    final agenda = meeting.agenda.isEmpty ? [meeting.description] : meeting.agenda;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Yig‘ilish tafsilotlari',
            style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w800, color: c.ink),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: c.ink2),
              onSelected: (action) {
                if (action == 'copy') _copyInvite();
                if (action == 'cancel') _cancelMeeting();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.content_copy_rounded),
                    title: Text('Taklifnomani nusxalash'),
                  ),
                ),
                if (widget.onCancel != null)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.event_busy_rounded, color: Colors.red),
                      title: Text('Yig‘ilishni bekor qilish'),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.primarySoft,
                border: Border.all(color: c.primary.withValues(alpha: .18)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(13)),
                        child: Icon(_meetingStatusIcon(meeting.status), color: Colors.white),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          meeting.title,
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 17, fontWeight: FontWeight.w800, color: c.ink),
                        ),
                      ),
                      Pill(_meetingStatusLabel(meeting.status), tone: _meetingStatusTone(meeting.status)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    meeting.description,
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 12, height: 1.4, color: c.ink2),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _MeetingInfoChip(icon: Icons.calendar_today_rounded, label: '${meeting.date} · ${meeting.time}'),
                      _MeetingInfoChip(icon: meeting.format == 'Onlayn' ? Icons.videocam_rounded : Icons.location_on_rounded, label: meeting.location),
                      _MeetingInfoChip(icon: Icons.timer_outlined, label: '${meeting.durationMinutes} daqiqa'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _setSec(c, 'QATNASHUVCHILAR'),
            SfCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(meeting.participants, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w800, color: c.ink))),
                        Text('${meeting.confirmedParticipants}/$total', style: TextStyle(fontFamily: SfType.mono, fontSize: 13, fontWeight: FontWeight.w800, color: c.success)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: progress, minHeight: 7, color: c.success, backgroundColor: c.surface2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(progress * 100).round()}% qatnashuv tasdiqlangan · mas’ul: ${meeting.owner}',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _setSec(c, 'KUN TARTIBI'),
            SfCard(
              child: Column(
                children: [
                  for (var index = 0; index < agenda.length; index++)
                    _MeetingAgendaRow(
                      index: index + 1,
                      text: agenda[index],
                      last: index == agenda.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _setSec(c, 'SO‘NGGI HARAKATLAR'),
            SfCard(
              child: Column(
                children: [
                  _InfoRow('Tashkilotchi', meeting.owner),
                  _InfoRow('Format', meeting.format),
                  _InfoRow(
                    'Eslatma',
                    _reminderSent ? 'Yuborildi' : 'Hali yuborilmagan',
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SfButton(
                    icon: _reminderSent ? Icons.check_rounded : Icons.notifications_active_rounded,
                    label: _reminderSent ? 'Eslatma yuborildi' : 'Eslatma yuborish',
                    primary: true,
                    onTap: () {
                      if (_reminderSent) return;
                      setState(() => _reminderSent = true);
                      widget.onReminderSent();
                      _snack(context, '$total qatnashuvchiga eslatma yuborildi', bg: c.success);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: SfButton(
                    icon: Icons.content_copy_rounded,
                    label: '',
                    primary: false,
                    onTap: _copyInvite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MeetingInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: c.surface.withValues(alpha: .7), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, color: c.ink2)),
        ],
      ),
    );
  }
}

class _MeetingAgendaRow extends StatelessWidget {
  final int index;
  final String text;
  final bool last;
  const _MeetingAgendaRow({required this.index, required this.text, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : BorderSide(color: c.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(8)),
            child: Text('$index', style: TextStyle(fontFamily: SfType.mono, fontSize: 10.5, fontWeight: FontWeight.w800, color: c.primary)),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: c.ink2))),
        ],
      ),
    );
  }
}

class MeetingCreateScreen extends StatefulWidget {
  final SfColors colors;
  const MeetingCreateScreen({super.key, required this.colors});
  @override
  State<MeetingCreateScreen> createState() => _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends State<MeetingCreateScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final date = TextEditingController();
  final time = TextEditingController();
  final location = TextEditingController();
  final participants = TextEditingController();
  final description = TextEditingController();
  String format = 'Ofisda';
  int duration = 60;
  bool notify = true;
  @override
  void dispose() {
    for (final c in [title, date, time, location, participants, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (d != null) {
      setState(
        () => date.text =
            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
      );
    }
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) setState(() => time.text = t.format(context));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final audiences = [
      'Butun filial · ${store.students.length}',
      'O‘qituvchilar · ${store.staff.length}',
      'Matematika bo‘limi · 12',
      'Sotuv va marketing · 5',
    ];
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Schedule meeting',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: c.primary),
                    const SizedBox(width: 9),
                    Expanded(child: Text('Aniq kun tartibi va eslatma qatnashuvni sezilarli oshiradi.', style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.primaryInk))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _setSec(c, 'ASOSIY MA’LUMOTLAR'),
              _ManagedTextField(
                controller: title,
                label: 'Yig‘ilish nomi',
                requiredField: true,
              ),
              _DateInput(label: 'Sana', controller: date, onTap: pickDate, requiredField: true),
              const SizedBox(height: 11),
              _DateInput(label: 'Vaqt', controller: time, onTap: pickTime, requiredField: true, icon: Icons.schedule_rounded),
              const SizedBox(height: 11),
              _ManagedSelect<String>(
                label: 'Format',
                value: format,
                items: const ['Ofisda', 'Onlayn'],
                onChanged: (value) => setState(() => format = value),
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: location,
                label: format == 'Onlayn' ? 'Platforma yoki havola' : 'Xona yoki manzil',
                requiredField: true,
              ),
              _ManagedSelect<int>(
                label: 'Davomiyligi',
                value: duration,
                items: const [30, 45, 60, 75, 90],
                display: (value) => '$value daqiqa',
                onChanged: (value) => setState(() => duration = value),
              ),
              const SizedBox(height: 18),
              _setSec(c, 'QATNASHUVCHILAR'),
              Text('Tayyor auditoriyani tanlang yoki ro‘yxatni o‘zingiz kiriting.', style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final audience in audiences)
                    ChoiceChip(
                      label: Text(audience),
                      selected: participants.text == audience,
                      onSelected: (_) => setState(() => participants.text = audience),
                      showCheckmark: false,
                      selectedColor: c.primarySoft,
                      labelStyle: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, color: participants.text == audience ? c.primaryInk : c.ink2),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              _ManagedTextField(
                controller: participants,
                label: 'Qatnashuvchilar',
                requiredField: true,
              ),
              _setSec(c, 'KUN TARTIBI'),
              _ManagedTextField(
                controller: description,
                label: 'Maqsad va muhokama bandlari',
                maxLines: 4,
                requiredField: true,
              ),
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                value: notify,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: c.primary,
                title: Text('Qatnashuvchilarga eslatma yuborish', style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                subtitle: Text('Yig‘ilish yaratilganda xabar jo‘natiladi', style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                onChanged: (value) => setState(() => notify = value),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SfButton(
              icon: Icons.notifications_active_rounded,
              label: 'Schedule and notify',
              primary: true,
              onTap: () {
                if (form.currentState!.validate()) {
                  final agenda = description.text
                      .split('\n')
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList();
                  Navigator.of(context).pop(
                    MeetingDraft(
                      title.text.trim(),
                      date.text.trim(),
                      time.text.trim(),
                      location.text.trim(),
                      participants.text.trim(),
                      description.text.trim(),
                      confirmedParticipants: 0,
                      agenda: agenda,
                      format: format,
                      durationMinutes: duration,
                      notifyParticipants: notify,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentsWorkspaceScreen extends StatelessWidget {
  final SfColors colors;
  const PaymentsWorkspaceScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final ledger = AppScope.of(context).ledger;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Payments',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                children: [
                  for (int i = 0; i < ledger.length; i++)
                    _PaymentLedgerRow(
                      entry: ledger[i],
                      last: i == ledger.length - 1,
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

class _PaymentLedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final bool last;
  const _PaymentLedgerRow({required this.entry, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
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
              color: (entry.inflow ? c.success : c.danger).withValues(
                alpha: 0.13,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.inflow
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 17,
              color: entry.inflow ? c.success : c.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  '${entry.who} · ${entry.time}',
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
            '${entry.inflow ? '+' : '-'}${fmtMoneyShort(entry.amount)}',
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: entry.inflow ? c.success : c.danger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushed wrapper so Messages can open as its own page from the top bar.
class _MessagesPage extends StatelessWidget {
  const _MessagesPage();
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.ink),
        shape: Border(bottom: BorderSide(color: c.border)),
        title: Text(
          tr(context, 'messages_title'),
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: c.ink,
          ),
        ),
      ),
      body: const SafeArea(top: false, child: MessagesScreen()),
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
  int sel = 0; // 0 all · 1 personal · 2 groups · 3 unread · 4 archive
  String query = '';

  // Telegram-style long-press menu: pin / archive.
  void _threadMenu(BuildContext context, AppStore store, int idx) {
    final c = SfTheme.of(context);
    final th = store.threads[idx].meta;
    final isPinned = store.pinned.contains(idx);
    final isArchived = store.archived.contains(idx);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: c,
        child: _SheetShell(
          children: [
            Text(
              th.name,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 12),
            _menuAction(
              c,
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              isPinned ? tr(context, 'msg_unpin') : tr(context, 'msg_pin'),
              () {
                store.togglePin(idx);
                Navigator.of(context).maybePop();
              },
            ),
            _menuAction(
              c,
              isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
              isArchived
                  ? tr(context, 'msg_unarchive')
                  : tr(context, 'msg_archive'),
              () {
                store.toggleArchive(idx);
                Navigator.of(context).maybePop();
              },
            ),
            _menuAction(
              c,
              Icons.done_all_rounded,
              tr(context, 'msg_mark_read'),
              () {
                Navigator.of(context).maybePop();
                _snack(context, '✓ ${th.name}');
              },
              last: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuAction(
    SfColors c,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: c.ink2),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final folders = [
      tr(context, 'f_all'),
      tr(context, 'f_direct'),
      tr(context, 'f_groups'),
      tr(context, 'f_unread'),
      '${tr(context, 'f_archive')}${store.archived.isNotEmpty ? ' ${store.archived.length}' : ''}',
    ];
    final q = query.trim().toLowerCase();
    final archiveView = sel == 4;
    // Keep each thread's real store index so the chat page opens the right one.
    final pinned = <int>[];
    final normal = <int>[];
    for (int i = 0; i < store.threads.length; i++) {
      final th = store.threads[i].meta;
      final isArch = store.archived.contains(i);
      if (archiveView != isArch) {
        continue; // archive folder shows only archived
      }
      final folderOk = switch (sel) {
        1 => !th.isGroup,
        2 => th.isGroup,
        3 => th.unread > 0,
        _ => true,
      };
      if (!folderOk) {
        continue;
      }
      if (q.isNotEmpty &&
          !th.name.toLowerCase().contains(q) &&
          !th.last.toLowerCase().contains(q)) {
        continue;
      }
      if (!archiveView && store.pinned.contains(i)) {
        pinned.add(i);
      } else {
        normal.add(i);
      }
    }
    final empty = pinned.isEmpty && normal.isEmpty;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: tr(context, 'messages_eyebrow'),
          title: tr(context, 'messages_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              _SearchField(
                hint: tr(context, 'msg_search'),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 10),
              _FilterChips(
                items: folders,
                selected: sel,
                onSelect: (i) => setState(() => sel = i),
              ),
              const SizedBox(height: 12),
              if (empty)
                _EmptyState(
                  icon: archiveView
                      ? Icons.archive_outlined
                      : Icons.chat_bubble_outline_rounded,
                  title: tr(context, 'no_messages'),
                  sub: tr(context, 'pick_filter'),
                )
              else ...[
                if (pinned.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: c.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tr(context, 'msg_pinned').toUpperCase(),
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SfCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < pinned.length; i++)
                          _ThreadRow(
                            idx: pinned[i],
                            colors: c,
                            last: i == pinned.length - 1,
                            pinned: true,
                            onLong: () =>
                                _threadMenu(context, store, pinned[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (normal.isNotEmpty)
                  SfCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < normal.length; i++)
                          _ThreadRow(
                            idx: normal[i],
                            colors: c,
                            last: i == normal.length - 1,
                            onLong: () =>
                                _threadMenu(context, store, normal[i]),
                          ),
                      ],
                    ),
                  ),
              ],
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
  final bool pinned;
  final VoidCallback? onLong;
  const _ThreadRow({
    required this.idx,
    required this.colors,
    required this.last,
    this.pinned = false,
    this.onLong,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final th = AppScope.of(context).threads[idx].meta;
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(sfPageRoute(ChatScreen(threadIdx: idx, colors: c))),
      onLongPress: onLong,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            if (th.isGroup)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: SfStar(size: 16, color: Colors.white),
                ),
              )
            else
              SfAvatar(name: th.name, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    th.name,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    th.last,
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  th.time,
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 9.5,
                    color: c.muted,
                  ),
                ),
                if (th.unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${th.unread}',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                if (pinned)
                  Icon(Icons.push_pin_rounded, size: 12, color: c.muted)
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: c.muted2,
                  ),
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

/// Telegram-style contact / group card opened by tapping a chat header. It is
/// deliberately a separate route, so Back always returns to the conversation.
class ChatCabinetScreen extends StatelessWidget {
  final Thread? thread;
  final Student? student;
  final int? threadIdx;
  final SfColors colors;
  const ChatCabinetScreen({
    super.key,
    this.thread,
    this.student,
    this.threadIdx,
    required this.colors,
  }) : assert(thread != null || student != null);

  String _phoneFor(String name) {
    var seed = 0;
    for (final unit in name.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    final operator = 90 + seed % 10;
    final number = 1000000 + (seed ~/ 10) % 9000000;
    final digits = number.toString();
    return '+998 $operator ${digits.substring(0, 3)} ${digits.substring(3, 5)} ${digits.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    // Respect the currently selected app theme in contact and group profiles.
    final c = colors;
    final t = thread;
    final s = student;
    final isGroup = t?.isGroup ?? false;
    final name = t?.name ?? s!.name;
    final detail = t?.group ?? s!.group;
    final online = t?.online ?? true;
    final status = online ? tr(context, 'online') : tr(context, 'chat_offline');
    final phone = s == null ? _phoneFor(name) : studentProfile(s).phone;
    final profile = s == null ? null : studentProfile(s);
    final username =
        s?.username ?? '@${name.toLowerCase().replaceAll(' ', '.')}';
    final email = '${name.toLowerCase().replaceAll(' ', '.')}@starforge.uz';
    final branch = profile?.branch ?? detail.split('·').first.trim();
    final department = isGroup
        ? detail
        : 'Ta’lim · ${profile?.level ?? detail}';
    final gender = profile == null
        ? 'Ko‘rsatilmagan'
        : (profile.firstName.endsWith('a') || profile.lastName.endsWith('a')
              ? 'Ayol'
              : 'Erkak');
    final media = threadIdx == null
        ? const <ChatMsg>[]
        : AppScope.of(context).threads[threadIdx!].messages
              .where(
                (m) =>
                    m.kind == ChatMessageKind.image ||
                    m.kind == ChatMessageKind.video,
              )
              .toList()
              .reversed
              .take(3)
              .toList();
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: c.ink),
          actions: [
            IconButton(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded, color: c.ink2),
              onPressed: () => _snack(context, 'Qidirish · ovozsiz · bloklash'),
            ),
          ],
        ),
        body: ListView(
          key: const ValueKey('chat-cabinet'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
          children: [
            Container(
              height: 246,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: isGroup
                      ? [c.primary.withValues(alpha: 0.75), c.surface3]
                      : [c.accent.withValues(alpha: 0.65), c.surface3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -34,
                    top: -48,
                    child: Container(
                      width: 178,
                      height: 178,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -52,
                    bottom: -78,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Center(
                    child: isGroup
                        ? Container(
                            width: 122,
                            height: 122,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(37),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: SfStar(size: 52, color: Colors.white),
                            ),
                          )
                        : SfAvatar(name: name, size: 122),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isGroup ? detail : status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: online ? c.primary : c.muted,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                _ChatProfileAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  color: c.primary,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                _ChatProfileAction(
                  icon: Icons.notifications_rounded,
                  label: 'Sound',
                  color: c.primary,
                  onTap: () => _snack(context, '🔔 Bildirishnomalar (demo)'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TelegramPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TelegramInfoLine(
                    value: isGroup
                        ? 'Dars jadvali, fayllar va muhim e’lonlar shu yerda.'
                        : name,
                    label: isGroup ? 'Dars ma’lumoti' : 'Full name',
                    leading: isGroup
                        ? Icons.info_outline_rounded
                        : Icons.person_outline_rounded,
                  ),
                  Divider(height: 1, color: c.border),
                  _TelegramInfoLine(
                    value: isGroup ? detail : username,
                    label: isGroup ? 'Guruh' : 'Username',
                    leading: isGroup
                        ? Icons.groups_rounded
                        : Icons.badge_outlined,
                  ),
                  Divider(height: 1, color: c.border),
                  _TelegramInfoLine(
                    value: isGroup
                        ? '${detail.split('·').last.trim()} participants'
                        : phone,
                    label: isGroup ? 'A’zolar' : 'Phone number',
                    leading: isGroup
                        ? Icons.groups_rounded
                        : Icons.phone_outlined,
                  ),
                  if (!isGroup) ...[
                    Divider(height: 1, color: c.border),
                    _TelegramInfoLine(
                      value: email,
                      label: 'Email',
                      leading: Icons.email_outlined,
                    ),
                    Divider(height: 1, color: c.border),
                    _TelegramInfoLine(
                      value: gender,
                      label: 'Gender',
                      leading: Icons.wc_rounded,
                    ),
                    Divider(height: 1, color: c.border),
                    _TelegramInfoLine(
                      value: branch,
                      label: 'Branch',
                      leading: Icons.account_tree_outlined,
                    ),
                    Divider(height: 1, color: c.border),
                    _TelegramInfoLine(
                      value: department,
                      label: 'Department',
                      leading: Icons.corporate_fare_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TelegramPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      media.isEmpty
                          ? 'Rasm va video hali yuborilmagan'
                          : '${media.length} ta so‘nggi fayl',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        color: c.muted,
                      ),
                    ),
                    if (media.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          for (int i = 0; i < media.length; i++) ...[
                            Expanded(
                              child: _CabinetMediaPreview(message: media[i]),
                            ),
                            if (i < media.length - 1) const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isGroup) ...[
              const SizedBox(height: 12),
              _TelegramPanel(
                child: _TelegramInfoLine(
                  value: detail,
                  label: 'Manage participants',
                  leading: Icons.group_add_rounded,
                  trailing: Icons.chevron_right_rounded,
                  onTap: () =>
                      _snack(context, 'Ishtirokchilar ro‘yxati (demo)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact action card used in the Telegram-style profile header.
class _ChatProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ChatProfileAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Expanded(
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TelegramPanel extends StatelessWidget {
  final Widget child;
  const _TelegramPanel({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _TelegramInfoLine extends StatelessWidget {
  final String value;
  final String label;
  final IconData leading;
  final IconData? trailing;
  final VoidCallback? onTap;
  const _TelegramInfoLine({
    required this.value,
    required this.label,
    required this.leading,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Icon(leading, color: c.muted, size: 20),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: c.muted, size: 19),
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class _CabinetMediaPreview extends StatelessWidget {
  final ChatMsg message;
  const _CabinetMediaPreview({required this.message});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final isImage = message.kind == ChatMessageKind.image;
    return AspectRatio(
      aspectRatio: 1.12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: isImage && message.path != null
            ? Image.file(
                File(message.path!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _mediaFallback(c, Icons.broken_image_outlined),
              )
            : _mediaFallback(c, Icons.play_circle_fill_rounded),
      ),
    );
  }

  Widget _mediaFallback(SfColors c, IconData icon) => Container(
    color: c.surface3,
    child: Center(child: Icon(icon, color: c.primary, size: 27)),
  );
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _voiceLocked = false;
  DateTime? _recordStartedAt;

  @override
  void dispose() {
    _recorder.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppStore store) {
    if (_ctrl.text.trim().isEmpty) return;
    store.sendMessage(widget.threadIdx, _ctrl.text);
    _ctrl.clear();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _attach(AppStore store) async {
    final kind = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: widget.colors,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.colors.muted2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                _AttachmentOption(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF7B9CFF),
                  title: 'Photo from gallery',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.galleryImage),
                ),
                _AttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF52C875),
                  title: 'Take a photo',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.cameraImage),
                ),
                _AttachmentOption(
                  icon: Icons.video_library_rounded,
                  color: const Color(0xFFE47C72),
                  title: 'Video from gallery',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.galleryVideo),
                ),
                _AttachmentOption(
                  icon: Icons.videocam_rounded,
                  color: const Color(0xFFF2B84B),
                  title: 'Record a video',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.cameraVideo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final isVideo =
        kind == _AttachmentChoice.galleryVideo ||
        kind == _AttachmentChoice.cameraVideo;
    final source =
        kind == _AttachmentChoice.cameraImage ||
            kind == _AttachmentChoice.cameraVideo
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final XFile? file = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null || !mounted) return;
      final localPath = await _saveAttachment(
        file.path,
        isVideo ? 'video' : 'image',
      );
      if (!mounted) return;
      store.sendAttachment(
        widget.threadIdx,
        kind: isVideo ? ChatMessageKind.video : ChatMessageKind.image,
        path: localPath,
        label: _fileName(file.path),
      );
      _scrollToEnd();
    } catch (_) {
      if (mounted) _snack(context, 'Faylni biriktirib bo‘lmadi');
    }
  }

  Future<void> _toggleVoice(AppStore store) async {
    if (_recording) {
      final path = await _recorder.stop();
      final duration = DateTime.now().difference(
        _recordStartedAt ?? DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _recording = false;
        _voiceLocked = false;
        _recordStartedAt = null;
      });
      if (path != null) {
        store.sendAttachment(
          widget.threadIdx,
          kind: ChatMessageKind.voice,
          path: path,
          label: 'Voice message',
          duration: duration,
        );
        _scrollToEnd();
      }
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) _snack(context, 'Mikrofon ruxsati kerak');
      return;
    }
    try {
      final dir = await _mediaDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _voiceLocked = false;
        _recordStartedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted) _snack(context, 'Ovozli xabarni yozib bo‘lmadi');
    }
  }

  Future<void> _cancelVoice() async {
    if (!_recording) return;
    final path = await _recorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _voiceLocked = false;
      _recordStartedAt = null;
    });
    _snack(context, 'Ovozli xabar bekor qilindi');
  }

  Future<Directory> _mediaDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/chat_media');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> _saveAttachment(String sourcePath, String type) async {
    final directory = await _mediaDirectory();
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot == -1 ? '' : sourcePath.substring(dot);
    final target = File(
      '${directory.path}/${type}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  String _fileName(String path) {
    final slash = path.lastIndexOf(Platform.pathSeparator);
    return slash == -1 ? path : path.substring(slash + 1);
  }

  void _openCabinet(Thread thread, SfColors colors) {
    Navigator.of(context).push(
      sfPageRoute(
        ChatCabinetScreen(
          thread: thread,
          threadIdx: widget.threadIdx,
          colors: colors,
        ),
      ),
    );
  }

  void _messageActions(ChatMsg message, int index) {
    final c = widget.colors;
    final visual = _chatVisualStyle(SettingsScope.of(context).chatDesign, c);
    final store = AppScope.of(context);
    final pinned =
        store.pinnedMessages[widget.threadIdx]?.contains(index) ?? false;
    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool danger = false,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: visual.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: danger ? visual.danger : visual.icon),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: danger ? visual.danger : visual.inputText,
              ),
            ),
          ],
        ),
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SfTheme(
        colors: c,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 14),
            decoration: BoxDecoration(
              color: visual.composer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border(top: BorderSide(color: visual.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: visual.muted.withValues(alpha: .42),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(height: 13),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Xabar amallari',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: visual.inputText,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                action(Icons.reply_rounded, 'Reply', () {
                  Navigator.of(sheet).pop();
                  setState(() {
                    _ctrl.text = '↩ ${message.text} ';
                  });
                }),
                action(Icons.forward_rounded, 'Forward', () {
                  Navigator.of(sheet).pop();
                  _snack(context, 'Forward uchun suhbatni tanlang');
                }),
                action(Icons.copy_rounded, 'Copy', () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (!mounted) return;
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  _snack(context, 'Xabar nusxalandi');
                }),
                action(
                  pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  pinned ? 'Unpin message' : 'Pin message',
                  () {
                    store.toggleMessagePin(widget.threadIdx, index);
                    Navigator.of(sheet).pop();
                  },
                ),
                action(Icons.delete_outline_rounded, 'Delete', () {
                  store.deleteMessage(widget.threadIdx, index);
                  Navigator.of(sheet).pop();
                }, danger: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _referenceBuild(context);

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = widget.colors;
    final settings = SettingsScope.of(context);
    final wallpaper = settings.chatWallpaper;
    final visual = _chatVisualStyle(settings.chatDesign, c);
    final store = AppScope.of(context);
    final thread = store.threads[widget.threadIdx];
    final th = thread.meta;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: visual.canvas,
        appBar: AppBar(
          backgroundColor: c.surface,
          flexibleSpace: null,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: c.primary),
          shape: Border(bottom: BorderSide(color: c.border)),
          titleSpacing: 0,
          title: Semantics(
            button: true,
            label:
                '${tr(context, th.isGroup ? 'chat_group_info' : 'chat_profile')} · ${th.name}',
            child: InkWell(
              key: const ValueKey('chat-profile-header'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openCabinet(th, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    if (th.isGroup)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Center(
                          child: SfStar(size: 17, color: Colors.white),
                        ),
                      )
                    else
                      SfAvatar(name: th.name, size: 38),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            th.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            th.online ? tr(context, 'online') : th.group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: th.online ? c.success : c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _ChatWallpaper(
                        style: wallpaper,
                        colors: c,
                        baseColor: visual.canvas,
                        accentColor: visual.accent,
                        customPath: settings.chatWallpaperPath,
                      ),
                    ),
                  ),
                  ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (int i = 0; i < thread.messages.length; i++) ...[
                        _bubble(context, thread.messages[i], i),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                heightFactor: _recording ? 1 : 0,
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: c.surface,
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 700),
                        tween: Tween(begin: 0.7, end: 1.0),
                        curve: Curves.easeInOut,
                        builder: (_, value, _) => Transform.scale(
                          scale: value,
                          child: Icon(
                            Icons.mic_rounded,
                            color: visual.danger,
                            size: 18,
                          ),
                        ),
                        onEnd: () {
                          if (mounted && _recording) setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _voiceLocked
                              ? 'Yozilmoqda · yuborish uchun tugmani bosing'
                              : 'Yozilmoqda · chapga suring — bekor qilish',
                          style: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: visual.danger,
                          ),
                        ),
                      ),
                      if (_voiceLocked)
                        Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: visual.danger,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach photo or video',
                    onPressed: () => _attach(store),
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 25,
                      color: c.primary,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(store),
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          color: c.ink,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                          hintText: tr(context, 'msg_hint'),
                          hintStyle: TextStyle(
                            fontFamily: SfType.ui,
                            fontSize: 13,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SfTap(
                    child: GestureDetector(
                      onTap: _ctrl.text.trim().isNotEmpty
                          ? () => _send(store)
                          : () => _toggleVoice(store),
                      onLongPressStart: _ctrl.text.trim().isNotEmpty
                          ? null
                          : (_) {
                              if (!_recording) _toggleVoice(store);
                            },
                      onLongPressMoveUpdate: _ctrl.text.trim().isNotEmpty
                          ? null
                          : (details) {
                              if (!_recording) return;
                              if (details.offsetFromOrigin.dx < -64) {
                                _cancelVoice();
                              } else if (details.offsetFromOrigin.dy < -48 &&
                                  !_voiceLocked) {
                                setState(() => _voiceLocked = true);
                              }
                            },
                      onLongPressEnd: _ctrl.text.trim().isNotEmpty
                          ? null
                          : (_) {
                              if (_recording && !_voiceLocked) {
                                _toggleVoice(store);
                              }
                            },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _recording ? c.danger : c.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _ctrl.text.trim().isNotEmpty
                              ? Icons.send_rounded
                              : _recording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
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

  Widget _referenceBuild(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final thread = store.threads[widget.threadIdx];
    final meta = thread.meta;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            RefNavHeader(
              title: meta.name,
              subtitle: meta.online ? tr(context, 'online') : meta.group,
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                RefIconAction(
                  key: const ValueKey('chat-profile-header'),
                  icon: meta.isGroup
                      ? Icons.groups_rounded
                      : Icons.person_outline_rounded,
                  tooltip: tr(
                    context,
                    meta.isGroup ? 'chat_group_info' : 'chat_profile',
                  ),
                  onPressed: () => _openCabinet(meta, c),
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.bg),
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  itemCount: thread.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _ReferenceConversationBubble(
                    message: thread.messages[index],
                    time: _messageTime(index),
                    onLongPress: () =>
                        _messageActions(thread.messages[index], index),
                  ),
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: RefMotion.resolve(context, RefMotion.quick),
                curve: Curves.easeOutCubic,
                child: _recording
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface2,
                          border: Border(top: BorderSide(color: c.border)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                size: 18,
                                color: c.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _voiceLocked
                                      ? 'Yozilmoqda · yuborish uchun tugmani bosing'
                                      : 'Yozilmoqda · chapga suring — bekor qilish',
                                  style: RefType.ui(
                                    size: 11.5,
                                    weight: FontWeight.w700,
                                    color: c.danger,
                                  ),
                                ),
                              ),
                              if (_voiceLocked)
                                Icon(
                                  Icons.lock_rounded,
                                  size: 16,
                                  color: c.danger,
                                ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            _referenceComposer(context, store),
          ],
        ),
      ),
    );
  }

  Widget _referenceComposer(BuildContext context, AppStore store) {
    final c = widget.colors;
    final hasText = _ctrl.text.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: RefShadows.soft,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach photo or video',
                onPressed: () => _attach(store),
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 23,
                  color: c.primary,
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(store),
                    onChanged: (_) => setState(() {}),
                    style: RefType.ui(size: 13, color: c.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      hintText: tr(context, 'msg_hint'),
                      hintStyle: RefType.ui(size: 13, color: c.muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: hasText ? () => _send(store) : () => _toggleVoice(store),
                onLongPressStart: hasText
                    ? null
                    : (_) {
                        if (!_recording) _toggleVoice(store);
                      },
                onLongPressMoveUpdate: hasText
                    ? null
                    : (details) {
                        if (!_recording) return;
                        if (details.offsetFromOrigin.dx < -64) {
                          _cancelVoice();
                        } else if (details.offsetFromOrigin.dy < -48 &&
                            !_voiceLocked) {
                          setState(() => _voiceLocked = true);
                        }
                      },
                onLongPressEnd: hasText
                    ? null
                    : (_) {
                        if (_recording && !_voiceLocked) _toggleVoice(store);
                      },
                child: RefPressable(
                  onPressed: hasText
                      ? () => _send(store)
                      : () => _toggleVoice(store),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _recording ? c.danger : c.primary,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        hasText
                            ? Icons.send_rounded
                            : _recording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMsg message, int index) {
    final c = widget.colors;
    final mine = message.mine;
    final visual = _chatVisualStyle(SettingsScope.of(context).chatDesign, c);
    final borderRadius = visual.bubbleRadius(mine);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mine && visual.outgoingGradient != null
            ? null
            : (mine ? visual.outgoing : visual.incoming),
        gradient: mine ? visual.outgoingGradient : null,
        border: Border.all(
          color: mine ? visual.outgoingBorder : visual.incomingBorder,
        ),
        borderRadius: borderRadius,
        boxShadow: visual.glass
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.09),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ChatMessageBody(
            message: message,
            mine: mine,
            textColor: mine ? visual.outgoingText : visual.incomingText,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 11, 7),
            child: Text(
              _messageTime(index),
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: mine ? visual.outgoingTime : visual.incomingTime,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onLongPress: () => _messageActions(message, index),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          'message-$index-${message.mine}-${message.path ?? message.text}',
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((mine ? 18 : -18) * (1 - value), 8 * (1 - value)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * value,
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: visual.glass
              ? ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: bubble,
                  ),
                )
              : bubble,
        ),
      ),
    );
  }

  String _messageTime(int index) {
    const values = ['10:24', '10:26', '10:27', '10:29', '10:31', '10:34'];
    return values[index % values.length];
  }
}

class _ReferenceConversationBubble extends StatelessWidget {
  const _ReferenceConversationBubble({
    required this.message,
    required this.time,
    required this.onLongPress,
  });

  final ChatMsg message;
  final String time;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final mine = message.mine;
    final body = message.kind == ChatMessageKind.text
        ? RefChatBubble(text: message.text, mine: mine, time: time)
        : RefSurfaceCard(
            color: mine ? c.primary : c.surface,
            radius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(mine ? 15 : 4),
              bottomRight: Radius.circular(mine ? 4 : 15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ChatMessageBody(
                  message: message,
                  mine: mine,
                  textColor: mine ? c.surface : c.ink,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 11, 7),
                  child: Text(
                    time,
                    style: RefType.mono(
                      size: 8.5,
                      color: mine ? c.surface.withValues(alpha: .72) : c.muted,
                    ),
                  ),
                ),
              ],
            ),
          );
    return GestureDetector(
      onLongPress: onLongPress,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: RefMotion.resolve(context, RefMotion.standard),
        curve: Curves.easeOutCubic,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .76,
          ),
          child: body,
        ),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((mine ? 14 : -14) * (1 - value), 7 * (1 - value)),
            child: Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// One source of truth for the visible chat chrome. Keeping it separate from
/// the app palette makes every choice in Chat Design change the full
/// conversation: header, bubbles, input, icons, timestamps and menus.
class _ChatVisualStyle {
  final SfChatDesign design;
  final Color canvas;
  final Color appBar;
  final Color appBarText;
  final Color presence;
  final Color incoming;
  final Color outgoing;
  final Color incomingText;
  final Color outgoingText;
  final Color composer;
  final Color input;
  final Color inputText;
  final Color icon;
  final Color muted;
  final Color action;
  final Color accent;
  final Color danger;
  final Color border;
  final Color incomingBorder;
  final Color outgoingBorder;
  final Color incomingTime;
  final Color outgoingTime;
  final Gradient? appBarGradient;
  final Gradient? outgoingGradient;
  final bool glass;

  const _ChatVisualStyle({
    required this.design,
    required this.canvas,
    required this.appBar,
    required this.appBarText,
    required this.presence,
    required this.incoming,
    required this.outgoing,
    required this.incomingText,
    required this.outgoingText,
    required this.composer,
    required this.input,
    required this.inputText,
    required this.icon,
    required this.muted,
    required this.action,
    required this.accent,
    required this.danger,
    required this.border,
    required this.incomingBorder,
    required this.outgoingBorder,
    required this.incomingTime,
    required this.outgoingTime,
    this.appBarGradient,
    this.outgoingGradient,
    this.glass = false,
  });

  BorderRadius bubbleRadius(bool mine) => switch (design) {
    SfChatDesign.telegram => BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 3),
      bottomRight: Radius.circular(mine ? 3 : 16),
    ),
    SfChatDesign.whatsapp => BorderRadius.only(
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: Radius.circular(mine ? 10 : 2),
      bottomRight: Radius.circular(mine ? 2 : 10),
    ),
    SfChatDesign.modernDark => BorderRadius.circular(18),
    SfChatDesign.glass => BorderRadius.circular(21),
    SfChatDesign.gradient => BorderRadius.circular(22),
    SfChatDesign.minimal => BorderRadius.circular(8),
    SfChatDesign.neon => BorderRadius.circular(14),
    SfChatDesign.nature => BorderRadius.circular(19),
  };
}

_ChatVisualStyle _chatVisualStyle(SfChatDesign design, SfColors fallback) {
  const darkText = Color(0xFF1D2B35);
  return switch (design) {
    SfChatDesign.telegram => const _ChatVisualStyle(
      design: SfChatDesign.telegram,
      canvas: Color(0xFFEAF4FC),
      appBar: Color(0xFFFDFEFF),
      appBarText: darkText,
      presence: Color(0xFF4C9ED9),
      incoming: Colors.white,
      outgoing: Color(0xFFD8F0FF),
      incomingText: darkText,
      outgoingText: darkText,
      composer: Color(0xFFFFFFFF),
      input: Color(0xFFF1F7FB),
      inputText: darkText,
      icon: Color(0xFF4C9ED9),
      muted: Color(0xFF7290A3),
      action: Color(0xFF4C9ED9),
      accent: Color(0xFF4C9ED9),
      danger: Color(0xFFE5656C),
      border: Color(0xFFD5E5F0),
      incomingBorder: Color(0xFFDFEAF0),
      outgoingBorder: Color(0xFFCAE4F5),
      incomingTime: Color(0xFF8AA2B2),
      outgoingTime: Color(0xFF6092AC),
    ),
    SfChatDesign.whatsapp => const _ChatVisualStyle(
      design: SfChatDesign.whatsapp,
      canvas: Color(0xFFE7F1E9),
      appBar: Color(0xFF0B6E4F),
      appBarText: Colors.white,
      presence: Color(0xFFA9E7BF),
      incoming: Colors.white,
      outgoing: Color(0xFFD9FDD3),
      incomingText: Color(0xFF1C2A22),
      outgoingText: Color(0xFF173525),
      composer: Color(0xFFF7F9F8),
      input: Colors.white,
      inputText: Color(0xFF173525),
      icon: Color(0xFF168A63),
      muted: Color(0xFF6C8376),
      action: Color(0xFF1DA86F),
      accent: Color(0xFF1DA86F),
      danger: Color(0xFFC85151),
      border: Color(0xFFCDE1D4),
      incomingBorder: Color(0xFFE0E9E2),
      outgoingBorder: Color(0xFFC8EFC5),
      incomingTime: Color(0xFF809487),
      outgoingTime: Color(0xFF5A9870),
    ),
    SfChatDesign.modernDark => const _ChatVisualStyle(
      design: SfChatDesign.modernDark,
      canvas: Color(0xFF0B1020),
      appBar: Color(0xFF11192A),
      appBarText: Color(0xFFF0F5FF),
      presence: Color(0xFF85D7C2),
      incoming: Color(0xFF18233A),
      outgoing: Color(0xFF304E70),
      incomingText: Color(0xFFE6EEF9),
      outgoingText: Colors.white,
      composer: Color(0xFF101827),
      input: Color(0xFF1A263A),
      inputText: Color(0xFFF0F5FF),
      icon: Color(0xFF9AB9E7),
      muted: Color(0xFF93A4BD),
      action: Color(0xFF6E9FE8),
      accent: Color(0xFF6E9FE8),
      danger: Color(0xFFFF7D8C),
      border: Color(0xFF26344C),
      incomingBorder: Color(0xFF2B3B55),
      outgoingBorder: Color(0xFF4F6E94),
      incomingTime: Color(0xFF9FB0C8),
      outgoingTime: Color(0xFFC5D9FA),
    ),
    SfChatDesign.glass => const _ChatVisualStyle(
      design: SfChatDesign.glass,
      canvas: Color(0xFFE9E5F8),
      appBar: Color(0xD9F7F4FF),
      appBarText: Color(0xFF302C52),
      presence: Color(0xFF786FC5),
      incoming: Color(0xB3FFFFFF),
      outgoing: Color(0xA8D8D0FA),
      incomingText: Color(0xFF302C52),
      outgoingText: Color(0xFF302C52),
      composer: Color(0xC9FFFFFF),
      input: Color(0xA8FFFFFF),
      inputText: Color(0xFF302C52),
      icon: Color(0xFF786FC5),
      muted: Color(0xFF766F91),
      action: Color(0xFF8D78D1),
      accent: Color(0xFF8D78D1),
      danger: Color(0xFFD56C82),
      border: Color(0x80FFFFFF),
      incomingBorder: Color(0xA3FFFFFF),
      outgoingBorder: Color(0x80FFFFFF),
      incomingTime: Color(0xFF786F92),
      outgoingTime: Color(0xFF665A88),
      glass: true,
    ),
    SfChatDesign.gradient => const _ChatVisualStyle(
      design: SfChatDesign.gradient,
      canvas: Color(0xFFF7E8FA),
      appBar: Color(0x00000000),
      appBarText: Colors.white,
      presence: Color(0xFFFFD4F7),
      incoming: Color(0xFFFDF9FF),
      outgoing: Color(0xFFD475E7),
      incomingText: Color(0xFF43244E),
      outgoingText: Colors.white,
      composer: Color(0xFFFEF8FF),
      input: Color(0xFFF3E8F8),
      inputText: Color(0xFF43244E),
      icon: Color(0xFFA656C1),
      muted: Color(0xFF8F7199),
      action: Color(0xFFC05CD0),
      accent: Color(0xFFC05CD0),
      danger: Color(0xFFD65B82),
      border: Color(0xFFE5CFEA),
      incomingBorder: Color(0xFFECDBF1),
      outgoingBorder: Color(0x00FFFFFF),
      incomingTime: Color(0xFF9B7AA6),
      outgoingTime: Color(0xFFF8D9FF),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF6A5BDE), Color(0xFFC35AD0), Color(0xFFED7C9D)],
      ),
      outgoingGradient: LinearGradient(
        colors: [Color(0xFF8560DD), Color(0xFFD66DCC)],
      ),
    ),
    SfChatDesign.minimal => const _ChatVisualStyle(
      design: SfChatDesign.minimal,
      canvas: Color(0xFFFFFFFF),
      appBar: Color(0xFFFFFFFF),
      appBarText: Color(0xFF171717),
      presence: Color(0xFF4B8062),
      incoming: Color(0xFFFFFFFF),
      outgoing: Color(0xFFF5F5F5),
      incomingText: Color(0xFF202020),
      outgoingText: Color(0xFF202020),
      composer: Color(0xFFFFFFFF),
      input: Color(0xFFF4F4F4),
      inputText: Color(0xFF202020),
      icon: Color(0xFF3E3E3E),
      muted: Color(0xFF8B8B8B),
      action: Color(0xFF1F1F1F),
      accent: Color(0xFF1F1F1F),
      danger: Color(0xFFC35151),
      border: Color(0xFFE4E4E4),
      incomingBorder: Color(0xFFE8E8E8),
      outgoingBorder: Color(0xFFE8E8E8),
      incomingTime: Color(0xFF989898),
      outgoingTime: Color(0xFF858585),
    ),
    SfChatDesign.neon => const _ChatVisualStyle(
      design: SfChatDesign.neon,
      canvas: Color(0xFF090C14),
      appBar: Color(0xFF101628),
      appBarText: Color(0xFFF6F4FF),
      presence: Color(0xFF75FFC6),
      incoming: Color(0xFF141D30),
      outgoing: Color(0xFF2B1F53),
      incomingText: Color(0xFFE9F5FF),
      outgoingText: Color(0xFFF5EEFF),
      composer: Color(0xFF101628),
      input: Color(0xFF18243A),
      inputText: Color(0xFFF6F4FF),
      icon: Color(0xFF70F6FF),
      muted: Color(0xFF9AA7C4),
      action: Color(0xFF9A5CFF),
      accent: Color(0xFF70F6FF),
      danger: Color(0xFFFF659B),
      border: Color(0xFF263654),
      incomingBorder: Color(0xFF29405D),
      outgoingBorder: Color(0xFF825BFF),
      incomingTime: Color(0xFF9EB7D6),
      outgoingTime: Color(0xFFC3B1FF),
      outgoingGradient: LinearGradient(
        colors: [Color(0xFF263C85), Color(0xFF742AB5)],
      ),
    ),
    SfChatDesign.nature => const _ChatVisualStyle(
      design: SfChatDesign.nature,
      canvas: Color(0xFFE8F3E8),
      appBar: Color(0xFFF7FBF4),
      appBarText: Color(0xFF26452B),
      presence: Color(0xFF4F9461),
      incoming: Color(0xFFFFFFFF),
      outgoing: Color(0xFFD0EBC9),
      incomingText: Color(0xFF27452D),
      outgoingText: Color(0xFF24452C),
      composer: Color(0xFFFBFDF8),
      input: Color(0xFFEAF4E7),
      inputText: Color(0xFF27452D),
      icon: Color(0xFF5B8F5B),
      muted: Color(0xFF748A73),
      action: Color(0xFF618F5D),
      accent: Color(0xFF618F5D),
      danger: Color(0xFFC76464),
      border: Color(0xFFD4E4D1),
      incomingBorder: Color(0xFFE0EBDE),
      outgoingBorder: Color(0xFFC2DDBB),
      incomingTime: Color(0xFF829781),
      outgoingTime: Color(0xFF668D65),
    ),
  };
}

/// A lightweight painted chat background. It is intentionally code-native so
/// every palette and dark/light theme remains readable without image assets.
class _ChatWallpaper extends StatelessWidget {
  final SfChatWallpaper style;
  final SfColors colors;
  final Color baseColor;
  final Color accentColor;
  final String? customPath;
  const _ChatWallpaper({
    required this.style,
    required this.colors,
    required this.baseColor,
    required this.accentColor,
    this.customPath,
  });

  @override
  Widget build(BuildContext context) {
    final background = switch (style) {
      SfChatWallpaper.telegramClouds => const LinearGradient(
        colors: [Color(0xFFEAF6FE), Color(0xFFD7ECFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.whatsappPattern => const LinearGradient(
        colors: [Color(0xFFEAF5EE), Color(0xFFD7E9DA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SfChatWallpaper.mountains => const LinearGradient(
        colors: [Color(0xFFD9E9E9), Color(0xFFEDF4EF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SfChatWallpaper.aurora => const LinearGradient(
        colors: [Color(0xFF15233E), Color(0xFF29445E), Color(0xFF27334F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.space => const LinearGradient(
        colors: [Color(0xFF080C1C), Color(0xFF151337), Color(0xFF11162C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.ocean => const LinearGradient(
        colors: [Color(0xFFDDF5F2), Color(0xFFAEDFD9), Color(0xFFB4D9E9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SfChatWallpaper.sakura => const LinearGradient(
        colors: [Color(0xFFFFF2F5), Color(0xFFF8DCE7), Color(0xFFF4E6EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.abstract => const LinearGradient(
        colors: [Color(0xFFE9E6FA), Color(0xFFF8ECF6), Color(0xFFE5F1FB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.gradient => const LinearGradient(
        colors: [Color(0xFF8574DF), Color(0xFFE885B5), Color(0xFFF9C976)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SfChatWallpaper.blur => LinearGradient(
        colors: [baseColor, Colors.white.withValues(alpha: 0.72)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      _ => null,
    };
    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        gradient: background,
        image: style == SfChatWallpaper.custom && customPath != null
            ? DecorationImage(
                image: FileImage(File(customPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: CustomPaint(
        painter: _ChatWallpaperPainter(
          style,
          colors.muted2.withValues(alpha: 0.16),
          accentColor,
        ),
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  final SfChatWallpaper style;
  final Color color;
  final Color accent;
  _ChatWallpaperPainter(this.style, this.color, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (style == SfChatWallpaper.telegramClouds) {
      for (double y = 24; y < size.height + 38; y += 110) {
        for (double x = -24; x < size.width + 80; x += 145) {
          final cloud = Paint()..color = Colors.white.withValues(alpha: 0.45);
          canvas.drawCircle(Offset(x + 24, y + 16), 21, cloud);
          canvas.drawCircle(Offset(x + 49, y + 9), 28, cloud);
          canvas.drawCircle(Offset(x + 76, y + 19), 18, cloud);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x + 15, y + 20, 74, 25),
              const Radius.circular(15),
            ),
            cloud,
          );
        }
      }
    } else if (style == SfChatWallpaper.whatsappPattern) {
      paint.color = const Color(0xFF6FAF86).withValues(alpha: 0.20);
      for (double y = 16; y < size.height; y += 52) {
        for (double x = 14; x < size.width; x += 58) {
          canvas.drawCircle(Offset(x, y), 5, paint);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x + 14, y + 10, 14, 9),
              const Radius.circular(3),
            ),
            paint,
          );
          canvas.drawLine(Offset(x + 34, y + 2), Offset(x + 43, y + 11), paint);
        }
      }
    } else if (style == SfChatWallpaper.mountains) {
      final far = Path()
        ..moveTo(0, size.height * .58)
        ..lineTo(size.width * .22, size.height * .32)
        ..lineTo(size.width * .45, size.height * .57)
        ..lineTo(size.width * .72, size.height * .25)
        ..lineTo(size.width, size.height * .55)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(far, Paint()..color = const Color(0xFF9FBFC0));
      final near = Path()
        ..moveTo(0, size.height * .73)
        ..lineTo(size.width * .28, size.height * .48)
        ..lineTo(size.width * .52, size.height * .72)
        ..lineTo(size.width * .82, size.height * .42)
        ..lineTo(size.width, size.height * .68)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(near, Paint()..color = const Color(0xFF5E8B78));
    } else if (style == SfChatWallpaper.aurora) {
      for (int i = 0; i < 4; i++) {
        final y = size.height * (.16 + i * .18);
        final glow = Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFF70F0C5).withValues(alpha: .30),
              const Color(0xFF9D81F6).withValues(alpha: .25),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, y - 42, size.width, 84));
        canvas.drawOval(Rect.fromLTWH(-35, y - 35, size.width + 70, 70), glow);
      }
    } else if (style == SfChatWallpaper.space) {
      paint.color = Colors.white.withValues(alpha: .55);
      for (double y = 18; y < size.height; y += 42) {
        for (double x = 12 + (y % 3) * 9; x < size.width; x += 54) {
          canvas.drawCircle(Offset(x, y), (x + y) % 4 == 0 ? 1.4 : .7, paint);
        }
      }
      canvas.drawCircle(
        Offset(size.width * .78, size.height * .18),
        72,
        Paint()..color = const Color(0xFF7B5AC9).withValues(alpha: .20),
      );
    } else if (style == SfChatWallpaper.ocean) {
      paint.style = PaintingStyle.stroke;
      paint.color = const Color(0xFF3B9FA1).withValues(alpha: .28);
      paint.strokeWidth = 2;
      for (double y = -10; y < size.height + 24; y += 38) {
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < size.width + 50; x += 50) {
          path.quadraticBezierTo(x + 12, y - 12, x + 25, y);
          path.quadraticBezierTo(x + 37, y + 12, x + 50, y);
        }
        canvas.drawPath(path, paint);
      }
    } else if (style == SfChatWallpaper.sakura) {
      paint.color = const Color(0xFFE98DAC).withValues(alpha: .42);
      for (double y = 18; y < size.height; y += 58) {
        for (double x = 12; x < size.width; x += 54) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate((x + y) % 8 / 8);
          canvas.drawOval(const Rect.fromLTWH(-4, -2, 8, 4), paint);
          canvas.restore();
        }
      }
    } else if (style == SfChatWallpaper.abstract) {
      for (int i = 0; i < 7; i++) {
        final x = (i * 71.0) % (size.width + 50) - 24;
        final y = (i * 113.0) % (size.height + 50) - 24;
        canvas.drawCircle(
          Offset(x, y),
          42 + (i % 3) * 16,
          Paint()..color = accent.withValues(alpha: .10 + i % 2 * .04),
        );
      }
    } else if (style == SfChatWallpaper.blur) {
      final blur = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      for (int i = 0; i < 5; i++) {
        blur.color = (i.isEven ? accent : const Color(0xFFF0A7C7)).withValues(
          alpha: .28,
        );
        canvas.drawCircle(
          Offset(size.width * (i + 1) / 6, size.height * ((i % 3) + 1) / 4),
          72,
          blur,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChatWallpaperPainter old) =>
      old.style != style || old.color != color || old.accent != accent;
}

enum _AttachmentChoice { galleryImage, cameraImage, galleryVideo, cameraVideo }

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  const _AttachmentOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 13),
              Text(
                title,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageBody extends StatelessWidget {
  final ChatMsg message;
  final bool mine;
  final Color textColor;
  const _ChatMessageBody({
    required this.message,
    required this.mine,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final textStyle = TextStyle(
      fontFamily: SfType.ui,
      fontSize: 13,
      height: 1.32,
      color: textColor,
    );
    switch (message.kind) {
      case ChatMessageKind.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Text(message.text, style: textStyle),
        );
      case ChatMessageKind.image:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.path != null)
              _ChatImage(path: message.path!)
            else
              _mediaError(
                c,
                Icons.image_not_supported_outlined,
                'Photo unavailable',
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                child: Text(message.text, style: textStyle),
              ),
          ],
        );
      case ChatMessageKind.video:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.path != null)
              _VideoMessage(path: message.path!, label: message.text)
            else
              _mediaError(c, Icons.video_file_outlined, 'Video unavailable'),
          ],
        );
      case ChatMessageKind.voice:
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
          child: message.path == null
              ? _mediaError(c, Icons.mic_off_rounded, 'Voice unavailable')
              : _VoiceMessage(
                  path: message.path!,
                  duration: message.duration,
                  mine: mine,
                ),
        );
    }
  }

  Widget _mediaError(SfColors c, IconData icon, String label) => SizedBox(
    width: 218,
    height: 96,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: c.muted, size: 25),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontFamily: SfType.ui, color: c.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _ChatImage extends StatelessWidget {
  final String path;
  const _ChatImage({required this.path});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 244, maxHeight: 270),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 218,
            height: 140,
            color: c.surface3,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: c.muted, size: 30),
          ),
        ),
      ),
    );
  }
}

class _VideoMessage extends StatefulWidget {
  final String path;
  final String label;
  const _VideoMessage({required this.path, required this.label});
  @override
  State<_VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<_VideoMessage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.addListener(_refresh);
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      width: 244,
      height: 164,
      child: InkWell(
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              Container(
                color: c.surface3,
                alignment: Alignment.center,
                child: Icon(
                  _failed
                      ? Icons.video_file_outlined
                      : Icons.hourglass_top_rounded,
                  color: c.muted,
                  size: 30,
                ),
              ),
            if (_ready && !_controller.value.isPlaying)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ),
            if (widget.label.isNotEmpty)
              Positioned(
                left: 9,
                right: 9,
                bottom: 8,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 10.5,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceMessage extends StatefulWidget {
  final String path;
  final Duration? duration;
  final bool mine;
  const _VoiceMessage({
    required this.path,
    required this.duration,
    required this.mine,
  });
  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  late final AudioPlayer _player;
  bool _ready = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
    _player
        .setFilePath(widget.path)
        .then((_) {
          if (mounted) setState(() => _ready = true);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final iconColor = widget.mine ? Colors.white : c.primary;
    final waveColor = widget.mine
        ? Colors.white.withValues(alpha: 0.68)
        : c.primary.withValues(alpha: 0.7);
    return SizedBox(
      width: 214,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.mine
                    ? Colors.white.withValues(alpha: 0.2)
                    : c.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 18; i++)
                      Container(
                        width: 3,
                        height: 5.0 + (i * 7 % 15),
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: waveColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _durationLabel(widget.duration),
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 9.5,
                    color: widget.mine
                        ? Colors.white.withValues(alpha: 0.75)
                        : c.muted,
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

String _durationLabel(Duration? duration) {
  final seconds = duration?.inSeconds ?? 0;
  final min = (seconds ~/ 60).toString();
  final sec = (seconds % 60).toString().padLeft(2, '0');
  return '$min:$sec';
}

// ── Profile ────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final RoleConfig cfg;
  final VoidCallback onSwitchRole;
  const ProfileScreen({
    super.key,
    required this.cfg,
    required this.onSwitchRole,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final settings = SettingsScope.of(context);
    void openDesign() => showDesignPanel(context, cfg.role);
    void openEdit() => Navigator.of(context).push(
      sfPageRoute(
        SfTheme(
          colors: c,
          child: EditProfileScreen(cfg: cfg, colors: c),
        ),
      ),
    );
    final who = store.nameOverride ?? cfg.who;
    final title = store.titleOverride ?? cfg.roleTitle;
    // (label, value, onTap) — theme/lang/currency change inline, instantly.
    final rows = <(String, String, VoidCallback)>[
      (
        tr(context, 'set_role'),
        cfg.label,
        () => _toast(context, '${cfg.roleTitle} · ${cfg.scope}'),
      ),
      (
        tr(context, 'set_currency'),
        '${kCurrencyCode[settings.currency]} · ${kCurrencySym[settings.currency]}',
        () => _showCurrencyPicker(context, settings),
      ),
      (
        tr(context, 'set_lang'),
        langName(context, settings.lang),
        () => _showLanguagePicker(context, settings),
      ),
      (
        tr(context, 'set_theme'),
        tr(context, settings.dark ? 'theme_dark' : 'theme_light'),
        settings.toggleTheme,
      ),
      (
        tr(context, 'set_notifs'),
        tr(context, 'on'),
        () => _showNotifications(context),
      ),
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: '${cfg.label} ${tr(context, 'unit_console')}',
          title: tr(context, 'profile_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            children: [
              GestureDetector(
                onTap: openEdit,
                child: SfCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Tap avatar → avatar picker; tap the card → edit profile.
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).push(sfPageRoute(AvatarPickerScreen(colors: c))),
                        child: Stack(
                          children: [
                            SfAvatar(
                              name: who,
                              size: 56,
                              color: cfg.accent(c),
                              choice: store.avatarChoice,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: c.primary,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: c.surface,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
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
                            Text(
                              who,
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              '$title · ${cfg.scope}',
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 11,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_rounded, size: 20, color: c.muted),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: openDesign,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
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
                      Icon(Icons.tune_rounded, size: 20, color: c.ai),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'tweaks_title'),
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              tr(context, 'tweaks_sub'),
                              style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 11,
                                color: c.ai,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: c.ai,
                      ),
                    ],
                  ),
                ),
              ),
              _ProfileLink(
                icon: Icons.widgets_rounded,
                title: tr(context, 'all_sections'),
                sub: tr(context, 'all_sections_sub'),
                onTap: () => Navigator.of(context).push(
                  sfPageRoute(
                    SfTheme(
                      colors: c,
                      child: MenuHub(colors: c, role: cfg.role),
                    ),
                  ),
                ),
              ),
              _ProfileLink(
                icon: Icons.auto_awesome_rounded,
                title: tr(context, 'all_modules'),
                sub: tr(context, 'all_modules_sub'),
                onTap: () => Navigator.of(
                  context,
                ).push(sfPageRoute(ModulesHub(colors: c))),
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
                            border: Border(
                              bottom: i < rows.length - 1
                                  ? BorderSide(color: c.border)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rows[i].$1,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 13,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                '${rows[i].$2} ›',
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 12,
                                  color: c.muted,
                                ),
                              ),
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
                    color: c.surface2,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    tr(context, 'btn_switch_role'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.ink2,
                    ),
                  ),
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
                    color: c.surface2,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    tr(context, 'btn_logout'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.danger,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Build marker — lets a tester confirm at a glance which APK is running.
              Center(
                child: Text(
                  'StarForge EDU · v1.0.8',
                  style: TextStyle(
                    fontFamily: SfType.mono,
                    fontSize: 10.5,
                    color: c.muted2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// A bordered nav card used on the profile (modules / sections / …).
class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// Edit-profile page — change avatar, display name and job title (saved to the
/// in-memory store, applied live across the app).
class EditProfileScreen extends StatefulWidget {
  final RoleConfig cfg;
  final SfColors colors;
  const EditProfileScreen({super.key, required this.cfg, required this.colors});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _title = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final store = AppScope.of(context);
    _name.text = store.nameOverride ?? widget.cfg.who;
    _title.text = store.titleOverride ?? widget.cfg.roleTitle;
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  Widget _field(
    SfColors c,
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: c.muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.muted),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  cursorColor: c.primary,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
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
          title: Text(
            tr(context, 'edit_profile'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(sfPageRoute(AvatarPickerScreen(colors: c))),
                child: Stack(
                  children: [
                    SfAvatar(
                      name: _name.text.isEmpty ? widget.cfg.who : _name.text,
                      size: 88,
                      color: widget.cfg.accent(c),
                      choice: store.avatarChoice,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                tr(context, 'change_photo'),
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _field(c, tr(context, 'stu_fname'), _name, Icons.person_rounded),
            _field(
              c,
              tr(context, 'edit_jobtitle'),
              _title,
              Icons.badge_rounded,
            ),
            Text(
              '${tr(context, 'set_role')}: ${widget.cfg.label} · ${widget.cfg.scope}',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11,
                color: c.muted,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
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
          child: SfButton(
            icon: Icons.check_rounded,
            label: tr(context, 'save'),
            primary: true,
            onTap: () {
              store.setProfile(name: _name.text, title: _title.text);
              Navigator.of(context).maybePop();
              _snack(
                context,
                tr(context, 'profile_saved'),
                bg: const Color(0xFF4F7B3B),
              );
            },
          ),
        ),
      ),
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
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.muted2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'currency_pick'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
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
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            kCurrencySym[cur]!,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context, nameKey[cur]!),
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                kCurrencyCode[cur]!,
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 11,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          settings.currency == cur
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 22,
                          color: settings.currency == cur
                              ? c.primary
                              : c.muted2,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
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
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.muted2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'lang_pick'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
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
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            o.$2,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(context, o.$3),
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Icon(
                          settings.lang == o.$1
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 22,
                          color: settings.lang == o.$1 ? c.primary : c.muted2,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
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

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    Color? vColor,
    bool last = false,
  }) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              color: c.muted,
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: vColor ?? c.ink,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final store = AppScope.of(context);
    final audit = role == SfRole.audit;
    final ceo = role == SfRole.ceo;
    final reportRevenue = store.scopedRevenue(store.stats.revenue);
    final reportStudents = store.scopedStudents(
      int.tryParse(store.stats.students.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
    );
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
            tr(context, audit ? 'report_audit_title' : 'report_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _CeoContextFilter(showBranches: false),
            const SizedBox(height: 12),
            // Header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.primary, c.primaryHover],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SfStar(size: 22, color: Colors.white),
                      const SizedBox(width: 9),
                      Text(
                        'StarForge EDU',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, audit ? 'report_audit_title' : 'report_title'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    tr(context, 'report_period'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (audit) ...[
              _setSec(c, tr(context, 'report_summary')),
              SfCard(
                child: Column(
                  children: [
                    _kv(context, tr(context, 'kpi_open_flags'), '12'),
                    _kv(context, tr(context, 'kpi_active_cases'), '8'),
                    _kv(
                      context,
                      tr(context, 'kpi_anom_score'),
                      '2.4%',
                      vColor: c.warn,
                    ),
                    _kv(
                      context,
                      tr(context, 'kpi_compliance'),
                      '96.8%',
                      vColor: c.success,
                      last: true,
                    ),
                  ],
                ),
              ),
              _setSec(c, tr(context, 'report_compliance')),
              SfCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: HBars(
                    rows: [
                      HBarRow('Yunusobod', 98, '98%', c.success),
                      HBarRow('Chilonzor', 97, '97%', c.success),
                      HBarRow('Mirobod', 95, '95%', c.warn),
                      HBarRow('Sebzor', 89, '89%', c.danger),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _setSec(c, tr(context, 'report_summary')),
              SfCard(
                child: Column(
                  children: [
                    _kv(
                      context,
                      tr(context, 'kpi_revenue'),
                      fmtMoneyMln(reportRevenue),
                      vColor: c.success,
                    ),
                    _kv(
                      context,
                      tr(context, 'kpi_students'),
                      '$reportStudents',
                    ),
                    _kv(
                      context,
                      tr(context, 'kpi_attendance'),
                      '91.2%',
                      vColor: c.primary,
                    ),
                    _kv(
                      context,
                      tr(context, 'kpi_debt'),
                      fmtMoneyMln(store.stats.debt),
                      vColor: c.warn,
                      last: true,
                    ),
                  ],
                ),
              ),
              _setSec(c, tr(context, 'report_finance')),
              SfCard(
                child: Column(
                  children: [
                    _kv(
                      context,
                      tr(context, 'tx_inflow'),
                      fmtMoneyMln(store.inflowTotal),
                      vColor: c.success,
                    ),
                    _kv(
                      context,
                      tr(context, 'tx_outflow'),
                      fmtMoneyMln(store.outflowTotal),
                      vColor: c.danger,
                    ),
                    _kv(
                      context,
                      'JORIY QOLDIQ',
                      fmtMoneyMln(store.balance),
                      last: true,
                    ),
                  ],
                ),
              ),
              if (ceo) ...[
                _setSec(c, tr(context, 'report_branches')),
                SfCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: HBars(
                      ranked: true,
                      rows: [
                        for (final b in store.branches)
                          HBarRow(
                            b.name,
                            b.revenue.toDouble(),
                            fmtMoneyMln(b.revenue),
                            b.mark,
                            mark: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 6),
            Text(
              tr(context, 'report_gen'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 10.5,
                color: c.muted2,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
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
          child: GestureDetector(
            onTap: () => _showReportFormatPicker(context, role),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              // mainAxisSize.max + center keeps it full-width & centred without the
              // aligned-Container greedily filling the bottomNavigationBar height.
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'report_export'),
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

/// Opens a dedicated mobile page before a file is exported. This avoids an
/// accidental download and makes all four formats visible to the user.
void _showReportFormatPicker(
  BuildContext context,
  SfRole role, {
  SfColors? colors,
}) {
  // BranchWorkspace is a pushed route and its State context sits above the
  // local SfTheme wrapper. Passing the known route colours avoids looking up a
  // theme from that outer context (the source of "SfTheme not found").
  final c = colors ?? SfTheme.of(context);
  Navigator.of(
    context,
  ).push(sfPageRoute(ReportFormatScreen(colors: c, role: role)));
}

class ReportFormatScreen extends StatelessWidget {
  final SfColors colors;
  final SfRole role;
  const ReportFormatScreen({
    super.key,
    required this.colors,
    required this.role,
  });
  @override
  Widget build(BuildContext context) {
    final c = colors;
    const formats = [
      ('word', 'Word document', 'DOCX', Icons.description_rounded),
      ('excel', 'Excel spreadsheet', 'XLSX', Icons.table_chart_rounded),
      ('html', 'HTML page', 'HTML', Icons.code_rounded),
      ('csv', 'CSV data', 'CSV', Icons.grid_on_rounded),
    ];
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          title: Text(
            'Hisobot formati',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Yuklab olishdan oldin formatni tanlang.',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12.5,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 14),
            for (final format in formats)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async =>
                      _exportReport(context, role, format.$1, format.$2),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(format.$4, color: c.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            format.$2,
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Pill(format.$3, tone: PillTone.neutral),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.download_rounded,
                          size: 19,
                          color: c.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _exportReport(
  BuildContext context,
  SfRole role,
  String format,
  String label,
) async {
  final store = AppScope.of(context);
  final now = DateTime.now();
  final scope = store.allBranchesSelected
      ? 'Barcha filiallar'
      : store.selectedBranch;
  final revenue = store.scopedRevenue(store.stats.revenue);
  final students = store.scopedStudents(
    int.tryParse(store.stats.students.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
  );
  final rows = <(String, String)>[
    ('Scope', scope),
    (
      'Period',
      '${store.selectedRange.start.toIso8601String().substring(0, 10)} — ${store.selectedRange.end.toIso8601String().substring(0, 10)}',
    ),
    ('Revenue', '$revenue'),
    ('Students', '$students'),
    ('Attendance', '${store.scopedAttendance(91)}%'),
    ('Generated', now.toIso8601String()),
  ];
  try {
    final dir = await getApplicationDocumentsDirectory();
    final ext = switch (format) {
      'word' => 'docx',
      'excel' => 'xlsx',
      _ => format,
    };
    final file = File(
      '${dir.path}/starforge_report_${now.millisecondsSinceEpoch}.$ext',
    );
    final csv = [
      'Metric,Value',
      ...rows.map((r) => '${r.$1},"${r.$2.replaceAll('"', '""')}"'),
    ].join('\n');
    final html =
        '<!doctype html><html><head><meta charset="utf-8"><title>StarForge report</title></head><body><h1>StarForge EDU</h1><table border="1">${rows.map((r) => '<tr><th>${r.$1}</th><td>${r.$2}</td></tr>').join()}</table></body></html>';
    await file.writeAsString(format == 'csv' ? csv : html);
    if (context.mounted) {
      _snack(
        context,
        '$label: ${file.path.split('/').last} tayyor',
        bg: const Color(0xFF4F7B3B),
      );
    }
  } catch (_) {
    if (context.mounted) _snack(context, 'Hisobotni saqlab bo‘lmadi');
  }
}

/// "+ Yangi …" creation sheet opened by the dashboard's new-entity button.
/// A real little form (name · owner · note) that validates and confirms — the
/// demo has no backend, so a successful submit shows a toast and closes.
void _showCreateSheet(
  BuildContext context,
  AppSettings settings,
  String titleKey,
) {
  final c = settings.colors;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SfTheme(
      colors: c,
      child: _CreateSheet(c: c, titleKey: titleKey),
    ),
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

  Widget _input(
    String hint,
    TextEditingController ctrl, {
    bool multiline = false,
  }) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: multiline ? 3 : 1,
        onChanged: (_) {
          if (_err != null) setState(() => _err = null);
        },
        style: TextStyle(
          fontFamily: SfType.ui,
          fontSize: 14,
          color: c.ink,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: SfType.ui,
            color: c.muted2,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, widget.titleKey),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _input(tr(context, 'create_name'), _name),
                _input(tr(context, 'create_owner'), _owner),
                _input(tr(context, 'create_note'), _note, multiline: true),
                if (_err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      tr(context, _err!),
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.danger,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.borderStrong),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            tr(context, 'create_cancel'),
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.ink2,
                            ),
                          ),
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
                          _snack(
                            context,
                            tr(context, 'create_done'),
                            bg: const Color(0xFF4F7B3B),
                          );
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            tr(context, 'create_submit'),
                            style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
          title: Text(
            tr(context, 'avatar_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: SfAvatar(name: 'Sardor Rashidov', size: 96, choice: cur),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                tr(context, 'avatar_eyebrow'),
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12.5,
                  color: c.muted,
                ),
              ),
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
  const _AvatarSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.isSel,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: c.muted,
          ),
        ),
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
                        color: isSel(selected, opt)
                            ? c.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
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
  // Mobile settings must be a normal route: a bottom sheet/drawer makes the
  // numerous design and wallpaper choices hard to use on a phone.
  final c = SettingsScope.of(context).colors;
  Navigator.of(context).push(
    sfPageRoute(
      SfTheme(
        colors: c,
        child: SettingsScreen(colors: c),
      ),
    ),
  );
}

/// Shared design-control sections (palette · theme · layout · density · pattern
/// · font) used by both the live panel and the Sozlamalar route.
List<Widget> _designControls(
  BuildContext context,
  AppSettings settings,
  SfColors c,
) {
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
          _PalCard(
            p: kPalettes[i],
            selected: settings.palette == i,
            onTap: () => settings.setPalette(i),
          ),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_theme')),
    Row(
      children: [
        Expanded(
          child: _ChoiceCard(
            icon: Icons.light_mode_rounded,
            label: tr(context, 'theme_light'),
            selected: !settings.dark,
            onTap: () => settings.setDark(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChoiceCard(
            icon: Icons.dark_mode_rounded,
            label: tr(context, 'theme_dark'),
            selected: settings.dark,
            onTap: () => settings.setDark(true),
          ),
        ),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, '${tr(context, 'tw_layout')} · 5'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      // A fixed, generous height prevents the label + description from
      // overflowing on smaller phone widths or with a larger system font.
      mainAxisExtent: 96,
      children: [
        for (int i = 0; i < kLayouts.length; i++)
          _LayCard(
            lay: kLayouts[i],
            selected: settings.layout == i,
            onTap: () => settings.setLayout(i),
          ),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_density')),
    _setSeg(c, [
      (
        tr(context, 'tw_dense_s'),
        settings.density == 0,
        () => settings.setDensity(0),
      ),
      (
        tr(context, 'tw_dense_m'),
        settings.density == 1,
        () => settings.setDensity(1),
      ),
      (
        tr(context, 'tw_dense_l'),
        settings.density == 2,
        () => settings.setDensity(2),
      ),
    ]),
    const SizedBox(height: 22),
    _setSec(c, '${tr(context, 'tw_pattern')} · 5'),
    Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (int i = 0; i < kPatterns.length; i++)
          _setChip(
            c,
            tr(
              context,
              ['pat_none', 'pat_dots', 'pat_grid', 'pat_tile', 'pat_topo'][i],
            ),
            settings.pattern == kPatterns[i],
            () => settings.setPattern(kPatterns[i]),
          ),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, 'Chat dizayni'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      mainAxisExtent: 166,
      children: [
        for (int i = 0; i < kChatDesigns.length; i++)
          _ChatDesignCard(
            design: kChatDesigns[i],
            label: const [
              'Telegram',
              'WhatsApp',
              'Modern Dark',
              'Glass',
              'Gradient',
              'Minimal',
              'Neon',
              'Nature',
            ][i],
            selected: settings.chatDesign == kChatDesigns[i],
            onTap: () => settings.setChatDesign(kChatDesigns[i]),
          ),
      ],
    ),
    const SizedBox(height: 14),
    _setSec(c, 'Chat oboyalari · 10'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      mainAxisExtent: 92,
      children: [
        for (int i = 0; i < kChatWallpapers.length; i++)
          _ChatWallpaperCard(
            wallpaper: kChatWallpapers[i],
            label: _chatWallpaperName(kChatWallpapers[i]),
            colors: c,
            selected: settings.chatWallpaper == kChatWallpapers[i],
            customPath: settings.chatWallpaperPath,
            onTap: () async {
              final wallpaper = kChatWallpapers[i];
              if (wallpaper != SfChatWallpaper.custom) {
                settings.setChatWallpaper(wallpaper);
                return;
              }
              final image = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (image != null) settings.setChatWallpaperPath(image.path);
            },
          ),
      ],
    ),
    const SizedBox(height: 22),
    _setSec(c, tr(context, 'tw_font')),
    _setSeg(c, [
      for (int i = 0; i < kFonts.length; i++)
        (kFonts[i].$2, settings.font == i, () => settings.setFont(i)),
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
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(-14, 0),
                ),
              ],
            ),
            child: SafeArea(
              left: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context, 'tweaks_title'),
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                tr(context, 'tweaks_sub'),
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 11,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.surface2,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: c.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: c.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        // Sections moved out of the design panel into Profile →
                        // "Barcha bo'limlar". This panel is design-only now.
                        ..._designControls(context, settings, c),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: settings.reset,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                border: Border.all(color: c.borderStrong),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                tr(context, 'tw_reset'),
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink2,
                                ),
                              ),
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
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                tr(context, 'tw_done'),
                                style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// A nav-layout preview card (mini chrome thumbnail + name + description).
class _LayCard extends StatelessWidget {
  final SfLayout lay;
  final bool selected;
  final VoidCallback onTap;
  const _LayCard({
    required this.lay,
    required this.selected,
    required this.onTap,
  });
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
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayMini(id: lay.id, c: c),
            const SizedBox(height: 6),
            Text(
              tr(context, lay.nameKey),
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            Text(
              tr(context, lay.descKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 9.5,
                color: c.muted,
              ),
            ),
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
        content = Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.24,
            heightFactor: 1,
            child: Container(color: bar),
          ),
        );
        break;
      case 'rail':
        content = Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.12,
            heightFactor: 1,
            child: Container(color: bar),
          ),
        );
        break;
      case 'topbar':
        content = Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.32,
            child: Container(color: bar),
          ),
        );
        break;
      case 'dock':
        content = Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 0.28,
              child: Container(
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
        break;
      default: // zen
        content = const SizedBox.shrink();
    }
    return Container(
      height: 26,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Tappable visual preview of a chat theme. A compact header, two bubbles and
/// a composer make the colour and shape readable before the user applies it.
class _ChatDesignCard extends StatelessWidget {
  final SfChatDesign design;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChatDesignCard({
    required this.design,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? c.primary.withValues(alpha: 0.08) : c.surface,
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              Expanded(child: _ChatDesignMini(design: design)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: c.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _chatWallpaperName(SfChatWallpaper wallpaper) => switch (wallpaper) {
  SfChatWallpaper.telegramClouds => 'Telegram Clouds',
  SfChatWallpaper.whatsappPattern => 'WhatsApp Pattern',
  SfChatWallpaper.mountains => 'Mountains',
  SfChatWallpaper.aurora => 'Aurora',
  SfChatWallpaper.space => 'Space',
  SfChatWallpaper.ocean => 'Ocean',
  SfChatWallpaper.sakura => 'Sakura',
  SfChatWallpaper.abstract => 'Abstract',
  SfChatWallpaper.gradient => 'Gradient',
  SfChatWallpaper.blur => 'Blur',
  SfChatWallpaper.custom => 'Gallery image',
};

/// Tappable sample of a real chat wallpaper. The preview carries two bubbles
/// so the user can judge contrast before applying it to every conversation.
class _ChatWallpaperCard extends StatelessWidget {
  final SfChatWallpaper wallpaper;
  final String label;
  final SfColors colors;
  final bool selected;
  final String? customPath;
  final VoidCallback onTap;
  const _ChatWallpaperCard({
    required this.wallpaper,
    required this.label,
    required this.colors,
    required this.selected,
    required this.customPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final isCustom = wallpaper == SfChatWallpaper.custom;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? c.primary.withValues(alpha: .07) : c.surface,
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ChatWallpaper(
                        style: wallpaper,
                        colors: colors,
                        baseColor: const Color(0xFFEAF4FC),
                        accentColor: colors.primary,
                        customPath: customPath,
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          width: 50,
                          height: 13,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .82),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          width: 56,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                      if (isCustom && customPath == null)
                        Center(
                          child: Container(
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .28),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: c.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatDesignMini extends StatelessWidget {
  final SfChatDesign design;
  const _ChatDesignMini({required this.design});

  @override
  Widget build(BuildContext context) {
    final p = _chatVisualStyle(design, SfColors.light);
    final tiny = TextStyle(
      fontFamily: SfType.ui,
      fontSize: 5.8,
      fontWeight: FontWeight.w700,
      color: p.appBarText,
      height: 1,
    );
    Widget bubble(String text, bool mine) => Container(
      constraints: const BoxConstraints(maxWidth: 86),
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: mine && p.outgoingGradient != null
            ? null
            : (mine ? p.outgoing : p.incoming),
        gradient: mine ? p.outgoingGradient : null,
        border: Border.all(
          color: mine ? p.outgoingBorder : p.incomingBorder,
          width: .5,
        ),
        borderRadius: p.bubbleRadius(mine).resolve(TextDirection.ltr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tiny.copyWith(
                color: mine ? p.outgoingText : p.incomingText,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '10:24',
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 4.6,
              color: mine ? p.outgoingTime : p.incomingTime,
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: p.canvas,
          gradient: design == SfChatDesign.gradient
              ? const LinearGradient(
                  colors: [Color(0xFFF4E8FC), Color(0xFFFFE8F1)],
                )
              : null,
        ),
        child: Column(
          children: [
            Container(
              height: 21,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: p.appBar,
                gradient: p.appBarGradient,
                border: Border(bottom: BorderSide(color: p.border, width: .5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [p.accent, p.action.withValues(alpha: .65)],
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Madina', maxLines: 1, style: tiny),
                        Text(
                          'online',
                          maxLines: 1,
                          style: tiny.copyWith(
                            fontSize: 4.6,
                            color: p.presence,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert_rounded, size: 10, color: p.appBarText),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (design == SfChatDesign.whatsapp)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ChatWallpaperPainter(
                          SfChatWallpaper.whatsappPattern,
                          p.muted.withValues(alpha: .22),
                          p.accent,
                        ),
                      ),
                    ),
                  if (design == SfChatDesign.neon)
                    Positioned(
                      top: -24,
                      right: -15,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 6, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bubble('Salom! Bugun dars bormi?', false),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: bubble('Ha, 18:00 da.', true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 19,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: p.composer,
                border: Border(top: BorderSide(color: p.border, width: .5)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 9,
                    color: p.icon,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 11,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: p.input,
                        border: Border.all(color: p.border, width: .5),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        'Message',
                        style: tiny.copyWith(fontSize: 4.8, color: p.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.mic_rounded, size: 9, color: p.action),
                ],
              ),
            ),
          ],
        ),
      ),
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
          title: Text(
            tr(context, 'settings_title'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
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
                decoration: BoxDecoration(
                  border: Border.all(color: c.borderStrong),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  tr(context, 'tw_reset'),
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
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
  child: Text(
    t.toUpperCase(),
    style: TextStyle(
      fontFamily: SfType.ui,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: c.muted,
    ),
  ),
);

Widget _setSeg(SfColors c, List<(String, bool, VoidCallback)> items) =>
    Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
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
                    border: items[i].$2 ? Border.all(color: c.border) : null,
                  ),
                  child: Text(
                    items[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: items[i].$2 ? c.ink : c.muted,
                    ),
                  ),
                ),
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );

Widget _setChip(SfColors c, String label, bool on, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? c.primary : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : c.ink2,
          ),
        ),
      ),
    );

/// A palette swatch row used in the design settings.
class _PalCard extends StatelessWidget {
  final SfPalette p;
  final bool selected;
  final VoidCallback onTap;
  const _PalCard({
    required this.p,
    required this.selected,
    required this.onTap,
  });
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
          border: Border.all(
            color: selected ? p.primary : c.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Row(
                  children: [
                    Expanded(child: Container(color: p.primary)),
                    Expanded(child: Container(color: p.accent)),
                    Expanded(child: Container(color: p.swatch)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                p.name,
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
            if (selected)
              Icon(Icons.check_circle_rounded, size: 16, color: p.primary),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? c.primary : c.muted),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? c.primary : c.ink,
                ),
              ),
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
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        backgroundColor: bg ?? const Color(0xFF3A332A),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    return _ReferenceAttendancePage(state: this);
  }

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final c = widget.colors;
    final store = AppScope.of(context);
    final students = store.students;
    // CEO and audit are analytical roles. They can inspect the roster and
    // operational health, but only the manager workspace may record a mark.
    final canEdit = store.role == SfRole.manager;
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
          title: Text(
            'Davomat',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                canEdit
                    ? Icons.qr_code_scanner_rounded
                    : Icons.download_rounded,
                color: c.ink,
              ),
              tooltip: canEdit ? 'QR check-in' : 'Hisobotni yuklash',
              onPressed: () => _snack(
                context,
                canEdit
                    ? '📷 QR check-in rejimi (demo)'
                    : '✓ Davomat hisoboti tayyorlandi (demo)',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  _AttendanceInsights(readOnly: !canEdit),
                  const SizedBox(height: 10),
                  _FilterChips(
                    items: groups,
                    selected: gi,
                    onSelect: (i) => setState(() => gi = i),
                  ),
                  const SizedBox(height: 8),
                  SfSurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Donut(
                          size: 78,
                          thickness: 12,
                          segments: [
                            DonutSegment(present.toDouble(), c.success),
                            DonutSegment(
                              absentInGroup.toDouble() == 0 && present == 0
                                  ? 1
                                  : absentInGroup.toDouble(),
                              c.danger,
                            ),
                          ],
                          center: _mono(
                            context,
                            '${roster.isEmpty ? 0 : (present / roster.length * 100).round()}%',
                            size: 15,
                          ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SfCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < roster.length; i++)
                          _RosterRow(
                            s: roster[i],
                            present: !absent.contains(roster[i].name),
                            last: i == roster.length - 1,
                            onToggle: canEdit
                                ? () => setState(() {
                                    final n = roster[i].name;
                                    absent.contains(n)
                                        ? absent.remove(n)
                                        : absent.add(n);
                                  })
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              Container(
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
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.notifications_active_rounded,
                        label: "Yo'qlarga xabar ($absentInGroup)",
                        primary: false,
                        onTap: absentInGroup == 0
                            ? () => _snack(
                                context,
                                "Bu guruhda yo'q o'quvchi yo'q",
                              )
                            : () => _snack(
                                context,
                                '🔔 $absentInGroup ota-onaga xabar yuborildi (demo)',
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.check_circle_rounded,
                        label: 'Saqlash',
                        primary: true,
                        onTap: () => _snack(
                          context,
                          '✓ Davomat saqlandi · $present bor, $absentInGroup yo‘q',
                          bg: const Color(0xFF4F7B3B),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
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
                child: SfButton(
                  icon: Icons.insights_rounded,
                  label: 'Davomat hisoboti',
                  primary: true,
                  onTap: () =>
                      _snack(context, '✓ Analitik hisobot tayyorlandi (demo)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reference-style attendance workspace. It reads and mutates the existing
/// [absent] set and group index, preserving manager-only permissions.
class _ReferenceAttendancePage extends StatelessWidget {
  const _ReferenceAttendancePage({required this.state});

  final _AttendanceScreenState state;

  @override
  Widget build(BuildContext context) {
    final c = state.widget.colors;
    final store = AppScope.of(context);
    final students = store.students;
    final canEdit = store.role == SfRole.manager;
    final groups = <({String branch, String group})>[];
    for (final student in students) {
      final scope = (
        branch: studentProfile(student).branch,
        group: student.group,
      );
      if (!groups.contains(scope)) {
        groups.add(scope);
      }
    }
    final groupLabels = groups
        .map((scope) => '${scope.branch} · ${scope.group}')
        .toList();
    if (state.gi >= groups.length) state.gi = 0;
    final selectedScope = groups[state.gi];
    final roster = students
        .where(
          (student) =>
              student.group == selectedScope.group &&
              studentProfile(student).branch == selectedScope.branch,
        )
        .toList();
    final present = roster
        .where((student) => !state.absent.contains(student.name))
        .length;
    final absent = roster.length - present;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            RefLargeHeader(
              eyebrow: canEdit ? 'OPERATSION DAVOMAT' : 'FAOLIYAT TAHLILI',
              title: 'Davomat',
              subtitle: canEdit
                  ? 'Guruhni belgilang va ro‘yxatni yangilang'
                  : 'Faqat tahlil va hisobotlar',
              actions: [
                RefIconAction(
                  icon: canEdit
                      ? Icons.qr_code_scanner_rounded
                      : Icons.download_rounded,
                  tooltip: canEdit ? 'QR check-in' : 'Hisobotni yuklash',
                  onPressed: () => _snack(
                    context,
                    canEdit
                        ? '📷 QR check-in rejimi (demo)'
                        : '✓ Davomat hisoboti tayyorlandi (demo)',
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                children: [
                  if (!canEdit) ...[
                    RefStatusTile(
                      icon: Icons.visibility_rounded,
                      title: 'CEO ko‘rinishi · faqat tahlil va hisobotlar',
                      subtitle: 'Ma’lumotlar tahrirlanmaydi',
                      tone: RefMetricTone.primary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  RefSectionHeader(
                    title: 'Bugun',
                    subtitle:
                        '${groupLabels[state.gi]} · ${roster.length} o‘quvchi',
                  ),
                  const SizedBox(height: 8),
                  RefAdaptiveGrid(
                    minCellWidth: 142,
                    spacing: 8,
                    children: [
                      RefMetricCard(
                        label: 'Bor',
                        value: '$present',
                        icon: Icons.check_circle_rounded,
                        tone: RefMetricTone.success,
                      ),
                      RefMetricCard(
                        label: "Yo'q",
                        value: '$absent',
                        icon: Icons.cancel_rounded,
                        tone: RefMetricTone.danger,
                        uppercaseLabel: false,
                      ),
                      RefMetricCard(
                        label: 'Kechikdi',
                        value: '9',
                        icon: Icons.more_time_rounded,
                        tone: RefMetricTone.warning,
                      ),
                      RefMetricCard(
                        label: 'Ozod',
                        value: '4',
                        icon: Icons.event_available_rounded,
                        tone: RefMetricTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ReferenceGroupPicker(
                    groups: groupLabels,
                    selected: state.gi,
                    onChanged: (index) => state._update(() => state.gi = index),
                  ),
                  const SizedBox(height: 12),
                  _ReferenceAttendanceSummary(
                    present: present,
                    absent: absent,
                    total: roster.length,
                  ),
                  const SizedBox(height: 18),
                  RefSectionHeader(
                    title: 'Ro‘yxat',
                    subtitle: canEdit
                        ? 'Bosib holatni o‘zgartiring'
                        : 'Joriy holat',
                  ),
                  const SizedBox(height: 8),
                  for (final student in roster) ...[
                    _ReferenceRosterCard(
                      student: student,
                      present: !state.absent.contains(student.name),
                      enabled: canEdit,
                      onToggle: canEdit
                          ? () => state._update(() {
                              state.absent.contains(student.name)
                                  ? state.absent.remove(student.name)
                                  : state.absent.add(student.name);
                            })
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 18),
                  _ReferenceAttendanceInsight(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: canEdit
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Yo'q",
                                style: RefType.eyebrow(
                                  color: c.muted,
                                  size: 9.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              RefButton(
                                label: "Yo'qlarga xabar ($absent)",
                                kind: RefButtonKind.soft,
                                leading: Icons.notifications_active_rounded,
                                onPressed: () => _snack(
                                  context,
                                  absent == 0
                                      ? "Bu guruhda yo'q o'quvchi yo'q"
                                      : '🔔 $absent ota-onaga xabar yuborildi (demo)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RefButton(
                            label: 'Saqlash',
                            leading: Icons.check_circle_rounded,
                            onPressed: () => _snack(
                              context,
                              '✓ Davomat saqlandi · $present bor, $absent yo‘q',
                            ),
                          ),
                        ),
                      ],
                    )
                  : RefButton(
                      label: 'Davomat hisoboti',
                      block: true,
                      leading: Icons.insights_rounded,
                      onPressed: () => _snack(
                        context,
                        '✓ Analitik hisobot tayyorlandi (demo)',
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact group/branch selector for attendance. It replaces the horizontally
/// scrolling chip rail so every option stays discoverable on a phone.
class _ReferenceGroupPicker extends StatelessWidget {
  const _ReferenceGroupPicker({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  final List<String> groups;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final selectedLabel = groups[selected];
    return PopupMenuButton<int>(
      key: const ValueKey('attendance-group-selector'),
      tooltip: 'Guruhni tanlang',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: c.surface,
      elevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: RefRadius.lg),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var index = 0; index < groups.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(
                  index == selected
                      ? Icons.check_circle_rounded
                      : Icons.groups_rounded,
                  size: 18,
                  color: index == selected ? c.primary : c.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    groups[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(
                      size: 12.5,
                      weight: index == selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: RefRadius.md,
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: RefRadius.sm,
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.groups_rounded, size: 18, color: c.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guruh / filial',
                      style: RefType.eyebrow(size: 9, color: c.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RefType.ui(
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceAttendanceSummary extends StatelessWidget {
  const _ReferenceAttendanceSummary({
    required this.present,
    required this.absent,
    required this.total,
  });

  final int present;
  final int absent;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final rate = total == 0 ? 0 : (present / total * 100).round();
    return RefSurfaceCard(
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.successSoft,
              borderRadius: RefRadius.lg,
            ),
            child: SizedBox(
              width: 74,
              height: 74,
              child: Center(
                child: Text(
                  '$rate%',
                  style: RefType.mono(
                    size: 21,
                    weight: FontWeight.w800,
                    color: c.success,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guruhning joriy holati',
                  style: RefType.ui(
                    size: 14,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$present bor · $absent yo‘q · $total jami',
                  style: RefType.ui(size: 11.5, color: c.muted),
                ),
                const SizedBox(height: 11),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : present / total,
                  minHeight: 6,
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  color: c.success,
                  backgroundColor: c.surface3,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: c.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Bor',
                      style: RefType.ui(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.cancel_rounded, size: 13, color: c.danger),
                    const SizedBox(width: 4),
                    Text(
                      "Yo'q",
                      style: RefType.ui(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceRosterCard extends StatelessWidget {
  const _ReferenceRosterCard({
    required this.student,
    required this.present,
    required this.enabled,
    this.onToggle,
  });

  final Student student;
  final bool present;
  final bool enabled;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final attendanceColor = student.attendance >= 92
        ? c.success
        : student.attendance >= 85
        ? c.warn
        : c.danger;
    final statusColor = present ? c.success : c.danger;
    return RefPressable(
      onPressed: onToggle,
      borderRadius: RefRadius.lg,
      semanticLabel: '${student.name}, ${present ? 'bor' : "yo‘q"}',
      child: RefSurfaceCard(
        color: present ? c.surface : c.dangerSoft.withValues(alpha: .45),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SfAvatar(name: student.name, size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
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
                    '${student.group} · ${student.attendance}%',
                    style: RefType.ui(
                      size: 10.5,
                      color: attendanceColor,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: RefMotion.resolve(context, RefMotion.quick),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .12),
                borderRadius: RefRadius.pill,
                border: Border.all(color: statusColor.withValues(alpha: .18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    present ? Icons.check_rounded : Icons.close_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    present ? 'Bor' : "Yo'q",
                    style: RefType.ui(
                      size: 11,
                      weight: FontWeight.w800,
                      color: statusColor,
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

class _ReferenceAttendanceInsight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RefSectionHeader(
          title: 'Davomat tahlili',
          subtitle: 'Oxirgi 30 kun',
        ),
        const SizedBox(height: 8),
        RefSurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '94%',
                style: RefType.mono(
                  size: 24,
                  weight: FontWeight.w800,
                  color: c.success,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'O‘rtacha davomat · oxirgi 30 kun',
                style: RefType.ui(size: 11.5, color: c.muted),
              ),
              const SizedBox(height: 10),
              Sparkline(
                data: const [91, 93, 90, 94, 92, 95, 94],
                color: c.success,
                height: 42,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RefStatusTile(
          icon: Icons.workspace_premium_rounded,
          title: '9-B',
          subtitle: 'Eng yaxshi guruh · 98%',
          tone: RefMetricTone.success,
        ),
        const SizedBox(height: 8),
        RefStatusTile(
          icon: Icons.workspace_premium_rounded,
          title: '10-A',
          subtitle: 'Ikkinchi o‘rin · 97%',
          tone: RefMetricTone.success,
        ),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  final Student s;
  final bool present;
  final bool last;
  final VoidCallback? onToggle;
  const _RosterRow({
    required this.s,
    required this.present,
    required this.last,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: present ? c.surface : c.dangerSoft.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: present
                  ? c.border.withValues(alpha: 0.7)
                  : c.danger.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              SfAvatar(name: s.name, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      '${s.group} · ${s.attendance}%',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 10,
                        color: s.attendance >= 92
                            ? c.success
                            : s.attendance >= 85
                            ? c.warn
                            : c.danger,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: present ? c.successSoft : c.dangerSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (present ? c.success : c.danger).withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      present ? Icons.check_rounded : Icons.close_rounded,
                      size: 14,
                      color: present ? c.success : c.danger,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      present ? 'Bor' : "Yo'q",
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: present ? c.success : c.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decision-friendly attendance summary. It deliberately stays available in
/// the CEO's read-only view: analytics are useful there, roster editing is not.
class _AttendanceInsights extends StatelessWidget {
  final bool readOnly;
  const _AttendanceInsights({required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (readOnly)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.primary.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_rounded, size: 16, color: c.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'CEO ko‘rinishi · faqat tahlil va hisobotlar',
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.primaryInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SfCard(
          child: Column(
            children: [
              const SfCardHeader('Bugun'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                child: Row(
                  children: [
                    _AttendanceMetric('Bor', '487', c.success),
                    _AttendanceMetric("Yo‘q", '18', c.danger),
                    _AttendanceMetric('Kechikdi', '9', c.warn),
                    _AttendanceMetric('Ozod', '4', c.muted),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SO‘NGGI 7 KUN',
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 9.5,
                        letterSpacing: .5,
                        fontWeight: FontWeight.w800,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Sparkline(
                      data: const [91, 93, 90, 94, 92, 95, 94],
                      color: c.success,
                      height: 35,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _AttendanceFact('30 kun', '94%', c.success)),
            const SizedBox(width: 8),
            Expanded(
              child: _AttendanceFact('Eng yaxshi', 'Dushanba', c.primary),
            ),
            const SizedBox(width: 8),
            Expanded(child: _AttendanceFact('E’tibor', 'Juma', c.warn)),
          ],
        ),
        const SizedBox(height: 8),
        SfCard(
          child: Column(
            children: [
              const SfCardHeader('Eng yaxshi guruhlar'),
              _AttendanceGroupRank('9-B', '98%', c.success),
              _AttendanceGroupRank('10-A', '97%', c.success),
              _AttendanceGroupRank('IELTS', '96%', c.primary, last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttendanceMetric(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: SfType.mono,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: SfType.ui,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: SfTheme.of(context).muted,
          ),
        ),
      ],
    ),
  );
}

class _AttendanceFact extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttendanceFact(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 9,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceGroupRank extends StatelessWidget {
  final String group, percentage;
  final Color color;
  final bool last;
  const _AttendanceGroupRank(
    this.group,
    this.percentage,
    this.color, {
    this.last = false,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
          Text(
            percentage,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
    // Kassa daftari, To'lovlar, Mock imtihonlar, Kamera tahlili, Mukofotlar and
    // Qoidalar kitobi were removed from the hub per the founder's request.
    final modules = <(IconData, String, bool, Widget Function()?)>[
      (
        Icons.fact_check_rounded,
        'Davomat',
        true,
        () => AttendanceScreen(colors: c),
      ),
      (
        Icons.print_rounded,
        'Bosib chiqarish',
        true,
        () => PrintingScreen(colors: c),
      ),
      (
        Icons.record_voice_over_rounded,
        'AI suhbatdosh',
        true,
        () => SpeakingScreen(colors: c),
      ),
      (Icons.badge_rounded, 'Xodimlar · HR', true, () => HrScreen(colors: c)),
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
          title: Text(
            'Modullar',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
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
                      ? () => Navigator.of(context).push(
                          sfPageRoute(
                            SfTheme(colors: c, child: modules[i].$4!()),
                          ),
                        )
                      : () => _snack(
                          context,
                          '"${modules[i].$2}" — tez orada (demo)',
                        ),
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
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.ready,
    required this.onTap,
  });
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
                    color: (ready ? c.primary : c.muted).withValues(
                      alpha: 0.13,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: ready ? c.primary : c.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Pill(
                  ready ? 'Tayyor' : 'Tez orada',
                  tone: ready ? PillTone.success : PillTone.neutral,
                ),
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

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

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
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
