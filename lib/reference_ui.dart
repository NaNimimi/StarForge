import 'package:flutter/material.dart';

import 'theme.dart';

/// UI primitives adapted directly from the reference project's
/// `lib/theme` and `lib/widgets` layers.  Feature screens pass their existing
/// data and callbacks into these widgets; no state, routes or domain models
/// are owned here.

abstract final class RefMotion {
  static const press = Duration(milliseconds: 110);
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 360);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

abstract final class RefRadius {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(14));
  static const lg = BorderRadius.all(Radius.circular(22));
  static const xl = BorderRadius.all(Radius.circular(28));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class RefShadows {
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x0F361E0E), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x14361E0E), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A361E0E), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x1F361E0E), blurRadius: 40, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x0F361E0E), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

class RefType {
  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = -0.07,
    double? height,
  }) => TextStyle(
    fontFamily: SfType.ui,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle display({
    double size = 22,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: SfType.display,
    fontSize: size,
    fontWeight: weight,
    fontStyle: FontStyle.italic,
    color: color,
    height: height,
  );

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: SfType.mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle eyebrow({Color? color, double size = 11}) => ui(
    size: size,
    weight: FontWeight.w600,
    color: color,
    letterSpacing: size * .06,
  );
}

/// Direct adaptation of the reference `SfPressable`: uniform scale, hover and
/// focus behaviour for every interactive surface.
class RefPressable extends StatefulWidget {
  const RefPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = RefRadius.md,
    this.pressedScale = .985,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final double pressedScale;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<RefPressable> createState() => _RefPressableState();
}

class _RefPressableState extends State<RefPressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final duration = RefMotion.resolve(context, RefMotion.press);
    final c = SfTheme.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: _pressed && enabled ? widget.pressedScale : 1,
              child: AnimatedContainer(
                duration: duration,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: _focused
                      ? Border.all(color: c.primary, width: 2)
                      : null,
                ),
                foregroundDecoration: _hovered && enabled
                    ? BoxDecoration(
                        borderRadius: widget.borderRadius,
                        color: c.primary.withValues(alpha: .025),
                      )
                    : null,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Direct adaptation of reference `SfSurfaceCard`; all new surfaces use this
/// instead of the application's older Card / Container compositions.
class RefSurfaceCard extends StatelessWidget {
  const RefSurfaceCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = RefRadius.lg,
    this.color,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color? color;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: elevated ? RefShadows.card : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum RefButtonKind { primary, ghost, soft, ink, danger }

/// Reference `SfButton` with the original 44px touch target and pill shell.
class RefButton extends StatelessWidget {
  const RefButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = RefButtonKind.primary,
    this.leading,
    this.trailing,
    this.block = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RefButtonKind kind;
  final IconData? leading;
  final IconData? trailing;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final (background, foreground, border) = switch (kind) {
      RefButtonKind.primary => (c.primary, c.surface, null),
      RefButtonKind.ghost => (Colors.transparent, c.ink, c.borderStrong),
      RefButtonKind.soft => (c.surface2, c.ink, null),
      RefButtonKind.ink => (c.ink, c.bg, null),
      RefButtonKind.danger => (c.danger, c.surface, null),
    };
    final child = AnimatedOpacity(
      opacity: onPressed == null ? .46 : 1,
      duration: RefMotion.resolve(context, RefMotion.quick),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: RefRadius.pill,
          border: border == null ? null : Border.all(color: border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 18, color: foreground),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailing, size: 18, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final pressable = RefPressable(
      onPressed: onPressed,
      borderRadius: RefRadius.pill,
      semanticLabel: label,
      child: child,
    );
    return block ? SizedBox(width: double.infinity, child: pressable) : pressable;
  }
}

/// Adapted from `SfLargeAppBar`: wide, editorial top-level page hierarchy.
class RefLargeHeader extends StatelessWidget {
  const RefLargeHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  ?leading,
                  const Spacer(),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: action,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (eyebrow != null) ...[
              Text(eyebrow!.toUpperCase(), style: RefType.eyebrow(color: c.primary, size: 10.5)),
              const SizedBox(height: 4),
            ],
            Text(
              title,
              style: RefType.ui(
                size: 28,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -.84,
                height: 1.05,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle!,
                  style: RefType.ui(size: 13, color: c.muted, height: 1.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Adapted from `SfNavBar`, used by profile and chat details.
class RefNavHeader extends StatelessWidget {
  const RefNavHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: subtitle == null ? 56 : 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: actions.isEmpty ? 52 : 96),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: RefType.ui(size: 17, weight: FontWeight.w700, color: c.ink),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: RefType.ui(size: 11, color: c.muted),
                      ),
                  ],
                ),
              ),
              if (onBack != null)
                Positioned(
                  left: 10,
                  child: IconButton(
                    tooltip: 'Orqaga',
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back_rounded, color: c.primary),
                  ),
                ),
              if (actions.isNotEmpty)
                Positioned(
                  right: 8,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RefIconAction extends StatelessWidget {
  const RefIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RefPressable(
            onPressed: onPressed,
            borderRadius: RefRadius.md,
            semanticLabel: tooltip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: RefRadius.md,
                border: Border.all(color: c.border),
              ),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(child: Icon(icon, size: 20, color: c.ink2)),
            ),
          ),
          if ((badge ?? 0) > 0)
            Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.danger,
                  borderRadius: RefRadius.pill,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  child: Center(
                    child: Text(
                      badge! > 9 ? '9+' : '$badge',
                      style: RefType.mono(size: 8.5, weight: FontWeight.w700, color: c.surface),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Adapted from `SfTextField`; no controller state is held by the component.
class RefSearchField extends StatelessWidget {
  const RefSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Qidirish',
    this.focusNode,
    this.suffix,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final FocusNode? focusNode;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      cursorColor: c.primary,
      style: RefType.ui(size: 14, weight: FontWeight.w600, color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: RefType.ui(size: 14, color: c.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: RefRadius.md,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RefRadius.md,
          borderSide: BorderSide(color: c.primary, width: 1.7),
        ),
      ),
    );
  }
}

/// Direct adaptation of the reference segmented filter rail.
class RefSegmentedControl<T> extends StatelessWidget {
  const RefSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: RefRadius.md,
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (final value in values)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: RefPressable(
                    onPressed: () => onChanged(value),
                    selected: value == selected,
                    borderRadius: RefRadius.sm,
                    semanticLabel: labelOf(value),
                    child: AnimatedContainer(
                      duration: RefMotion.resolve(context, const Duration(milliseconds: 180)),
                      constraints: const BoxConstraints(minHeight: 42),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: value == selected ? c.surface : Colors.transparent,
                        borderRadius: RefRadius.sm,
                        boxShadow: value == selected ? RefShadows.soft : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labelOf(value),
                        style: RefType.ui(
                          size: 11.5,
                          weight: value == selected ? FontWeight.w700 : FontWeight.w500,
                          color: value == selected ? c.ink : c.muted,
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

enum RefPillTone { neutral, primary, accent, success, warning, danger }

class RefPill extends StatelessWidget {
  const RefPill({super.key, required this.label, this.tone = RefPillTone.neutral});

  final String label;
  final RefPillTone tone;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final (background, foreground, border) = switch (tone) {
      RefPillTone.primary => (c.primarySoft, c.primaryInk, null),
      RefPillTone.accent => (c.accentSoft, c.accentInk, null),
      RefPillTone.success => (c.successSoft, c.success, null),
      RefPillTone.warning => (c.warnSoft, c.warn, null),
      RefPillTone.danger => (c.dangerSoft, c.danger, null),
      RefPillTone.neutral => (c.surface2, c.ink2, c.border),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: RefRadius.pill,
        border: border == null ? null : Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label.toUpperCase(), style: RefType.eyebrow(color: foreground, size: 10)),
      ),
    );
  }
}

enum RefMetricTone { neutral, primary, accent, success, warning, danger }

/// Direct adaptation of `StaffMetricCard`, including its equal-card grid rhythm.
class RefMetricCard extends StatelessWidget {
  const RefMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.tone = RefMetricTone.neutral,
    this.onTap,
    this.uppercaseLabel = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final RefMetricTone tone;
  final VoidCallback? onTap;
  final bool uppercaseLabel;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final (accent, soft) = switch (tone) {
      RefMetricTone.primary => (c.primary, c.primarySoft),
      RefMetricTone.accent => (c.accentInk, c.accentSoft),
      RefMetricTone.success => (c.success, c.successSoft),
      RefMetricTone.warning => (c.warn, c.warnSoft),
      RefMetricTone.danger => (c.danger, c.dangerSoft),
      RefMetricTone.neutral => (c.ink2, c.surface2),
    };
    final content = RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: soft, borderRadius: RefRadius.sm),
                child: SizedBox(width: 30, height: 30, child: Icon(icon, size: 17, color: accent)),
              ),
              const Spacer(),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: RefType.mono(size: 22, weight: FontWeight.w700, color: accent, height: 1)),
          const SizedBox(height: 6),
          Text(uppercaseLabel ? label.toUpperCase() : label, style: RefType.eyebrow(color: c.muted, size: 10)),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, maxLines: 2, overflow: TextOverflow.ellipsis, style: RefType.ui(size: 10.5, color: c.muted, height: 1.25)),
          ],
        ],
      ),
    );
    return onTap == null
        ? content
        : RefPressable(onPressed: onTap, borderRadius: RefRadius.lg, semanticLabel: '$label: $value', child: content);
  }
}

