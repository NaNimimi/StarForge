import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_connection.dart';
import 'api_client.dart';
import 'data.dart';
import 'i18n.dart';
import 'pages.dart';
import 'productivity_hub.dart';
import 'reference_ui.dart';
import 'screens.dart';
import 'settings.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'web_mobile_pages.dart';
import 'live_pages.dart';
import 'notification_service.dart';

/// Mobile adaptation of the web console shell.
///
/// The desktop reference turns its sidebar into an off-canvas drawer below
/// 1100px.  This keeps that exact information architecture on a phone instead
/// of replacing it with a different product-level bottom tab bar. Page widgets
/// and their store-backed actions remain the existing Flutter implementation.
class Console extends StatefulWidget {
  final RoleConfig cfg;
  final VoidCallback onSwitchRole;
  const Console({super.key, required this.cfg, required this.onSwitchRole});

  @override
  State<Console> createState() => _ConsoleState();
}

/// Adaptive navigation modes. The selected presentation is now functional
/// rather than a settings-only preview.
enum _ConsoleLayout { sidebar, rail, topbar }

class _ConsoleState extends State<Console> {
  String _route = 'dash';
  bool _drawerOpen = false;
  DateTime? _lastBack;
  Timer? _notificationPoll;
  final Set<String> _knownNotificationIds = <String>{};
  bool _notificationFeedReady = false;
  bool _notificationPermissionAsked = false;
  bool _syncingNotifications = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureNotificationMonitor();
  }

  void _configureNotificationMonitor() {
    final session = ApiScope.maybeOf(context)?.notifier;
    if (session?.authenticated != true) {
      _notificationPoll?.cancel();
      _notificationPoll = null;
      _notificationFeedReady = false;
      _knownNotificationIds.clear();
      return;
    }
    _notificationPoll ??= Timer.periodic(
      const Duration(seconds: 90),
      (_) => unawaited(_syncDeviceNotifications()),
    );
    unawaited(_syncDeviceNotifications());
  }

  String _notificationId(Map<String, dynamic> record) {
    final id = record['id'] ?? record['uuid'] ?? record['notification_id'];
    if (id != null && '$id'.trim().isNotEmpty) return '$id';
    return '${record['created_at'] ?? ''}:${record['title'] ?? record['message'] ?? ''}';
  }

  bool _notificationUnread(Map<String, dynamic> record) {
    final state = record['is_read'] ?? record['read'] ?? record['status'];
    if (state is bool) return !state;
    final text = '$state'.toLowerCase();
    return text != 'read' && text != 'seen' && text != 'true';
  }

  String _notificationValue(
    Map<String, dynamic> record,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = record[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  Future<void> _syncDeviceNotifications() async {
    if (_syncingNotifications) return;
    final session = ApiScope.maybeOf(context)?.notifier;
    if (session?.authenticated != true) return;
    _syncingNotifications = true;
    try {
      await Future.wait([
        session!.refresh('notifications'),
        session.refresh('unreadNotifications'),
      ]);
      final records = session.records('notifications');
      final currentIds = records.map(_notificationId).toSet();
      if (!_notificationFeedReady) {
        _knownNotificationIds
          ..clear()
          ..addAll(currentIds);
        _notificationFeedReady = true;
        if (!_notificationPermissionAsked) {
          _notificationPermissionAsked = true;
          await DeviceNotificationService.instance.requestPermission();
        }
        return;
      }
      final newlyArrived = records
          .where(
            (record) =>
                !_knownNotificationIds.contains(_notificationId(record)) &&
                _notificationUnread(record),
          )
          .toList(growable: false);
      _knownNotificationIds
        ..clear()
        ..addAll(currentIds);
      for (final record in newlyArrived.take(3)) {
        final key = _notificationId(record);
        await DeviceNotificationService.instance.show(
          id: key.hashCode & 0x7fffffff,
          title: _notificationValue(record, const [
            'title',
            'subject',
            'heading',
          ], 'StarForge EDU'),
          body: _notificationValue(record, const [
            'body',
            'message',
            'description',
          ], 'Yangi bildirishnoma bor'),
        );
      }
    } catch (_) {
      // Notification delivery must never interrupt the active workspace when
      // a backend role lacks access or the device is briefly offline.
    } finally {
      _syncingNotifications = false;
    }
  }

  @override
  void didUpdateWidget(Console old) {
    super.didUpdateWidget(old);
    if (old.cfg.role != widget.cfg.role) {
      _route = 'dash';
      _drawerOpen = false;
    }
  }

  @override
  void dispose() {
    _notificationPoll?.cancel();
    super.dispose();
  }

  void _navigate(String route) {
    if (!roleCanNavigate(widget.cfg.role, route)) {
      setState(() {
        _route = 'dash';
        _drawerOpen = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Bu bo‘lim ${widget.cfg.label} roli uchun yopiq',
              style: TextStyle(
                fontFamily: SfType.ui,
                fontWeight: FontWeight.w600,
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    AppScope.of(context).rememberOpenedRoute(route);
    setState(() {
      _route = route;
      _drawerOpen = false;
    });
    final api = ApiScope.maybeOf(context)?.notifier;
    if (route == 'dash' && api?.authenticated == true) {
      // Re-entering the dashboard must always fetch a fresh backend snapshot.
      api!.refreshDashboard().catchError((_) {});
    }
  }

  void _handleBack() {
    if (_drawerOpen) {
      setState(() => _drawerOpen = false);
      return;
    }
    if (_route != 'dash') {
      _navigate('dash');
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null &&
        now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'exit_confirm'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontWeight: FontWeight.w600,
            ),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _page(SfColors colors) {
    final live = ApiScope.maybeOf(context)?.notifier?.authenticated ?? false;
    switch (_route) {
      case 'dash':
        return DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'tools':
        return ProductivityHub(role: widget.cfg.role, onNavigate: _navigate);
      case 'branches':
        return live
            ? const LiveCollectionPage(
                resource: 'branches',
                title: 'Filiallar',
                icon: Icons.account_tree_rounded,
              )
            : const BranchesScreen();
      case 'students':
        return live ? const LiveStudentsPage() : const StudentsScreen();
      case 'teachers':
        return live
            ? const LiveTeachersPage()
            : TeachersWorkspaceScreen(colors: colors);
      case 'employees':
        return live
            ? const LiveEmployeesPage()
            : HrWorkspaceScreen(colors: colors);
      case 'attendance':
        return live
            ? const LiveAttendanceAnalyticsPage()
            : AttendanceScreen(colors: colors);
      case 'finance':
      case 'report':
        if (live && widget.cfg.role == SfRole.audit && _route == 'finance') {
          return const _LiveDocumentPage(
            resource: 'paymentReconciliation',
            title: 'Moliyaviy solishtirish',
            icon: Icons.rule_folder_outlined,
          );
        }
        return live
            ? const LiveRevenueReportPage()
            : ReportScreen(colors: colors, role: widget.cfg.role);
      case 'groups':
        return live
            ? const LiveCollectionPage(
                resource: 'groups',
                title: 'Guruhlar',
                icon: Icons.workspaces_rounded,
              )
            : const WebGroupsPage();
      case 'messages':
        return live
            ? const LiveCollectionPage(
                resource: 'threads',
                title: 'Xabarlar',
                icon: Icons.chat_bubble_rounded,
              )
            : const WebMessagesPage();
      case 'approvals':
        return live
            ? const LiveCollectionPage(
                resource: 'approvals',
                title: 'Tasdiqlar · faqat ko‘rish',
                icon: Icons.lock_outline_rounded,
              )
            : const WebApprovalsPage();
      case 'payments':
        return live ? const LiveRevenueReportPage() : const WebPaymentsPage();
      case 'hr':
        return live ? const LiveEmployeesPage() : const WebHrPage();
      case 'parents':
        return live
            ? const LiveCollectionPage(
                resource: 'parents',
                title: 'Ota-onalar',
                icon: Icons.family_restroom_rounded,
              )
            : ParentsWorkspaceScreen(colors: colors);
      case 'departments':
        return live
            ? const LiveCollectionPage(
                resource: 'departments',
                title: 'Bo‘limlar',
                icon: Icons.account_balance_rounded,
              )
            : DepartmentsWorkspaceScreen(colors: colors);
      case 'meetings':
        return live
            ? const LiveCollectionPage(
                resource: 'meetings',
                title: 'Yig‘ilishlar',
                icon: Icons.event_rounded,
              )
            : MeetingsWorkspaceScreen(colors: colors);
      case 'schedule':
        return live
            ? const LiveCollectionPage(
                resource: 'schedule',
                title: 'Jadval',
                icon: Icons.calendar_month_rounded,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'anomalies':
        return live
            ? const LiveCollectionPage(
                resource: 'studentRisk',
                title: 'Risk va signallar',
                icon: Icons.flag_rounded,
              )
            : const AnomaliesScreen();
      case 'cases':
        return live
            ? _LiveUnavailablePage(
                title: 'Tekshiruv holatlari',
                onOpenSettings: () => _navigate('settings'),
                onBack: () => _navigate('dash'),
              )
            : const CasesScreen();
      case 'logs':
        return live
            ? const LiveCollectionPage(
                resource: 'audit',
                title: 'O‘zgarmas audit jurnali',
                icon: Icons.policy_rounded,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'history':
        return live
            ? const LiveCollectionPage(
                resource: 'audit',
                title: 'So‘nggi backend hodisalari',
                icon: Icons.history_rounded,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'comparison':
        return live
            ? const _LiveDocumentPage(
                resource: 'intelligenceBranches',
                title: 'Filiallarni solishtirish',
                icon: Icons.compare_arrows_rounded,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'aiusage':
        return live
            ? const _LiveDocumentPage(
                resource: 'aiUsage',
                secondaryResource: 'aiBudget',
                title: 'AI monitoring',
                icon: Icons.auto_awesome_outlined,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'permissions':
        return live
            ? const LiveCollectionPage(
                resource: 'accessPermissions',
                title: 'Ruxsatlar · faqat ko‘rish',
                icon: Icons.admin_panel_settings_outlined,
              )
            : buildAdminPage(_route, colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'ai':
        // The same assistant surface handles both modes: with a session it
        // calls the published AI endpoint, without one it shows the honest
        // "AI is not connected" state. A read-only request collection would
        // make the connected assistant impossible to use.
        return AiScreen(cfg: widget.cfg);
      case 'notifications':
        return live
            ? LiveNotificationsPage(onNavigate: _navigate)
            : NotificationsScreen(colors: colors, onNavigate: _navigate);
      case 'me':
        return ProfileScreen(
          cfg: widget.cfg,
          onSwitchRole: widget.onSwitchRole,
        );
      case 'settings':
        return const ApiConnectionScreen();
      default:
        // Authenticated workspaces must never fall back to seeded preview
        // figures. Keep the route discoverable and explain that its endpoint
        // is not published instead of presenting invented live data.
        if (live) {
          return _LiveUnavailablePage(
            title: _routeLabel(_route),
            onOpenSettings: () => _navigate('settings'),
            onBack: () => _navigate('dash'),
          );
        }
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
    }
  }

  List<TabSpec> get _bottomTabs => widget.cfg.tabs;

  String _routeLabel(String route) {
    for (final group in menuFor(widget.cfg.role)) {
      for (final item in group.items) {
        if (item.id == route) return menuLabel(context, item.label);
      }
    }
    return route;
  }

  Widget _pageViewport(SfColors colors) => AnimatedSwitcher(
    duration: RefMotion.resolve(context, RefMotion.standard),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey(_route),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: _page(colors),
        ),
      ),
    ),
  );

  Widget _content(SfColors colors) => _pageViewport(colors);

  Widget _drawerLayer(Widget content, {bool showNavigationOpener = false}) =>
      Stack(
        children: [
          content,
          if (showNavigationOpener)
            Positioned.fill(
              child: Align(
                alignment: const Alignment(-1, -.72),
                child: _MobileNavigationOpener(
                  onPressed: () => setState(() => _drawerOpen = true),
                ),
              ),
            ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _drawerOpen = false),
                child: ColoredBox(color: Colors.black.withValues(alpha: .48)),
              ),
            ),
          _WebSidebar(
            key: const ValueKey('console-navigation-drawer-layer'),
            cfg: widget.cfg,
            activeRoute: _route,
            open: _drawerOpen,
            onClose: () => setState(() => _drawerOpen = false),
            onNavigate: _navigate,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final colors = settings.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: SfTheme(
        colors: colors,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Match the design system's expanded breakpoint: from 840 px the
            // old full sidebar is useful and remains permanently visible.
            final expanded = constraints.maxWidth >= 840;
            // The original navigation is a persistent information-rich
            // sidebar. Keep it visible on tablets and desktop so secondary
            // destinations never disappear behind a menu. Phones retain the
            // compact bottom navigation and do not lose content width.
            final mode = expanded
                ? _ConsoleLayout.sidebar
                : _ConsoleLayout.topbar;
            final content = _content(colors);
            final main = switch (mode) {
              _ConsoleLayout.sidebar => Row(
                children: [
                  _WebSidebar(
                    cfg: widget.cfg,
                    activeRoute: _route,
                    open: true,
                    docked: true,
                    onClose: () {},
                    onNavigate: _navigate,
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  Expanded(child: content),
                ],
              ),
              _ConsoleLayout.rail => Row(
                children: [
                  _ConsoleRail(
                    cfg: widget.cfg,
                    tabs: _bottomTabs,
                    activeRoute: _route,
                    onSelect: _navigate,
                    onSwitchRole: widget.onSwitchRole,
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  Expanded(child: _drawerLayer(content)),
                ],
              ),
              _ => _drawerLayer(content, showNavigationOpener: true),
            };
            return Scaffold(
              backgroundColor: colors.bg,
              body: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.45,
                    colors: [
                      Color.alphaBlend(
                        colors.primary.withValues(alpha: .08),
                        colors.bg,
                      ),
                      colors.bg,
                    ],
                  ),
                ),
                child: SafeArea(bottom: false, child: main),
              ),
              bottomNavigationBar: !expanded && mode == _ConsoleLayout.topbar
                  ? _BubbleBottomNavigation(
                      tabs: _bottomTabs,
                      activeRoute: _route,
                      onSelect: _navigate,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _LiveUnavailablePage extends StatelessWidget {
  const _LiveUnavailablePage({
    required this.title,
    required this.onOpenSettings,
    required this.onBack,
  });

  final String title;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RefLargeHeader(
          eyebrow: 'LIVE WORKSPACE',
          title: title,
          subtitle: 'Раздел сохранён в навигации, но API ещё не опубликован',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            children: [
              RefStatusTile(
                icon: Icons.extension_off_outlined,
                title: 'Интеграция ещё не подключена',
                subtitle:
                    'Приложение не подменяет серверные данные демонстрационными. Подключите endpoint и права доступа для этого раздела.',
                tone: RefMetricTone.neutral,
              ),
              const SizedBox(height: 12),
              RefButton(
                label: 'Проверить подключение',
                leading: Icons.settings_ethernet_rounded,
                block: true,
                onPressed: onOpenSettings,
              ),
              const SizedBox(height: 8),
              RefButton(
                label: 'Вернуться на Dashboard',
                leading: Icons.arrow_back_rounded,
                kind: RefButtonKind.ghost,
                block: true,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveDocumentPage extends StatefulWidget {
  const _LiveDocumentPage({
    required this.resource,
    required this.title,
    required this.icon,
    this.secondaryResource,
  });

  final String resource;
  final String? secondaryResource;
  final String title;
  final IconData icon;

  @override
  State<_LiveDocumentPage> createState() => _LiveDocumentPageState();
}

class _LiveDocumentPageState extends State<_LiveDocumentPage> {
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final session = ApiScope.of(context);
      await session.refresh(widget.resource);
      if (widget.secondaryResource != null) {
        await session.refresh(widget.secondaryResource!);
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _label(String key) => key
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'(^|\s)\S'),
        (match) => match.group(0)!.toUpperCase(),
      );

  String _value(Object? value) {
    if (value == null) return '—';
    if (value is Map || value is Iterable) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return '$value';
      }
    }
    return '$value';
  }

  List<MapEntry<String, Object?>> _entries(Object? document, String prefix) {
    if (document is Map) {
      return Map<String, dynamic>.from(document).entries
          .map<MapEntry<String, Object?>>(
            (entry) => MapEntry('$prefix${entry.key}', entry.value),
          )
          .toList(growable: false);
    }
    return [MapEntry(prefix.isEmpty ? 'result' : prefix, document)];
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final primary = session.document(widget.resource);
    final secondary = widget.secondaryResource == null
        ? null
        : session.document(widget.secondaryResource!);
    final rows = [
      ..._entries(primary, ''),
      if (widget.secondaryResource != null)
        ..._entries(secondary, '${widget.secondaryResource}.'),
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          RefLargeHeader(
            eyebrow: 'LIVE API',
            title: widget.title,
            subtitle: 'Последнее состояние backend · потяните для обновления',
            actions: [
              RefIconAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Обновить',
                onPressed: _refreshing ? null : _refresh,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              children: [
                if (_refreshing && primary == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                else if (_error != null)
                  RefStatusTile(
                    icon: Icons.cloud_off_outlined,
                    title: 'Не удалось обновить',
                    subtitle: _error!,
                    tone: RefMetricTone.danger,
                    onTap: _refresh,
                  )
                else if (primary == null)
                  RefStatusTile(
                    icon: widget.icon,
                    title: 'Данных пока нет',
                    subtitle:
                        'Endpoint подключён, но backend не вернул документ для вашей области доступа.',
                    tone: RefMetricTone.neutral,
                    onTap: _refresh,
                  )
                else
                  for (var index = 0; index < rows.length; index++) ...[
                    RefStatusTile(
                      icon: index == 0
                          ? widget.icon
                          : Icons.data_object_rounded,
                      title: _label(rows[index].key),
                      subtitle: _value(rows[index].value),
                      tone: RefMetricTone.neutral,
                    ),
                    if (index < rows.length - 1) const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigationOpener extends StatelessWidget {
  const _MobileNavigationOpener({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final title = tr(context, 'all_sections');
    return Semantics(
      button: true,
      label: title,
      child: Tooltip(
        message: title,
        child: Material(
          color: Color.alphaBlend(c.primary.withValues(alpha: .1), c.surface),
          elevation: 4,
          shadowColor: c.primary.withValues(alpha: .2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(18),
            ),
            side: BorderSide(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('console-open-navigation'),
            onTap: onPressed,
            child: SizedBox(
              width: 46,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.menu_rounded, size: 24, color: c.primary),
                  ),
                  Positioned(
                    right: 4,
                    child: Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(99),
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

/// Mobile counterpart of the web navigation: one moving, liquid selection
/// bubble instead of five independently highlighted buttons.  The animated
/// background and icon lift keep the Telegram/iPhone-like tab transition while
/// retaining the web app's real navigation routes.
class _BubbleBottomNavigation extends StatelessWidget {
  const _BubbleBottomNavigation({
    required this.tabs,
    required this.activeRoute,
    required this.onSelect,
  });

  final List<TabSpec> tabs;
  final String activeRoute;
  final ValueChanged<String> onSelect;

  int get _selectedIndex {
    final index = tabs.indexWhere((tab) => tab.id == activeRoute);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final selected = _selectedIndex;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('console-bottom-navigation'),
        height: 82,
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: .98),
          border: Border(top: BorderSide(color: c.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .14
                    : .045,
              ),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return LayoutBuilder(
              builder: (context, navConstraints) {
                final itemWidth = navConstraints.maxWidth / tabs.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: RefMotion.resolve(context, RefMotion.standard),
                      curve: Curves.easeOutBack,
                      left: selected * itemWidth + 4,
                      top: 2,
                      width: itemWidth - 8,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: c.primary.withValues(alpha: .13),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < tabs.length; index++)
                          Expanded(
                            child: _BubbleNavItem(
                              tab: tabs[index],
                              active: selected == index,
                              onTap: () => onSelect(tabs[index].id),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BubbleNavItem extends StatelessWidget {
  const _BubbleNavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });
  final TabSpec tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final duration = RefMotion.resolve(context, RefMotion.standard);
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSlide(
          duration: duration,
          curve: Curves.easeOutBack,
          offset: active ? const Offset(0, -.08) : Offset.zero,
          child: AnimatedScale(
            duration: duration,
            curve: Curves.easeOutBack,
            scale: active ? 1.08 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab.icon,
                  size: active ? 24 : 21,
                  color: active ? c.primary : c.muted,
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  style: RefType.ui(
                    size: 10,
                    weight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? c.primary : c.muted,
                  ),
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Compact navigation for tablets.  It keeps the five primary destinations in
/// reach without wasting the wide canvas on a phone-sized bottom bar; the menu
/// button still exposes every secondary route and branch switcher.
class _ConsoleRail extends StatelessWidget {
  const _ConsoleRail({
    required this.cfg,
    required this.tabs,
    required this.activeRoute,
    required this.onSelect,
    required this.onSwitchRole,
  });

  final RoleConfig cfg;
  final List<TabSpec> tabs;
  final String activeRoute;
  final ValueChanged<String> onSelect;
  final VoidCallback onSwitchRole;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Tooltip(
                  message: cfg.label,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.ink,
                          Color.alphaBlend(
                            cfg.accent(c).withValues(alpha: .42),
                            c.ink,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: cfg.accent(c).withValues(alpha: .25),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: SfStar(size: 23, color: c.accent)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final active = tab.id == activeRoute;
                    return Tooltip(
                      message: tab.label,
                      child: Semantics(
                        button: true,
                        selected: active,
                        label: tab.label,
                        child: InkWell(
                          onTap: () => onSelect(tab.id),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: RefMotion.resolve(
                              context,
                              RefMotion.quick,
                            ),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: active
                                  ? c.primarySoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              tab.icon,
                              size: 22,
                              color: active ? c.primary : c.muted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Tooltip(
                  message: 'Ish maydonini almashtirish',
                  child: InkWell(
                    onTap: onSwitchRole,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.switch_account_rounded,
                        color: c.ink2,
                        size: 21,
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
}

class _WebSidebar extends StatelessWidget {
  final RoleConfig cfg;
  final String activeRoute;
  final bool open;
  final bool docked;
  final VoidCallback onClose;
  final ValueChanged<String> onNavigate;
  const _WebSidebar({
    super.key,
    required this.cfg,
    required this.activeRoute,
    required this.open,
    this.docked = false,
    required this.onClose,
    required this.onNavigate,
  });

  void _selectBranch(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: _ConsoleSheet(
          title: tr(context, 'filter_branch'),
          children: [
            _SheetChoice(
              label: tr(context, 'f_all_branches'),
              trailing:
                  '${store.branches.length} · ${store.branches.fold<int>(0, (sum, b) => sum + b.students)}',
              selected: store.allBranchesSelected,
              onTap: () {
                store.setBranchScope('__all');
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final branch in store.branches)
              _SheetChoice(
                label: branch.name,
                trailing: '${branch.students}',
                selected: store.selectedBranch == branch.name,
                onTap: () {
                  store.setBranchScope(branch.name);
                  Navigator.of(sheetContext).pop();
                },
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
    final api = ApiScope.maybeOf(context)?.notifier;
    final live = api?.authenticated == true;
    final liveScope = apiText(
      apiValue(api?.me ?? const {}, const [
        'branch_name',
        'branch',
        'tenant_name',
        'tenant',
        'organization_name',
        'organization',
        'scope',
      ]),
      fallback: 'Backend scope',
    );
    final groups = menuFor(cfg.role);
    final branchName = live
        ? liveScope
        : store.allBranchesSelected
        ? tr(context, 'f_all_branches')
        : store.selectedBranch;
    final branchSub = live
        ? 'Backend scope'
        : store.allBranchesSelected
        ? '${store.branches.length} · ${store.branches.fold<int>(0, (sum, b) => sum + b.students)} ${tr(context, 'unit_student')}'
        : '${store.selectedBranchData?.students ?? 0} ${tr(context, 'unit_student')}';
    final panel = Material(
      key: ValueKey(
        docked ? 'console-navigation-persistent' : 'console-navigation-drawer',
      ),
      color: c.surface,
      elevation: 18,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.ink,
                    Color.alphaBlend(c.primary.withValues(alpha: .54), c.ink),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: .19),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SfStar(size: 26, color: cfg.accent(c)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: RefType.ui(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: c.surface,
                            ),
                            children: [
                              const TextSpan(text: 'StarForge'),
                              TextSpan(
                                text: ' · EDU',
                                style: RefType.ui(
                                  size: 14.5,
                                  weight: FontWeight.w500,
                                  color: c.surface.withValues(alpha: .68),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          cfg.label.toUpperCase(),
                          style: RefType.eyebrow(color: c.accent, size: 9.5),
                        ),
                      ],
                    ),
                  ),
                  if (!docked)
                    _TopIcon(
                      icon: Icons.close_rounded,
                      onTap: onClose,
                      label: 'Close menu',
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: RefPressable(
                onPressed: live ? null : () => _selectBranch(context),
                borderRadius: const BorderRadius.all(Radius.circular(11)),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    border: Border.all(color: c.border),
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: cfg.accent(c),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.public_rounded,
                          size: 15,
                          color: c.surface,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branchName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RefType.ui(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              branchSub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RefType.ui(size: 10, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        live
                            ? Icons.lock_outline_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: c.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _SidebarSearchAndGroups(
                groups: groups,
                activeRoute: activeRoute,
                accent: cfg.accent(c),
                onNavigate: onNavigate,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SidebarQuickAction(
                          key: const ValueKey('sidebar-profile'),
                          icon: Icons.person_rounded,
                          label: tr(context, 'profile_title'),
                          selected: activeRoute == 'me',
                          onTap: () => onNavigate('me'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SidebarQuickAction(
                          key: const ValueKey('sidebar-settings'),
                          icon: Icons.settings_rounded,
                          label: menuLabel(context, 'Sozlamalar'),
                          selected: activeRoute == 'settings',
                          onTap: () => onNavigate('settings'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RefPressable(
                    onPressed: () => onNavigate('me'),
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border.all(color: c.border),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        children: [
                          SfAvatar(
                            name: cfg.who,
                            size: 36,
                            color: cfg.accent(c),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cfg.who,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RefType.ui(
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                Text(
                                  cfg.roleTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RefType.ui(size: 10, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: c.muted,
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
      ),
    );
    if (docked) return SizedBox(width: 272, child: panel);
    return AnimatedPositioned(
      duration: RefMotion.resolve(context, RefMotion.emphasized),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      left: open ? 0 : -288,
      width: 272,
      child: panel,
    );
  }
}

class _SidebarSearchAndGroups extends StatefulWidget {
  const _SidebarSearchAndGroups({
    required this.groups,
    required this.activeRoute,
    required this.accent,
    required this.onNavigate,
  });

  final List<MenuGroup> groups;
  final String activeRoute;
  final Color accent;
  final ValueChanged<String> onNavigate;

  @override
  State<_SidebarSearchAndGroups> createState() =>
      _SidebarSearchAndGroupsState();
}

class _SidebarSearchAndGroupsState extends State<_SidebarSearchAndGroups> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _copy(BuildContext context, String uz, String ru, String en) {
    return switch (SettingsScope.of(context).lang) {
      SfLang.uz => uz,
      SfLang.ru => ru,
      SfLang.en => en,
    };
  }

  String _normalise(String value) =>
      value.toLowerCase().replaceAll('‘', "'").replaceAll('’', "'").trim();

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final needle = _normalise(_query);
    final visibleGroups = <(MenuGroup, List<MenuItem>)>[
      for (final group in widget.groups)
        if ((
              group,
              group.items
                  .where((item) {
                    if (needle.isEmpty) return true;
                    final haystack = _normalise(
                      '${grpLabel(context, group.title)} '
                      '${menuLabel(context, item.label)} ${item.id}',
                    );
                    return haystack.contains(needle);
                  })
                  .toList(growable: false),
            )
            case final entry when entry.$2.isNotEmpty)
          entry,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: TextField(
            key: const ValueKey('sidebar-section-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            style: RefType.ui(size: 12.5, color: c.ink),
            decoration: InputDecoration(
              hintText: _copy(
                context,
                'Bo‘limlarni qidirish…',
                'Поиск разделов…',
                'Search sections…',
              ),
              hintStyle: RefType.ui(size: 12, color: c.muted),
              prefixIcon: Icon(Icons.search_rounded, size: 19, color: c.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('sidebar-section-search-clear'),
                      tooltip: _copy(
                        context,
                        'Qidiruvni tozalash',
                        'Очистить поиск',
                        'Clear search',
                      ),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: Icon(Icons.close_rounded, size: 18, color: c.muted),
                    ),
              filled: true,
              fillColor: c.surface2,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accent, width: 1.6),
              ),
            ),
          ),
        ),
        Expanded(
          child: visibleGroups.isEmpty
              ? Center(
                  key: const ValueKey('sidebar-search-empty'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 30,
                          color: c.muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _copy(
                            context,
                            'Bo‘lim topilmadi',
                            'Раздел не найден',
                            'No section found',
                          ),
                          textAlign: TextAlign.center,
                          style: RefType.ui(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _copy(
                            context,
                            'Boshqa so‘rovni kiriting',
                            'Попробуйте другой запрос',
                            'Try a different query',
                          ),
                          textAlign: TextAlign.center,
                          style: RefType.ui(size: 10.5, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  children: [
                    for (final entry in visibleGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 5),
                        child: Text(
                          grpLabel(context, entry.$1.title).toUpperCase(),
                          style: RefType.eyebrow(color: c.muted2, size: 9.5),
                        ),
                      ),
                      for (final item in entry.$2)
                        _SidebarItem(
                          item: item,
                          selected: widget.activeRoute == item.id,
                          accent: widget.accent,
                          onTap: () => widget.onNavigate(item.id),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SidebarQuickAction extends StatelessWidget {
  const _SidebarQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface2,
            border: Border.all(
              color: selected ? c.primary.withValues(alpha: .36) : c.border,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? c.primary : c.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RefType.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: selected ? c.primary : c.ink2,
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

class _SidebarItem extends StatelessWidget {
  final MenuItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final label = menuLabel(context, item.label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: RefPressable(
            onPressed: onTap,
            selected: selected,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(9)),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 17,
                    color: selected ? c.surface : c.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RefType.ui(
                        size: 13,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? c.surface : c.ink2,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 17,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.surface.withValues(alpha: .24)
                            : c.surface3,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        '${item.badge}',
                        style: RefType.mono(
                          size: 9.5,
                          weight: FontWeight.w700,
                          color: selected ? c.surface : c.ink2,
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

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  const _TopIcon({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 19, color: c.ink2),
        ),
      ),
    );
  }
}

class _ConsoleSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ConsoleSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: RefShadows.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: RefType.ui(
                size: 15.5,
                weight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;
  const _SheetChoice({
    required this.label,
    this.trailing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? c.surface2 : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: RefType.ui(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            if (trailing != null)
              Text(trailing!, style: RefType.mono(size: 10.5, color: c.muted)),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, color: c.primary, size: 17),
            ],
          ],
        ),
      ),
    );
  }
}

// Kept for the preferences sheet used by alternative console layouts.
// ignore: unused_element
class _SheetToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SheetToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RefType.ui(
                size: 12.5,
                weight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: c.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _SheetCaption extends StatelessWidget {
  final String text;
  const _SheetCaption(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 5),
    child: Text(
      text.toUpperCase(),
      style: RefType.eyebrow(color: SfTheme.of(context).muted, size: 10),
    ),
  );
}

// ignore: unused_element
class _PaletteOption extends StatelessWidget {
  final SfPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteOption({
    required this.palette,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(9)),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(
            color: selected ? c.primary : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(9)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                palette.name,
                overflow: TextOverflow.ellipsis,
                style: RefType.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
