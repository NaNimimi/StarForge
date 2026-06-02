import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Deterministic warm avatar from initials (mirrors SfAvatar).
class SfAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const SfAvatar({super.key, required this.name, this.size = 34, this.color});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final palette = [c.primary, c.accent, c.success, const Color(0xFF7A4A82), const Color(0xFF2A3D8F)];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final bg = color ?? palette[hash % palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: SfType.ui,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: bg,
        ),
      ),
    );
  }
}

enum PillTone { success, danger, warn, primary, accent, neutral }

class Pill extends StatelessWidget {
  final String text;
  final PillTone tone;
  final bool dot;
  const Pill(this.text, {super.key, this.tone = PillTone.neutral, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    late Color fg, bg;
    switch (tone) {
      case PillTone.success:
        fg = c.success;
        bg = c.successSoft;
        break;
      case PillTone.danger:
        fg = c.danger;
        bg = c.dangerSoft;
        break;
      case PillTone.warn:
        fg = c.warn;
        bg = c.warnSoft;
        break;
      case PillTone.primary:
        fg = c.primaryInk;
        bg = c.primarySoft;
        break;
      case PillTone.accent:
        fg = c.accentInk;
        bg = c.accentSoft;
        break;
      case PillTone.neutral:
        fg = c.ink2;
        bg = c.surface2;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Saffron "AI" badge with star glyph.
class SfAiBadge extends StatelessWidget {
  final String text;
  const SfAiBadge(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.aiBg.first,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.aiBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SfStar(size: 11, color: c.ai),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.04,
                  color: c.ai)),
        ],
      ),
    );
  }
}

/// The StarForge 8-point star mark.
class SfStar extends StatelessWidget {
  final double size;
  final Color color;
  const SfStar({super.key, this.size = 16, required this.color});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _StarPainter(color));
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const pts = [
      [50, 0], [61, 35], [98, 35], [68, 57], [79, 91],
      [50, 70], [21, 91], [32, 57], [2, 35], [39, 35],
    ];
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = pts[i][0] / 100 * w, y = pts[i][1] / 100 * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

// ── Charts ─────────────────────────────────────────────────────────────

class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  const Sparkline({super.key, required this.data, required this.color, this.height = 24});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(double.infinity, height), painter: _SparkPainter(data, color));
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final lo = data.reduce(math.min), hi = data.reduce(math.max);
    final range = (hi - lo) == 0 ? 1 : (hi - lo);
    Offset pt(int i) => Offset(
          i / (data.length - 1) * size.width,
          size.height - (data[i] - lo) / range * size.height,
        );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < data.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data || old.color != color;
}

class AreaChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  const AreaChart({super.key, required this.data, required this.color, this.height = 130});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _AreaPainter(data, color, c.border),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color grid;
  _AreaPainter(this.data, this.color, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final lo = data.reduce(math.min) * 0.96, hi = data.reduce(math.max);
    final range = (hi - lo) == 0 ? 1 : (hi - lo);
    Offset pt(int i) => Offset(
          i / (data.length - 1) * size.width,
          size.height - (data[i] - lo) / range * (size.height - 6) - 3,
        );

    // baseline grid
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (int g = 1; g <= 3; g++) {
      final y = size.height / 4 * g;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < data.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // end dot
    final end = pt(data.length - 1);
    canvas.drawCircle(end, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AreaPainter old) => old.data != data || old.color != color;
}

class DonutSegment {
  final double value;
  final Color color;
  const DonutSegment(this.value, this.color);
}

class Donut extends StatelessWidget {
  final double size;
  final double thickness;
  final List<DonutSegment> segments;
  final Widget center;
  const Donut({
    super.key,
    required this.size,
    required this.thickness,
    required this.segments,
    required this.center,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(segments, thickness, c.surface2),
          ),
          center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double thickness;
  final Color track;
  _DonutPainter(this.segments, this.thickness, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    final rect = Rect.fromLTWH(thickness / 2, thickness / 2,
        size.width - thickness, size.height - thickness);
    canvas.drawArc(rect, 0, math.pi * 2,
        false, Paint()..color = track..strokeWidth = thickness..style = PaintingStyle.stroke);
    double start = -math.pi / 2;
    for (final s in segments) {
      final sweep = (s.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.04,
        false,
        Paint()
          ..color = s.color
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
}

class HBarRow {
  final String label;
  final double value;
  final String display;
  final Color color;
  const HBarRow(this.label, this.value, this.display, this.color);
}

class HBars extends StatelessWidget {
  final List<HBarRow> rows;
  const HBars({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final max = rows.map((r) => r.value).reduce(math.max);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(r.label,
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.ink2)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: r.value / max,
                      minHeight: 8,
                      backgroundColor: c.surface2,
                      valueColor: AlwaysStoppedAnimation(r.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(r.display,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontFamily: SfType.mono,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Layout helpers ─────────────────────────────────────────────────────

/// A surface card matching `.am-card`.
class SfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  const SfCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// Card header row with a title and optional trailing link (`.am-card-h`).
class SfCardHeader extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onTap;
  const SfCardHeader(this.title, {super.key, this.link, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
          if (link != null)
            GestureDetector(
              onTap: onTap,
              child: Text(link!,
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.primary)),
            ),
        ],
      ),
    );
  }
}

/// Big screen header (`.am-head`).
class SfHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? sub;
  const SfHead({super.key, required this.eyebrow, required this.title, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(),
              style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: c.muted)),
          const SizedBox(height: 3),
          Text(title,
              style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: c.ink)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

/// Horizontal scrolling filter chips (`.am-chips`).
class SfChips extends StatefulWidget {
  final List<String> chips;
  final bool aiStyle;
  const SfChips(this.chips, {super.key, this.aiStyle = false});
  @override
  State<SfChips> createState() => _SfChipsState();
}

class _SfChipsState extends State<SfChips> {
  int sel = 0;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final on = i == sel && !widget.aiStyle;
          final ai = widget.aiStyle;
          return GestureDetector(
            onTap: () => setState(() => sel = i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ai
                    ? c.aiBg.first
                    : on
                        ? c.ink
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: ai
                        ? c.aiBorder
                        : on
                            ? Colors.transparent
                            : c.border),
              ),
              child: Text(widget.chips[i],
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ai
                          ? c.ai
                          : on
                              ? c.bg
                              : c.muted)),
            ),
          );
        },
      ),
    );
  }
}

