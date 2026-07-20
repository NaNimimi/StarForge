import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'data.dart';
import 'settings.dart';
import 'i18n.dart';
import 'reference_ui.dart';
import 'screens.dart';

/// The role console: a bottom-tab shell that swaps the active screen.
class Console extends StatefulWidget {
  final RoleConfig cfg;
  final VoidCallback onSwitchRole;
  const Console({super.key, required this.cfg, required this.onSwitchRole});

  @override
  State<Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<Console> {
  String tab = 'dash';
  // Android back / left-edge swipe: first press from a non-dash tab returns to
  // the dashboard; from the dashboard a second press within 2s exits the app.
  DateTime? _lastBack;

  @override
  void didUpdateWidget(Console old) {
    super.didUpdateWidget(old);
    if (old.cfg.role != widget.cfg.role) tab = 'dash';
  }

  void _handleBack() {
    if (tab != 'dash') {
      setState(() => tab = 'dash');
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(tr(context, 'exit_confirm'),
            style: TextStyle(fontFamily: SfType.ui, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Widget _screen() {
    switch (tab) {
      case 'groups':
        return const GroupsScreen();
      case 'students':
        return const StudentsScreen();
      case 'anomalies':
        return const AnomaliesScreen();
      case 'approvals':
        return const ApprovalsScreen();
      case 'branches':
        return const BranchesScreen();
      case 'cases':
        return const CasesScreen();
      case 'ai':
        return AiScreen(cfg: widget.cfg);
      case 'messages':
        return const MessagesScreen();
      case 'me':
        return ProfileScreen(cfg: widget.cfg, onSwitchRole: widget.onSwitchRole);
      default:
        return DashboardScreen(cfg: widget.cfg, go: (t) => setState(() => tab = t));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colours follow the global theme toggle, not the role default, so a user
    // can run any console in light or dark mode.
    final settings = SettingsScope.of(context);
    final c = settings.colors;
    // The selected Layout reshapes the nav chrome (web's "Layout · 5").
    final layoutId = kLayouts[settings.layout].id;
    final atTop = layoutId == 'topbar' || layoutId == 'zen';
    final content = Expanded(
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(tab), child: _screen()),
        ),
      ),
    );
    final tabBar = _TabBar(
      cfg: widget.cfg,
      colors: c,
      current: tab,
      layout: layoutId,
      onTap: (t) => setState(() => tab = t),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          // The design panel lives in Profile (the "Dizayn" card), so there's
          // no floating ✦ overlay cluttering every screen.
          child: Column(
            children: atTop ? [tabBar, content] : [content, tabBar],
          ),
        ),
      ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final RoleConfig cfg;
  final SfColors colors;
  final String current;
  final String layout;
  final ValueChanged<String> onTap;
  const _TabBar({required this.cfg, required this.colors, required this.current, required this.layout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final atTop = layout == 'topbar' || layout == 'zen';
    final iconsOnly = layout == 'rail' || layout == 'zen';
    final floating = layout == 'dock';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget tab(TabSpec t) {
      final on = current == t.id;
      return Expanded(
        child: RefPressable(
          onPressed: () => onTap(t.id),
          selected: on,
          borderRadius: RefRadius.md,
          semanticLabel: tabLabel(context, t.id, t.label),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: iconsOnly ? 7 : 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: RefMotion.resolve(context, RefMotion.standard),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 9 : 11, vertical: iconsOnly ? 8 : 6),
                  decoration: BoxDecoration(
                    color: on ? colors.ink : Colors.transparent,
                    borderRadius: RefRadius.md,
                    boxShadow: on ? RefShadows.soft : null,
                  ),
                  child: AnimatedScale(
                    duration: RefMotion.resolve(context, RefMotion.standard),
                    curve: Curves.easeOutBack,
                    scale: on ? 1 : .92,
                    child: Icon(t.icon, size: iconsOnly ? 21 : 20, color: on ? colors.bg : colors.muted),
                  ),
                ),
                if (!iconsOnly) ...[
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: RefMotion.resolve(context, RefMotion.standard),
                    style: RefType.ui(size: 9.5, weight: on ? FontWeight.w700 : FontWeight.w600, color: on ? colors.ink : colors.muted),
                    child: Text(tabLabel(context, t.id, t.label)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final row = Row(children: [for (final t in cfg.tabs) tab(t)]);

    if (floating) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 10 + bottomInset * 0.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: RefRadius.lg,
            border: Border.all(color: colors.border),
            boxShadow: RefShadows.card,
          ),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: row),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: atTop ? BorderSide.none : BorderSide(color: colors.border),
          bottom: atTop ? BorderSide(color: colors.border) : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, atTop ? 4 : 8, 4, atTop ? 4 : 8 + bottomInset * 0.4),
        child: row,
      ),
    );
  }
}
