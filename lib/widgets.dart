import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Press-to-shrink feedback wrapper. Uses a [Listener] (not GestureDetector) so
/// it never steals taps from an inner InkWell/onTap — purely a visual accent.
class SfTap extends StatefulWidget {
  final Widget child;
  final double scale;
  const SfTap({super.key, required this.child, this.scale = 0.96});
  @override
  State<SfTap> createState() => _SfTapState();
}

class _SfTapState extends State<SfTap> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Smooth fade + lift page transition for pushed routes.
Route<T> sfPageRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

/// Each of the three console users gets a unique branded avatar (gradient +
/// white initials) so they're recognisable at a glance everywhere they appear.
const Map<String, List<Color>> kUserAvatars = {
  'Sardor Rashidov': [Color(0xFFB85535), Color(0xFFD89A2E)],
  "Dilnoza Yo'ldosheva": [Color(0xFF2E9B8F), Color(0xFF4F7B3B)],
  'Jamshid Qodirov': [Color(0xFF7A4A82), Color(0xFF2A3D8F)],
};

/// Real portrait photos (bundled assets) for the three console users.
const Map<String, String> kUserPhotos = {
  'Sardor Rashidov': 'assets/avatars/sardor.jpg',
  "Dilnoza Yo'ldosheva": 'assets/avatars/dilnoza.jpg',
  'Jamshid Qodirov': 'assets/avatars/jamshid.jpg',
};

/// A user-selectable avatar: either a bundled [photo] or a [gradient] badge with
/// an [emoji]. Stored on the [AppStore] so the choice shows everywhere at once.
class AvatarChoice {
  final String? photo;
  final List<Color>? gradient;
  final String? emoji;
  const AvatarChoice({this.photo, this.gradient, this.emoji});
}

/// Real-photo avatar options offered in the picker.
const List<AvatarChoice> kAvatarPhotos = [
  AvatarChoice(photo: 'assets/avatars/sardor.jpg'),
  AvatarChoice(photo: 'assets/avatars/dilnoza.jpg'),
  AvatarChoice(photo: 'assets/avatars/jamshid.jpg'),
];

/// Colourful emoji badge options offered in the picker.
const List<AvatarChoice> kAvatarBadges = [
  AvatarChoice(gradient: [Color(0xFFB85535), Color(0xFFD89A2E)], emoji: '🦁'),
  AvatarChoice(gradient: [Color(0xFF2E9B8F), Color(0xFF4F7B3B)], emoji: '🌿'),
  AvatarChoice(gradient: [Color(0xFF7A4A82), Color(0xFF2A3D8F)], emoji: '🔮'),
  AvatarChoice(gradient: [Color(0xFF2A3D8F), Color(0xFF2E9B8F)], emoji: '🌊'),
  AvatarChoice(gradient: [Color(0xFFB33A2A), Color(0xFFD89A2E)], emoji: '🔥'),
  AvatarChoice(gradient: [Color(0xFF4F7B3B), Color(0xFFC68423)], emoji: '⭐'),
];