/// AI insight card (`.am-ai`).
class SfAiCard extends StatelessWidget {
  final String badge;
  final String quote;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SfAiCard({super.key, required this.badge, required this.quote, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.aiBg,
          ),
          border: Border.all(color: c.aiBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [SfAiBadge(badge), ?trailing],
            ),
            const SizedBox(height: 8),
            Text('“$quote”',
                style: TextStyle(
                    fontFamily: SfType.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    height: 1.35,
                    color: c.ink)),
          ],
        ),
      ),
    );
  }
}

/// A simple legend row for donut charts.
class LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const LegendRow(this.color, this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 7),
          Expanded(child: Text(label, style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.ink2))),
          Text(value,
              style: TextStyle(fontFamily: SfType.mono, fontSize: 11.5, fontWeight: FontWeight.w700, color: c.ink)),
        ],
      ),
    );
  }
}

/// Scaffold for pushed module routes — they have no [SfTheme] ancestor, so
/// [colors] is passed in and re-provided.
class SfScaffold extends StatelessWidget {
  final SfColors colors;
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? bottomBar;
  const SfScaffold({
    super.key,
    required this.colors,
    required this.title,
    required this.body,
    this.actions,
    this.bottomBar,
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
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: c.ink),
          shape: Border(bottom: BorderSide(color: c.border)),
          title: Text(title,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
          actions: actions,
        ),
        body: body,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// A small labelled stat block on a `surface2` background.
class SfStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const SfStatTile(this.label, this.value, this.color, {super.key});
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
              style: TextStyle(
                  fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.muted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontFamily: SfType.mono, fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Single-select chip row (dark "ink" pill = active).
class SfSelectChips extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const SfSelectChips({super.key, required this.items, required this.selected, required this.onSelect});
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
                      fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: on ? c.bg : c.muted)),
            ),
          );
        },
      ),
    );
  }
}

/// Primary/secondary pill button used in module action bars.
class SfButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const SfButton({super.key, this.icon, required this.label, required this.primary, required this.onTap});
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
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: primary ? Colors.white : c.ink2),
                const SizedBox(width: 7),
              ],
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
    );
  }
}

/// Floating snackbar that does not pop the current route.
void sfSnack(BuildContext context, String msg, {Color? bg}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg ?? const Color(0xFF3A332A),
      content: Text(msg, style: const TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ));
}

PillTone toneFromString(String s) {
  switch (s) {
    case 'success':
      return PillTone.success;
    case 'danger':
      return PillTone.danger;
    case 'warn':
      return PillTone.warn;
    case 'primary':
      return PillTone.primary;
    case 'accent':
      return PillTone.accent;
    default:
      return PillTone.neutral;
  }
}
