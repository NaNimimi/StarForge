import 'dart:math' as math;
import 'dart:typed_data';
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
  final Uint8List? memoryBytes;
  final List<Color>? gradient;
  final String? emoji;
  const AvatarChoice({this.photo, this.memoryBytes, this.gradient, this.emoji});
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
      child: ch.memoryBytes != null
          ? Image.memory(
              ch.memoryBytes!,
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
          : ch.photo != null
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
    late Color fg, bg, border;
    switch (tone) {
      case PillTone.success:
        fg = c.success;
        bg = c.successSoft;
        border = Colors.transparent;
        break;
      case PillTone.danger:
        fg = c.danger;
        bg = c.dangerSoft;
        border = Colors.transparent;
        break;
      case PillTone.warn:
        fg = c.warn;
        bg = c.warnSoft;
        border = Colors.transparent;
        break;
      case PillTone.primary:
        fg = c.primaryInk;
        bg = c.primarySoft;
        border = Colors.transparent;
        break;
      case PillTone.accent:
        fg = c.accentInk;
        bg = c.accentSoft;
        border = Colors.transparent;
        break;
      case PillTone.neutral:
        fg = c.ink2;
        bg = c.surface2;
        border = c.border;
        break;
    }
    // Statuses are localised and can be much longer than their Uzbek source.
    // Keep a pill compact on a phone rather than letting it squeeze a sibling
    // label into a vertical word or trigger a RenderFlex overflow.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
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
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.22,
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

/// Compact line chart with point selection for narrow detail pages.
///
/// A tap or horizontal drag selects the nearest sample and exposes its label
/// and formatted value above the drawing. The last sample is selected first so
/// the chart is understandable without requiring an initial gesture.
class InteractiveSparkline extends StatefulWidget {
  const InteractiveSparkline({
    super.key,
    required this.data,
    required this.color,
    required this.labels,
    required this.valueFormatter,
    this.height = 58,
    this.selectionLabelBuilder,
  }) : assert(data.length == labels.length);

  final List<double> data;
  final Color color;
  final List<String> labels;
  final String Function(double value) valueFormatter;
  final String Function(int index, String label, double value)?
  selectionLabelBuilder;
  final double height;

  @override
  State<InteractiveSparkline> createState() => _InteractiveSparklineState();
}

class _InteractiveSparklineState extends State<InteractiveSparkline> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = math.max(0, widget.data.length - 1);
  }

  @override
  void didUpdateWidget(InteractiveSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.length != oldWidget.data.length ||
        _selectedIndex >= widget.data.length) {
      _selectedIndex = math.max(0, widget.data.length - 1);
    }
  }

  void _select(double dx, double width) {
    if (widget.data.isEmpty || width <= 0) return;
    final index = widget.data.length == 1
        ? 0
        : (dx.clamp(0, width) / width * (widget.data.length - 1)).round().clamp(
            0,
            widget.data.length - 1,
          );
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();
    final c = SfTheme.of(context);
    final value = widget.data[_selectedIndex];
    final label = widget.labels[_selectedIndex];
    final summary =
        widget.selectionLabelBuilder?.call(_selectedIndex, label, value) ??
        '$label · ${widget.valueFormatter(value)}';
    return Semantics(
      label: summary,
      value: widget.valueFormatter(value),
      increasedValue: _selectedIndex < widget.data.length - 1
          ? widget.valueFormatter(widget.data[_selectedIndex + 1])
          : null,
      decreasedValue: _selectedIndex > 0
          ? widget.valueFormatter(widget.data[_selectedIndex - 1])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              summary,
              key: ValueKey(_selectedIndex),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _select(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragStart: (details) =>
                  _select(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (details) =>
                  _select(details.localPosition.dx, constraints.maxWidth),
              child: SizedBox(
                height: math.max(widget.height, 44),
                child: CustomPaint(
                  size: Size(double.infinity, widget.height),
                  painter: _InteractiveSparkPainter(
                    widget.data,
                    widget.color,
                    c.border,
                    c.surface,
                    _selectedIndex,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                widget.labels.first,
                style: TextStyle(
                  fontFamily: SfType.mono,
                  fontSize: 9,
                  color: c.muted,
                ),
              ),
              const Spacer(),
              Text(
                widget.labels.last,
                style: TextStyle(
                  fontFamily: SfType.mono,
                  fontSize: 9,
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

class _InteractiveSparkPainter extends CustomPainter {
  const _InteractiveSparkPainter(
    this.data,
    this.color,
    this.grid,
    this.surface,
    this.selectedIndex,
  );

  final List<double> data;
  final Color color;
  final Color grid;
  final Color surface;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final lo = data.reduce(math.min);
    final hi = data.reduce(math.max);
    final range = hi == lo ? 1.0 : hi - lo;
    final usableHeight = math.max(1, size.height - 8);
    Offset point(int index) => Offset(
      data.length == 1
          ? size.width / 2
          : index / (data.length - 1) * size.width,
      4 + usableHeight - (data[index] - lo) / range * usableHeight,
    );

    for (var row = 1; row <= 2; row++) {
      final y = size.height / 3 * row;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = grid.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
    }

    if (data.length >= 2) {
      final path = Path()..moveTo(point(0).dx, point(0).dy);
      for (var index = 1; index < data.length; index++) {
        path.lineTo(point(index).dx, point(index).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final selected = point(selectedIndex);
    canvas.drawLine(
      Offset(selected.dx, 0),
      Offset(selected.dx, size.height),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(selected, 5.5, Paint()..color = surface);
    canvas.drawCircle(
      selected,
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_InteractiveSparkPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid ||
      oldDelegate.surface != surface ||
      oldDelegate.selectedIndex != selectedIndex;
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
  final String? label;
  final String? display;

  const DonutSegment(this.value, this.color, {this.label, this.display});
}

/// A shared, touch-aware donut used by every analytics surface.
///
/// Tapping a segment replaces the centre total with that segment's name,
/// value and share. Tapping the centre restores the original summary.
class Donut extends StatefulWidget {
  final double size;
  final double thickness;
  final List<DonutSegment> segments;
  final Widget center;
  final ValueChanged<int?>? onSelected;

  const Donut({
    super.key,
    required this.size,
    required this.thickness,
    required this.segments,
    required this.center,
    this.onSelected,
  });

  @override
  State<Donut> createState() => _DonutState();
}

class _DonutState extends State<Donut> {
  int? _selectedIndex;

  double get _total => widget.segments.fold<double>(
    0,
    (total, segment) => total + math.max(0, segment.value),
  );

  void _selectAt(Offset position) {
    if (widget.segments.isEmpty || _total <= 0) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = position - center;
    final distance = delta.distance;
    final innerRadius = math.max(0, widget.size / 2 - widget.thickness - 5);
    if (distance <= innerRadius) {
      if (_selectedIndex != null) {
        setState(() => _selectedIndex = null);
        widget.onSelected?.call(null);
      }
      return;
    }
    if (distance > widget.size / 2 + 8) return;

    // The painter starts at twelve o'clock; normalise the pointer angle to
    // that same clockwise [0, 2π) coordinate system.
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var end = 0.0;
    for (var index = 0; index < widget.segments.length; index++) {
      end += math.max(0, widget.segments[index].value) / _total * math.pi * 2;
      if (angle <= end || index == widget.segments.length - 1) {
        if (_selectedIndex != index) {
          setState(() => _selectedIndex = index);
          widget.onSelected?.call(index);
        }
        return;
      }
    }
  }

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  Widget _selectedCenter(BuildContext context) {
    final c = SfTheme.of(context);
    final segment = widget.segments[_selectedIndex!];
    final percent = _total <= 0
        ? '0%'
        : '${(segment.value / _total * 100).round()}%';
    final value = segment.display ?? _number(segment.value);
    final detail = value == percent ? value : '$value · $percent';
    final innerSize = math
        .max(28, widget.size - widget.thickness * 2 - 8)
        .toDouble();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: SizedBox.square(
        key: ValueKey(_selectedIndex),
        dimension: innerSize,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: innerSize),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    segment.label ?? 'Segment ${_selectedIndex! + 1}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 10,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: c.ink2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: SfType.mono,
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: segment.color,
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
    final c = SfTheme.of(context);
    final selected = _selectedIndex;
    final semantics = selected == null
        ? 'Circular chart. Tap a segment for details.'
        : '${widget.segments[selected].label ?? 'Segment ${selected + 1}'}, '
              '${widget.segments[selected].display ?? _number(widget.segments[selected].value)}';
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _selectAt(details.localPosition),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: selected == null ? 1 : 1.025,
                duration: const Duration(milliseconds: 180),
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _DonutPainter(
                    widget.segments,
                    widget.thickness,
                    c.surface2,
                    selected,
                  ),
                ),
              ),
              selected == null ? widget.center : _selectedCenter(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double thickness;
  final Color track;
  final int? selectedIndex;
  _DonutPainter(this.segments, this.thickness, this.track, this.selectedIndex);
  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
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
    for (var index = 0; index < segments.length; index++) {
      final s = segments[index];
      final sweep = (s.value / total) * math.pi * 2;
      final selected = selectedIndex == index;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - 0.04),
        false,
        Paint()
          ..color = selectedIndex == null || selected
              ? s.color
              : s.color.withValues(alpha: 0.28)
          ..strokeWidth = selected ? thickness + 3 : thickness
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments ||
      old.thickness != thickness ||
      old.track != track ||
      old.selectedIndex != selectedIndex;
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

/// Adapted from the Staff app's `SfSurfaceCard`.
///
/// This is the shared physical surface for the CEO console.  It intentionally
/// owns the reference app's radius, border and clipping so
/// feature screens no longer construct their own unrelated Container cards.
class SfSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  const SfSurfaceCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Material(
      color: color ?? c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: c.border.withValues(alpha: 0.92)),
      ),
      elevation: 0,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Backward-compatible facade over the reference surface component.
class SfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  const SfCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 8),
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: SfSurfaceCard(padding: padding ?? EdgeInsets.zero, child: child),
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
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SfType.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
          if (link != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  link!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: SfType.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.primary,
                  ),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
              fontFamily: SfType.display,
              fontSize: 28,
              fontWeight: FontWeight.w400,
              height: 1.12,
              letterSpacing: -0.25,
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

/// Large page header adapted from the reference project's `SfLargeAppBar`.
/// Existing pages may keep their current title/copy while sharing the new
/// hierarchy, breathing room and editorial type scale.
class SfLargeAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  const SfLargeAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 12, 12),
      color: c.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SfType.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    height: 1.05,
                    letterSpacing: -0.2,
                    color: c.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SfType.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: c.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    actions[index],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Reference-style form/search input. It wraps Flutter's native text field,
/// so focus, validation and existing callbacks remain unchanged.
class SfTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  const SfTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onTap: onTap,
      cursorColor: c.primary,
      style: TextStyle(
        fontFamily: SfType.ui,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(
          fontFamily: SfType.ui,
          fontSize: 13,
          color: c.muted,
        ),
        hintStyle: TextStyle(
          fontFamily: SfType.ui,
          fontSize: 14,
          color: c.muted,
        ),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.7),
        ),
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
      height: 44,
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
                    ? c.primarySoft
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: ai
                      ? c.aiBorder
                      : on
                      ? c.primarySoft
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
                      ? c.primaryInk
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

/// Single-select chip row with a tonal selected state.
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
      height: 44,
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
                color: on ? c.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? c.primarySoft : c.border),
              ),
              child: Text(
                items[i],
                style: TextStyle(
                  fontFamily: SfType.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? c.primaryInk : c.muted,
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
    final iconOnly = icon != null && label.trim().isEmpty;
    return Material(
      color: primary ? c.primary : c.primarySoft,
      // Buttons in the reference workspace are deliberately pill-shaped. It
      // gives primary actions a calm, recognisable affordance across pages.
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: iconOnly ? 0 : 18,
          ),
          decoration: BoxDecoration(
            border: primary ? null : Border.all(color: c.primarySoft),
            borderRadius: BorderRadius.circular(999),
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
                Icon(icon, size: 18, color: primary ? c.surface : c.primaryInk),
                if (!iconOnly) const SizedBox(width: 8),
              ],
              if (!iconOnly)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primary ? c.surface : c.primaryInk,
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
        // Keep the floating snack bar inside the safe area. A large synthetic
        // bottom margin can push it completely off small screens or above a
        // sheet, making feedback invisible and triggering a layout error.
        margin: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        backgroundColor: bg ?? SfTheme.of(context).ink,
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