/// Deterministic warm avatar from initials; branded users get a real photo
/// (with their gradient as the loading/fallback backdrop).
class SfAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  /// When set, overrides the name-derived avatar — used for the logged-in user
  /// after they pick a custom photo or badge in the avatar picker.
  final AvatarChoice? choice;
  const SfAvatar({
    super.key,
    required this.name,
    this.size = 34,
    this.color,
    this.choice,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  /// Render a [photo] / gradient+emoji avatar at [size].
  Widget _choice(AvatarChoice ch) {
    final grad = ch.gradient ?? const [Color(0xFFB85535), Color(0xFFD89A2E)];
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: grad.last.withValues(alpha: 0.32),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
      child: ch.photo != null
          ? Image.asset(
              ch.photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                _initials,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
          : Text(ch.emoji ?? _initials, style: TextStyle(fontSize: size * 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    if (choice != null) return _choice(choice!);
    // Branded users: a vivid gradient backdrop with their real photo on top.
    final grad = kUserAvatars[name];
    if (grad != null) {
      final photo = kUserPhotos[name];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: grad.last.withValues(alpha: 0.32),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.07),
            ),
          ],
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Text(
                _initials,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              )
            : Image.asset(
                photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Soft fade-in once the photo decodes.
                frameBuilder: (context, child, frame, wasSync) {
                  if (wasSync) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                // If the asset is missing, fall back to white initials.
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
      );
    }
    // Everyone else: soft tinted initials, colour derived from the name.
    final palette = [
      c.primary,
      c.accent,
      c.success,
      const Color(0xFF7A4A82),
      const Color(0xFF2A3D8F),
    ];
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

/// Public KPI tile (icon + value + trend + sub or sparkline) — used by the
/// ported web pages. Mirrors the dashboard's private `_Kpi`.
class SfKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final ({bool up, String v})? trend;
  final List<double>? spark;
  final String? sub;
  final IconData? icon;
  const SfKpi({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.trend,
    this.spark,
    this.sub,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
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
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: color ?? c.ink,
                    ),
                  ),
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
    );
  }
}

/// 2-column KPI grid for the ported pages.
Widget sfKpiGrid(List<Widget> tiles, {double ratio = 1.6}) => GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: 9,
  crossAxisSpacing: 9,
  childAspectRatio: ratio,
  children: tiles,
);

enum PillTone { success, danger, warn, primary, accent, neutral }

class Pill extends StatelessWidget {
  final String text;
  final PillTone tone;
  final bool dot;
  const Pill(
    this.text, {
    super.key,
    this.tone = PillTone.neutral,
    this.dot = false,
  });

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
    // Statuses are localised and can be much longer than their Uzbek source.
    // Keep a pill compact on a phone rather than letting it squeeze a sibling
    // label into a vertical word or trigger a RenderFlex overflow.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
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
          Text(
            text,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
              color: c.ai,
            ),
          ),
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
      [50, 0],
      [61, 35],
      [98, 35],
      [68, 57],
      [79, 91],
      [50, 70],
      [21, 91],
      [32, 57],
      [2, 35],
      [39, 35],
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
  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 24,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, height),
    painter: _SparkPainter(data, color),
  );
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
  bool shouldRepaint(_SparkPainter old) =>
      old.data != data || old.color != color;
}

class AreaChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;

  /// Optional x-axis labels (e.g. months); when set, a dot is drawn at every
  /// point and the labels are rendered along the bottom (web "Daromad" chart).
  final List<String>? labels;
  const AreaChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 130,
    this.labels,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _AreaPainter(data, color, c.border, labels, c.muted, c.surface),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color grid;
  final List<String>? labels;
  final Color labelColor;
  final Color dotFill;
  _AreaPainter(
    this.data,
    this.color,
    this.grid,
    this.labels,
    this.labelColor,
    this.dotFill,
  );
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final labelH = labels != null ? 16.0 : 0.0;
    final chartH = size.height - labelH;
    final padX = labels != null ? 6.0 : 0.0;
    final lo = data.reduce(math.min) * 0.96, hi = data.reduce(math.max);
    final range = (hi - lo) == 0 ? 1 : (hi - lo);
    Offset pt(int i) => Offset(
      padX + i / (data.length - 1) * (size.width - padX * 2),
      chartH - (data[i] - lo) / range * (chartH - 6) - 3,
    );

    // baseline grid
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (int g = 1; g <= 3; g++) {
      final y = chartH / 4 * g;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < data.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(pt(data.length - 1).dx, chartH)
      ..lineTo(pt(0).dx, chartH)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
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
    if (labels != null) {
      // dot at every point
      final dotStroke = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final dotCore = Paint()..color = dotFill;
      for (int i = 0; i < data.length; i++) {
        canvas.drawCircle(pt(i), 3, dotCore);
        canvas.drawCircle(pt(i), 3, dotStroke);
      }
      // month labels
      for (int i = 0; i < labels!.length && i < data.length; i++) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels![i],
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 9,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(pt(i).dx - tp.width / 2, size.height - tp.height),
        );
      }
    } else {
      // end dot only
      canvas.drawCircle(pt(data.length - 1), 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.data != data || old.color != color || old.labels != labels;
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
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke,
    );
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

  /// Show a coloured star badge before the label (branch ranking style).
  final bool mark;

  /// When set, the row becomes tappable (shows a chevron) — used to drill into
  /// a branch's detail from a ranking/compliance chart.
  final VoidCallback? onTap;
  const HBarRow(
    this.label,
    this.value,
    this.display,
    this.color, {
    this.mark = false,
    this.onTap,
  });
}

