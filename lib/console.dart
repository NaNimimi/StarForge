import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_connection.dart';
import 'api_client.dart';
import 'api_data_view.dart';
import 'api_store_adapter.dart';
import 'data.dart';
import 'i18n.dart';
import 'live_pages.dart';
import 'pages.dart';
import 'productivity_hub.dart';
import 'reference_ui.dart';
import 'screens.dart';
import 'settings.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'web_mobile_pages.dart';
import 'notification_service.dart';
import 'push_notification_service.dart';

const Map<String, Set<String>> _routeApiPermissions = {
  'branches': {'intelligence:read', 'users:read'},
  'groups': {'students:read', 'schedule:read'},
  'teachers': {'users:read'},
  'departments': {'users:read'},
  'hr': {'users:read'},
  'meetings': {'meetings:read'},
  'attendance': {'attendance:read', 'students:read'},
  'payments': {'payments:read'},
  'report': {'payments:read', 'finance:read'},
  'finance': {'payments:read'},
  'payroll': {'finance:read'},
  'leads': {'sales:read'},
  'enroll': {'placement:read'},
  'approvals': {'approvals:read'},
  'schedule': {'schedule:read'},
  'anomalies': {'intelligence:read'},
  'comparison': {'intelligence:read'},
  'fairness': {'card:read'},
  'logs': {'audit:read'},
  'history': {'audit:read'},
  'aiusage': {'ai:read'},
  'ai': {'ai:read'},
  'surveys': {'forms:read'},
  'messages': {'messaging:read'},
  'chats': {'messaging:read'},
  'permissions': {'users:read'},
  'cases': {'tasks:read', 'compliance:read', 'penalty:read'},
  'students': {'students:read'},
  'parents': {'parents:read'},
};

