import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'settings.dart';
import 'i18n.dart';
import 'modules.dart';
import 'pages.dart';
import 'widgets.dart';

const _pad = EdgeInsets.fromLTRB(16, 4, 16, 24);

/// A focused dark palette for person/group pages and conversations. It keeps
/// the messaging experience coherent even when the rest of the school console
/// uses its light Saroy theme.
const _telegramColors = SfColors(
  bg: Color(0xFF101114),
  surface: Color(0xFF1B1C20),
  surface2: Color(0xFF292B30),
  surface3: Color(0xFF36383E),
  ink: Color(0xFFF4F5F7),
  ink2: Color(0xFFD3D5DA),
  muted: Color(0xFF9B9DA5),
  muted2: Color(0xFF656871),
  border: Color(0xFF2C2E34),
  borderStrong: Color(0xFF45474F),
  primary: Color(0xFF2AABEE),
  primaryHover: Color(0xFF49B8F2),
  primarySoft: Color(0xFF17394B),
  primaryInk: Color(0xFFBDE9FF),
  accent: Color(0xFF7B9CFF),
  accentSoft: Color(0xFF202D4C),
  accentInk: Color(0xFFD5DEFF),
  success: Color(0xFF57C777),
  successSoft: Color(0xFF173D25),
  warn: Color(0xFFF2B84B),
  warnSoft: Color(0xFF453615),
  danger: Color(0xFFFF7770),
  dangerSoft: Color(0xFF482426),
  ai: Color(0xFFC2A6FF),
  aiBg: [Color(0xFF27223B), Color(0xFF1D273C)],
  aiBorder: Color(0xFF4A4166),
);

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
    return GestureDetector(
      onTap: onTap,
      child: SfTap(
        scale: onTap == null ? 1.0 : 0.97,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(13),
          ),
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
                newLabel: tr(context, ceo ? 'btn_new_branch' : 'btn_new_group'),
                accent: c.primary,
                onReport: () => Navigator.of(
                  context,
                ).push(sfPageRoute(ReportScreen(colors: c, role: cfg.role))),
                onNew: () => _showCreateSheet(
                  context,
                  SettingsScope.of(context),
                  ceo ? 'create_branch' : 'create_group',
                ),
              ),
              const SizedBox(height: 14),
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
                  value: ceo ? '1 842' : '512',
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
                  value: '91.2%',
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
                                onTap: () => _showBranchSheet(context, b),
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
                label: newLabel,
                primary: true,
                accent: accent,
                onTap: onNew,
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

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final start = seg == 1
        ? 6
        : seg == 2
        ? 7
        : 0;
    final data = _all.sublist(start).map((e) => e * 1e6).toList();
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
                          onTap: () => setState(() => seg = i),
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
            child: AreaChart(
              color: widget.color,
              height: 144,
              data: data,
              labels: labels,
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
                onTap: () => go('approvals'),
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
                      _MiniBtn(
                        ok: true,
                        onTap: () => _quick(context, store, rows[i], true),
                      ),
                      const SizedBox(width: 4),
                      _MiniBtn(
                        ok: false,
                        onTap: () => _quick(context, store, rows[i], false),
                      ),
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
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: approved
              ? const Color(0xFF4F7B3B)
              : const Color(0xFF8A4232),
          content: Text(
            approved
                ? '✓ "${a.title}" tasdiqlandi'
                : '✗ "${a.title}" rad etildi',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
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
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            ok ? Icons.check_rounded : Icons.close_rounded,
            size: 15,
            color: ok ? c.success : c.danger,
          ),
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
};

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

class _StudentsScreenState extends State<StudentsScreen> {
  String query = '';
  int statusSel = 0; // all / debtor / paid / partial / risk
  int callSel = 0; // all / recent / mid / overdue
  int branchSel = 0;
  int levelSel = 0;
  bool showFilters = false;