class RefAdaptiveGrid extends StatelessWidget {
  const RefAdaptiveGrid({super.key, required this.children, this.minCellWidth = 152, this.spacing = 10});

  final List<Widget> children;
  final double minCellWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = ((constraints.maxWidth + spacing) / (minCellWidth + spacing))
          .floor()
          .clamp(1, 4)
          .toInt();
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

class RefSectionHeader extends StatelessWidget {
  const RefSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RefType.ui(size: 17, weight: FontWeight.w800, color: c.ink)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: RefType.ui(size: 11.5, color: c.muted)),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class RefStatusTile extends StatelessWidget {
  const RefStatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone = RefMetricTone.neutral,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RefMetricTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final color = switch (tone) {
      RefMetricTone.primary => c.primary,
      RefMetricTone.accent => c.accentInk,
      RefMetricTone.success => c.success,
      RefMetricTone.warning => c.warn,
      RefMetricTone.danger => c.danger,
      RefMetricTone.neutral => c.ink2,
    };
    final tile = RefSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: RefRadius.md),
            child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 19, color: color)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: RefType.ui(size: 13.5, weight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: RefType.ui(size: 11.5, color: c.muted, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? (onTap == null ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, size: 18, color: c.muted)),
        ],
      ),
    );
    return onTap == null ? tile : RefPressable(onPressed: onTap, borderRadius: RefRadius.lg, child: tile);
  }
}