class HBars extends StatelessWidget {
  final List<HBarRow> rows;

  /// Prefix each row with its 1-based rank number (web "Filiallar reytingi").
  final bool ranked;
  const HBars({super.key, required this.rows, this.ranked = false});
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final max = rows.map((r) => r.value).reduce(math.max);
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: rows[i].onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  if (ranked) ...[
                    SizedBox(
                      width: 14,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: SfType.mono,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.muted2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (rows[i].mark) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: rows[i].color,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Center(
                        child: SfStar(size: 11, color: Color(0xFFFFFCF5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: ranked ? 70 : 64,
                    child: Text(
                      rows[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        fontWeight: ranked ? FontWeight.w600 : FontWeight.w400,
                        color: ranked ? c.ink : c.ink2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: rows[i].value / max,
                        minHeight: 8,
                        backgroundColor: c.surface2,
                        valueColor: AlwaysStoppedAnimation(rows[i].color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 62,
                    child: Text(
                      rows[i].display,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: SfType.mono,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                  if (rows[i].onTap != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: c.muted2,
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
          Text(
            title,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          if (link != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                link!,
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
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
  const SfHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.sub,
  });
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 3),
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
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12,
                color: c.muted,
              ),
            ),
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
  final ValueChanged<int>? onChanged;
  const SfChips(this.chips, {super.key, this.aiStyle = false, this.onChanged});
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
            onTap: () {
              setState(() => sel = i);
              widget.onChanged?.call(i);
            },
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
                      : c.border,
                ),
              ),
              child: Text(
                widget.chips[i],
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ai
                      ? c.ai
                      : on
                      ? c.bg
                      : c.muted,
                ),
              ),
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
  const SfAiCard({
    super.key,
    required this.badge,
    required this.quote,
    this.trailing,
    this.onTap,
  });
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
            Text(
              '“$quote”',
              style: TextStyle(
                fontFamily: SfType.display,
                fontStyle: FontStyle.italic,
                fontSize: 15,
                height: 1.35,
                color: c.ink,
              ),
            ),
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
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 11.5,
                color: c.ink2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
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
          title: Text(
            title,
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
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

/// Single-select chip row (dark "ink" pill = active).
class SfSelectChips extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const SfSelectChips({
    super.key,
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

/// Primary/secondary pill button used in module action bars.
class SfButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const SfButton({
    super.key,
    this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          // mainAxisSize.max + center keeps the button full-width and its label
          // centred WITHOUT making the box greedily expand to fill all available
          // height — an aligned Container in a Scaffold.bottomNavigationBar slot
          // (loose, full-screen height) would balloon and collapse the body.
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: primary ? Colors.white : c.ink2),
                const SizedBox(width: 7),
              ],
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
    );
  }
}

/// Floating snackbar that does not pop the current route.
void sfSnack(BuildContext context, String msg, {Color? bg}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        // Notifications are intentionally shown at the top of the mobile view,
        // where they do not hide the composer or bottom navigation.
        margin: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          MediaQuery.of(context).size.height - 92,
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