  bool _statusOk(Student s) => switch (statusSel) {
    1 => s.debt > 0,
    2 => s.pay == 'paid',
    3 => s.pay == 'partial',
    4 => s.attendance < 85 || s.debt >= 1000000,
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

  @override
  Widget build(BuildContext context) {
    final all = AppScope.of(context).students;
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
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.group.toLowerCase().contains(q)) {
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SfHead(
          eyebrow: "${list.length} ${tr(context, 'unit_student')}",
          title: tr(context, 'students_title'),
        ),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                ],
              ),
              if (showFilters) ...[
                const SizedBox(height: 10),
                _filterRow(
                  tr(context, 'filter_status'),
                  statusF,
                  statusSel,
                  (i) => setState(() => statusSel = i),
                ),
                _filterRow(
                  tr(context, 'filter_call'),
                  callF,
                  callSel,
                  (i) => setState(() => callSel = i),
                ),
                _filterRow(
                  tr(context, 'filter_branch'),
                  branchF,
                  branchSel,
                  (i) => setState(() => branchSel = i),
                ),
                _filterRow(
                  tr(context, 'filter_level'),
                  levelF,
                  levelSel,
                  (i) => setState(() => levelSel = i),
                ),
              ],
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Mos keladigan yo‘q',
                  sub: 'Boshqa filtrni tanlang.',
                )
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

  Widget _filterRow(
    String label,
    List<String> items,
    int sel,
    ValueChanged<int> onSelect,
  ) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 6),
          _FilterChips(items: items, selected: sel, onSelect: onSelect),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: on ? c.ink : c.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? Colors.transparent : c.border),
        ),
        child: Row(
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
    final aColor = s.attendance >= 92
        ? c.success
        : s.attendance >= 85
        ? c.warn
        : c.danger;
    final days = studentCallDays(s);
    final call = _callTone(days);
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(sfPageRoute(StudentDetailScreen(student: s, colors: c))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SfAvatar(name: s.name, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
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
                        '${s.group} · ',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 10.5,
                          color: c.muted,
                        ),
                      ),
                      Text(
                        '${s.attendance}%',
                        style: TextStyle(
                          fontFamily: SfType.mono,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: aColor,
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
                // Call-recency is now the primary signal (not payment status).
                Pill(tr(context, call.key), tone: call.tone),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    s.debt > 0 ? fmtMoney(s.debt) : _callAgo(context, days),
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 10,
                      color: s.debt > 0 ? c.danger : c.muted,
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
  Widget build(BuildContext context) {
    final c = colors;
    final s = student;
    final p = studentProfile(s);
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
            Row(
              children: [
                SfAvatar(name: s.name, size: 60),
                const SizedBox(width: 13),
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
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.group,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 12.5,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill(t.$2, tone: t.$1),
              ],
            ),
            const SizedBox(height: 14),
            // Call-status banner — green/amber/red by how long since the last
            // parent call. Tapping places a (demo) call to the father.
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: callColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: callColor.withValues(alpha: 0.35)),
              ),
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
                    onTap: () => _snack(context, '📞 ${p.phone} (demo)'),
                  ),
                  _InfoRow(
                    '${tr(context, 'stu_father')} · ${p.fatherName}',
                    p.fatherPhone,
                    mono: true,
                    onTap: () => _snack(
                      context,
                      '📞 ${p.fatherName} · ${p.fatherPhone} (demo)',
                    ),
                  ),
                  _InfoRow(
                    '${tr(context, 'stu_mother')} · ${p.motherName}',
                    p.motherPhone,
                    mono: true,
                    last: true,
                    onTap: () => _snack(
                      context,
                      '📞 ${p.motherName} · ${p.motherPhone} (demo)',
                    ),
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
                    onTap: () => _snack(
                      context,
                      '📞 ${p.fatherName} · ${p.fatherPhone} (demo)',
                    ),
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
  Widget build(BuildContext context) {
    final c = _telegramColors;
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
              onPressed: () => _snack(
                context,
                '📞 ${p.fatherName} · ${p.fatherPhone} (demo)',
              ),
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
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
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  void _resolve(
    BuildContext context,
    AppStore store,
    Approval it,
    bool approved,
  ) {
    store.resolve(it, approved: approved);
    final posted = approved && it.amount > 0;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: approved
              ? const Color(0xFF4F7B3B)
              : const Color(0xFF8A4232),
          content: Text(
            approved
                ? (posted
                      ? '✓ Tasdiqlandi · ${fmtMoney(it.amount)} kassa daftariga yozildi'
                      : '✓ "${it.title}" tasdiqlandi')
                : '✗ "${it.title}" rad etildi',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          action: posted
              ? SnackBarAction(
                  label: 'Daftar',
                  textColor: Colors.white,
                  onPressed: () => Navigator.of(context).push(
                    sfPageRoute(LedgerScreen(colors: SfTheme.of(context))),
                  ),
                )
              : null,
        ),
      );
  }

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
              // The cash ledger banner was removed from Approvals — it lives in
              // its own module, not on the requests screen.
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                fontWeight: FontWeight.w600,
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
                                      borderRadius: BorderRadius.circular(8),
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ApprBtn(
                                          label: tr(context, 'btn_reject'),
                                          primary: false,
                                          onTap: () => _resolve(
                                            context,
                                            store,
                                            it,
                                            false,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _ApprBtn(
                                          label: tr(context, 'btn_approve'),
                                          primary: true,
                                          onTap: () => _resolve(
                                            context,
                                            store,
                                            it,
                                            true,
                                          ),
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
              child: Text(
                items[i],
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? c.bg : c.muted,
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
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: c.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 13,
                color: c.ink,
              ),
              cursorColor: c.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 13,
                  color: c.muted2,
                ),
              ),
            ),
          ),
        ],
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
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(999),
              ),
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
  Widget build(BuildContext context) {
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
                    return GestureDetector(
                      onTap: () => _showBranchSheet(context, b),
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
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                13,
                                14,
                                13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: b.mark,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: SfStar(
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.name,
                                          style: TextStyle(
                                            fontFamily: SfType.ui,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: c.ink,
                                          ),
                                        ),
                                        Text(
                                          '${fmtMoney(b.revenue)}/oy',
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
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: c.border),
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
                                    b.attendance >= 92 ? c.success : c.warn,
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
        padding: const EdgeInsets.symmetric(vertical: 9),
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: c.muted,
              ),
            ),
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
  const GroupInfo(
    this.name,
    this.branch,
    this.level,
    this.teacher,
    this.schedule,
    this.count,
    this.avgAtt,
    this.debtors,
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

List<GroupInfo> _groupsFrom(List<Student> students) {
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
  bool showFilters = false;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final students = AppScope.of(context).students;
    final groups = _groupsFrom(students);
    final branches = <String>[
      '__all',
      ...{for (final g in groups) g.branch},
    ];
    final levels = <String>[
      '__all',
      ...{for (final g in groups) g.level},
    ];
    if (branchSel >= branches.length) branchSel = 0;
    if (levelSel >= levels.length) levelSel = 0;
    final wantBranch = branches[branchSel];
    final wantLevel = levels[levelSel];
    final q = query.trim().toLowerCase();
    final list = groups.where((g) {
      if (wantBranch != '__all' && g.branch != wantBranch) return false;
      if (wantLevel != '__all' && g.level != wantLevel) return false;
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
    final active = (branchSel != 0 ? 1 : 0) + (levelSel != 0 ? 1 : 0);

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
    final c = _telegramColors;
    final t = thread;
    final s = student;
    final isGroup = t?.isGroup ?? false;
    final name = t?.name ?? s!.name;
    final detail = t?.group ?? s!.group;
    final online = t?.online ?? true;
    final status = online ? tr(context, 'online') : tr(context, 'chat_offline');
    final phone = s == null ? _phoneFor(name) : studentProfile(s).phone;
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
                      ? const [Color(0xFF223E55), Color(0xFF121B23)]
                      : const [Color(0xFF4A3548), Color(0xFF16171B)],
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
                const SizedBox(width: 8),
                _ChatProfileAction(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  color: c.primary,
                  onTap: () => _snack(context, '📞 $phone'),
                ),
                const SizedBox(width: 8),
                _ChatProfileAction(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: c.primary,
                  onTap: () => _snack(context, '🎥 Video qo‘ng‘iroq (demo)'),
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
                        : phone,
                    label: isGroup ? 'About' : 'Phone',
                    leading: isGroup
                        ? Icons.info_outline_rounded
                        : Icons.phone_outlined,
                    onTap: isGroup ? null : () => _snack(context, '📞 $phone'),
                  ),
                  const Divider(height: 1, color: Color(0xFF2C2E34)),
                  _TelegramInfoLine(
                    value: isGroup ? detail : 'Where is the cat?!!!',
                    label: isGroup ? 'Group' : 'Bio',
                    leading: isGroup
                        ? Icons.groups_rounded
                        : Icons.format_quote_rounded,
                  ),
                  const Divider(height: 1, color: Color(0xFF2C2E34)),
                  _TelegramInfoLine(
                    value: isGroup
                        ? '${detail.split('·').last.trim()} participants'
                        : '@${_usernameFor(name)}',
                    label: isGroup ? 'Members' : 'Username',
                    leading: Icons.alternate_email_rounded,
                  ),
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

  String _usernameFor(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
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
        colors: _telegramColors,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1B1C20),
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
                    color: _telegramColors.muted2,
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
        _recordStartedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted) _snack(context, 'Ovozli xabarni yozib bo‘lmadi');
    }
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
          title: Semantics(
            button: true,
            label:
                '${tr(context, th.isGroup ? 'chat_group_info' : 'chat_profile')} · ${th.name}',
            child: InkWell(
              key: const ValueKey('chat-profile-header'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openCabinet(th, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    if (th.isGroup)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Center(
                          child: SfStar(size: 14, color: Colors.white),
                        ),
                      )
                    else
                      SfAvatar(name: th.name, size: 32),
                    const SizedBox(width: 10),
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
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in thread.messages) ...[
                    _bubble(context, m),
                    const SizedBox(height: 8),
                  ],
                ],
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
                      color: c.muted,
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
                        borderRadius: BorderRadius.circular(22),
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
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _recording ? c.danger : c.primary,
                          borderRadius: BorderRadius.circular(20),
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

  Widget _bubble(BuildContext context, ChatMsg message) {
    final c = _telegramColors;
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface2,
          border: mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(mine ? 13 : 4),
            bottomRight: Radius.circular(mine ? 4 : 13),
          ),
        ),
        child: _ChatMessageBody(message: message, mine: mine),
      ),
    );
  }
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
  const _ChatMessageBody({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final textStyle = TextStyle(
      fontFamily: SfType.ui,
      fontSize: 13,
      height: 1.32,
      color: mine ? Colors.white : c.ink,
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
                      fmtMoneyMln(store.stats.revenue),
                      vColor: c.success,
                    ),
                    _kv(
                      context,
                      tr(context, 'kpi_students'),
                      store.stats.students,
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
            onTap: () => _snack(
              context,
              tr(context, 'report_exported'),
              bg: const Color(0xFF4F7B3B),
            ),
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
          .animate(
            CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      child: child,
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
      childAspectRatio: 2.4,
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
              child: _FilterChips(
                items: groups,
                selected: gi,
                onSelect: (i) => setState(() => gi = i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(14),
                ),
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
                              absent.contains(n)
                                  ? absent.remove(n)
                                  : absent.add(n);
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                          ? () =>
                                _snack(context, "Bu guruhda yo'q o'quvchi yo'q")
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
  const _RosterRow({
    required this.s,
    required this.present,
    required this.last,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SfAvatar(name: s.name, size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: present ? c.successSoft : c.dangerSoft,
                borderRadius: BorderRadius.circular(999),
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