class RefStaggeredReveal extends StatelessWidget {
  const RefStaggeredReveal({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: RefMotion.resolve(context, Duration(milliseconds: 230 + order * 45)),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
    ),
  );
}

class RefChatBubble extends StatelessWidget {
  const RefChatBubble({super.key, required this.text, required this.mine, this.time});

  final String text;
  final bool mine;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface,
          border: mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mine ? 15 : 4),
            bottomRight: Radius.circular(mine ? 4 : 15),
          ),
          boxShadow: mine ? RefShadows.soft : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(text, style: RefType.ui(size: 13, color: mine ? c.surface : c.ink, height: 1.35)),
              if (time != null) ...[
                const SizedBox(height: 3),
                Text(time!, style: RefType.mono(size: 8.5, color: mine ? c.surface.withValues(alpha: .72) : c.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RefComposer extends StatelessWidget {
  const RefComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.onAttach,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
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
              IconButton(onPressed: onAttach, icon: Icon(Icons.add_circle_outline_rounded, color: c.muted)),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: RefType.ui(size: 13, color: c.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      hintText: hint,
                      hintStyle: RefType.ui(size: 13, color: c.muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              RefPressable(
                onPressed: onSend,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.primary, borderRadius: const BorderRadius.all(Radius.circular(12))),
                  child: const SizedBox(width: 40, height: 40, child: Icon(Icons.send_rounded, size: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