bool _backendAllowsRoute(ApiSession? session, SfRole role, String route) {
  if (session?.authenticated != true) return true;
  // The deployed Audit profile does not advertise `messaging:read`, while
  // its GET /messaging/threads endpoint is intentionally available for
  // oversight. Role navigation and the page resolver already force Audit
  // onto a read-only transcript, so do not redirect this legitimate route
  // back to Dashboard because of the incomplete capability list.
  if (role == SfRole.audit && (route == 'messages' || route == 'chats')) {
    return true;
  }
  final required = _routeApiPermissions[route];
  if (required == null || required.isEmpty) return true;
  return required.any(session!.hasPermission);
}

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
    // didChangeDependencies is triggered by every ApiSession notification.
    // Only the first authenticated pass may start the initial sync; otherwise
    // each completed resource refresh immediately launched another request.
    if (_notificationPoll != null) return;
    _notificationPoll = Timer.periodic(
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
    final readAt = record['read_at'];
    if (readAt != null && '$readAt'.trim().isNotEmpty) return false;
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
      final value = apiText(apiPresentationValue(record[key]));
      if (value.isNotEmpty) return value;
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
        session!.refreshNotificationHead(),
        session.refresh('unreadNotifications', force: true),
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
      final push = PushNotificationService.instance;
      final presentFallback = shouldPresentNotificationPollingFallback(
        pushAvailable: push.available,
        pushRegistered: push.registered,
      );
      if (!presentFallback) return;
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
          ], 'Откройте приложение, чтобы посмотреть подробности.'),
          payload: Map<String, dynamic>.from(record),
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
    final api = ApiScope.maybeOf(context)?.notifier;
    if (!roleCanNavigate(widget.cfg.role, route) ||
        !_backendAllowsRoute(api, widget.cfg.role, route)) {
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
    unawaited(_refreshRouteData(route));
  }

  /// Database directories can change after sign-in (for example when an
  /// operator creates a student in another session). Refresh their exact join
  /// set whenever the user opens the section, while leaving dashboard polling
  /// and unrelated endpoints untouched.
  Future<void> _refreshRouteData(String route) async {
    final session = ApiScope.maybeOf(context)?.notifier;
    if (session?.authenticated != true) return;
    final resources = switch (route) {
      'students' => const ['students', 'guardians', 'parents', 'groups'],
      'parents' => const ['parents', 'guardians', 'students', 'groups'],
      // Both the writable Manager workspace and Audit oversight must refresh
      // the same authoritative thread list when opened. Refreshing threads
      // also reloads the published messaging contact directory.
      'messages' || 'chats' => const ['threads'],
      _ => const <String>[],
    };
    for (final resource in resources) {
      try {
        await session!.refresh(resource, force: true);
      } on ApiException catch (error) {
        final primary = resource == resources.first;
        if (primary && mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(error.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          break;
        }
        // Optional joins can legitimately be forbidden for scoped roles.
        // Other failures are kept in ApiSession and surfaced by live pages.
      }
    }
    if (mounted && resources.isNotEmpty) {
      syncProductStoreFromApi(session!, AppScope.of(context));
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
    switch (_route) {
      case 'dash':
        return widget.cfg.role == SfRole.student
            ? StudentSelfServiceScreen(colors: colors)
            : DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'student_report':
        return StudentSelfServiceScreen(colors: colors, reportOnly: true);
      case 'tools':
        // This route is the user's role-safe navigation/action hub in both
        // preview and authenticated modes. The technical OpenAPI explorer is
        // diagnostics, not role or permission management.
        return ProductivityHub(role: widget.cfg.role, onNavigate: _navigate);
      case 'branches':
        return const BranchesScreen();
      case 'students':
        return const StudentsScreen();
      case 'teachers':
        return TeachersWorkspaceScreen(colors: colors);
      case 'employees':
        return HrWorkspaceScreen(colors: colors);
      case 'attendance':
        return AttendanceScreen(colors: colors);
      case 'finance':
      case 'report':
        return ReportScreen(colors: colors, role: widget.cfg.role);
      case 'groups':
        return const WebGroupsPage();
      case 'messages':
        // Audit can inspect transcripts but the backend explicitly rejects
        // message creation (403). Keep its primary Messages tab on the same
        // read-only oversight page as the audit navigation destination.
        return widget.cfg.role == SfRole.audit
            ? (buildAdminPage('messages', colors, widget.cfg.role) ??
                  DashboardScreen(cfg: widget.cfg, go: _navigate))
            : const WebMessagesPage();
      case 'chats':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'approvals':
        return const WebApprovalsPage();
      case 'payments':
        return const WebPaymentsPage();
      case 'hr':
        return const WebHrPage();
      case 'parents':
        return ParentsWorkspaceScreen(colors: colors);
      case 'departments':
        return DepartmentsWorkspaceScreen(colors: colors);
      case 'meetings':
        return MeetingsWorkspaceScreen(colors: colors);
      case 'schedule':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'payroll':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'leads':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'enroll':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'anomalies':
        return const AnomaliesScreen();
      case 'fairness':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'surveys':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'cases':
        return const CasesScreen();
      case 'logs':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'history':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'comparison':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'aiusage':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'permissions':
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
      case 'ai':
        // The same assistant surface handles both modes: with a session it
        // calls the published AI endpoint, without one it shows the honest
        // "AI is not connected" state. A read-only request collection would
        // make the connected assistant impossible to use.
        return AiScreen(cfg: widget.cfg);
      case 'notifications':
        final api = ApiScope.maybeOf(context)?.notifier;
        return api?.authenticated == true
            ? LiveNotificationsPage(onNavigate: _navigate)
            : NotificationsScreen(colors: colors, onNavigate: _navigate);
      case 'me':
        return ProfileScreen(
          cfg: widget.cfg,
          onSwitchRole: widget.onSwitchRole,
          onNavigate: _navigate,
        );
      case 'account_preferences':
        return AccountPreferencesScreen(cfg: widget.cfg, colors: colors);
      case 'account_activity':
        return AccountActivityScreen(colors: colors);
      case 'privacy':
        return PrivacyPolicyScreen(colors: colors);
      case 'security':
        return AccountSecurityScreen(colors: colors);
      case 'settings':
        return const ApiConnectionScreen();
      default:
        return buildAdminPage(_route, colors, widget.cfg.role) ??
            DashboardScreen(cfg: widget.cfg, go: _navigate);
    }
  }

  List<TabSpec> get _bottomTabs {
    final api = ApiScope.maybeOf(context)?.notifier;
    return widget.cfg.tabs
        .where((tab) => _backendAllowsRoute(api, widget.cfg.role, tab.id))
        .toList(growable: false);
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
            Positioned(
              left: 0,
              // AI already has a chat-history button in its first header row.
              // Keep the section drawer on the left but below that control so
              // both remain visible and independently tappable.
              top: _route == 'ai' ? 58 : 12,
              child: _MobileNavigationOpener(
                onPressed: () => setState(() => _drawerOpen = true),
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
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: Color.alphaBlend(
              c.primary.withValues(alpha: .06),
              c.surface,
            ),
            elevation: 2,
            shadowColor: c.ink.withValues(alpha: .12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('console-open-navigation'),
              onTap: onPressed,
              child: SizedBox(
                width: 32,
                height: 34,
                child: Icon(Icons.menu_rounded, size: 18, color: c.primary),
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
    final label = tabLabel(context, tab.id, tab.label);
    return Semantics(
      button: true,
      selected: active,
      label: label,
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
                    label,
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
                    final label = tabLabel(context, tab.id, tab.label);
                    return Tooltip(
                      message: label,
                      child: Semantics(
                        button: true,
                        selected: active,
                        label: label,
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
    final groups = [
      for (final group in menuFor(cfg.role))
        MenuGroup(
          group.title,
          group.items
              .where((item) => _backendAllowsRoute(api, cfg.role, item.id))
              .toList(growable: false),
        ),
    ].where((group) => group.items.isNotEmpty).toList(growable: false);
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
    final profile = api?.me ?? const <String, dynamic>{};
    final liveName = apiText(
      apiValue(profile, const ['full_name', 'display_name', 'name']),
    );
    final composedName = [
      apiText(profile['first_name']),
      apiText(profile['middle_name']),
      apiText(profile['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    final displayName = live
        ? (liveName.isNotEmpty
              ? liveName
              : composedName.isNotEmpty
              ? composedName
              : apiText(profile['username'], fallback: cfg.who))
        : cfg.who;
    final memberships = apiValue(profile, const ['role_memberships']);
    final firstMembership = memberships is Iterable
        ? memberships.whereType<Map>().firstOrNull
        : null;
    final displayRole = live
        ? apiText(
            firstMembership == null
                ? apiValue(profile, const ['role', 'principal_kind'])
                : apiValue(Map<String, dynamic>.from(firstMembership), const [
                    'account_type_name',
                    'role_name',
                    'account_kind',
                  ]),
            fallback: configLabel(context, cfg.roleTitle),
          )
        : configLabel(context, cfg.roleTitle);
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RefType.ui(
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                Text(
                                  displayRole,
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
