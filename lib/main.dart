import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'settings.dart';
import 'i18n.dart';
import 'console.dart';
import 'widgets.dart';

void main() {
  runApp(const CeoManagerApp());
}

class CeoManagerApp extends StatefulWidget {
  const CeoManagerApp({super.key});
  @override
  State<CeoManagerApp> createState() => _CeoManagerAppState();
}

class _CeoManagerAppState extends State<CeoManagerApp> {
  SfRole? role;
  // Seeded again whenever the user opens a different workspace. The first
  // value only provides AppScope while the workspace picker is on screen.
  AppStore store = AppStore.seed(SfRole.ceo);

  // Global theme/language — survives sign-out and rebuilds the whole app on
  // change so every screen re-themes and re-translates instantly.
  late final AppSettings settings = AppSettings()..addListener(_onSettings);
  void _onSettings() => setState(() {});

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    settings.dispose();
    super.dispose();
  }

  void _openWorkspace(SfRole r) => setState(() {
    role = r;
    store = AppStore.seed(r);
  });

  @override
  Widget build(BuildContext context) {
    final c = settings.colors;
    return SettingsScope(
      settings: settings,
      child: AppScope(
        store: store,
        child: MaterialApp(
          title: 'StarForge EDU · CEO Manager',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: c.bg,
            fontFamily: SfType.ui,
            splashFactory: InkRipple.splashFactory,
            useMaterial3: true,
            brightness: settings.dark ? Brightness.dark : Brightness.light,
          ),
          // Apply the live density (text-scale) tweak globally and paint the
          // chosen background pattern behind every route.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: settings.pattern == SfPattern.none
                  ? child!
                  : Stack(
                      children: [
                        child!,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PatternPainter(
                                settings.pattern,
                                c.muted2.withValues(alpha: 0.22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
          // Animated swap between the workspace picker and the active console.
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final fade = FadeTransition(opacity: anim, child: child);
              return ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
                child: fade,
              );
            },
            child: role == null
                ? LoginScreen(
                    key: const ValueKey('workspace-picker'),
                    onLogin: _openWorkspace,
                  )
                : Console(
                    key: ValueKey('console-${role!.name}'),
                    cfg: kRoleConfigs[role]!,
                    onSwitchRole: () => setState(() => role = null),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Faint canvas pattern (dots / grid / tile / topo) painted over the app bg.
class _PatternPainter extends CustomPainter {
  final SfPattern pattern;
  final Color color;
  _PatternPainter(this.pattern, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    switch (pattern) {
      case SfPattern.dots:
        for (double y = 0; y < size.height; y += 22) {
          for (double x = 0; x < size.width; x += 22) {
            canvas.drawCircle(Offset(x, y), 1, p);
          }
        }
        break;
      case SfPattern.grid:
        for (double x = 0; x < size.width; x += 28) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = 0; y < size.height; y += 28) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        break;
      case SfPattern.tile:
        for (double d = -size.height; d < size.width; d += 14) {
          canvas.drawLine(
            Offset(d, 0),
            Offset(d + size.height, size.height),
            p,
          );
          canvas.drawLine(
            Offset(d, size.height),
            Offset(d + size.height, 0),
            p,
          );
        }
        break;
      case SfPattern.topo:
        for (double y = 0; y < size.height; y += 18) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        break;
      case SfPattern.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern || old.color != color;
}

/// Password-free workspace picker. The former local demo login has been
/// deliberately removed: this is a device-local product preview, so a user can
/// move freely between CEO, manager and audit workspaces.
///
/// The class name remains [LoginScreen] for backward-compatible embedding and
/// tests, but there are no credential fields or validation in this screen.
class LoginScreen extends StatelessWidget {
  final ValueChanged<SfRole> onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  Widget build(BuildContext context) {
    final c = SettingsScope.of(context).colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            // Soft drifting colour glows behind the form.
            Positioned.fill(child: _LoginBackdrop(c)),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    children: [
                      _brand(context, c),
                      const SizedBox(height: 38),
                      Text(
                        'Ish maydonini tanlang',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Kirish ma’lumotlari talab qilinmaydi. Kerakli konsolni bosing.',
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 13,
                          color: c.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WorkspaceCard(
                        role: SfRole.ceo,
                        icon: Icons.account_balance_rounded,
                        title: 'CEO Manager',
                        subtitle: 'Filiallar, odamlar va umumiy ko‘rsatkichlar',
                        color: c.primary,
                        onTap: () => onLogin(SfRole.ceo),
                      ),
                      const SizedBox(height: 11),
                      _WorkspaceCard(
                        role: SfRole.manager,
                        icon: Icons.business_center_rounded,
                        title: 'Manager',
                        subtitle: 'Filial operatsiyalari va tasdiqlashlar',
                        color: c.success,
                        onTap: () => onLogin(SfRole.manager),
                      ),
                      const SizedBox(height: 11),
                      _WorkspaceCard(
                        role: SfRole.audit,
                        icon: Icons.shield_rounded,
                        title: 'Audit',
                        subtitle: 'Nazorat, signallar va tekshiruvlar',
                        color: c.accent,
                        onTap: () => onLogin(SfRole.audit),
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

  Widget _brand(BuildContext context, SfColors c) => Row(
    children: [
      // Gentle breathing pulse on the logo.
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (_, v, child) =>
            Transform.scale(scale: 0.6 + 0.4 * v, child: child),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: SfStar(size: 26, color: Colors.white)),
        ),
      ),
      const SizedBox(width: 13),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'StarForge EDU',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: c.ink,
            ),
          ),
          Text(
            tr(context, 'brand_sub'),
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12,
              color: c.muted,
            ),
          ),
        ],
      ),
    ],
  );
}

class _WorkspaceCard extends StatelessWidget {
  final SfRole role;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _WorkspaceCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Semantics(
      button: true,
      label: '$title ish maydoni',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('workspace-${role.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient, slowly drifting colour glows behind the login form.
class _LoginBackdrop extends StatefulWidget {
  final SfColors c;
  const _LoginBackdrop(this.c);
  @override
  State<_LoginBackdrop> createState() => _LoginBackdropState();
}

class _LoginBackdropState extends State<_LoginBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _blob(double size, List<Color> colors) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: colors),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_a.value);
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: -90 + 34 * t,
                left: -70 - 24 * t,
                child: _blob(240, [
                  c.primary.withValues(alpha: 0.22),
                  c.primary.withValues(alpha: 0),
                ]),
              ),
              Positioned(
                bottom: -110 - 26 * t,
                right: -80 + 34 * t,
                child: _blob(280, [
                  const Color(0xFFD89A2E).withValues(alpha: 0.20),
                  const Color(0x00D89A2E),
                ]),
              ),
              Positioned(
                top: 220 + 46 * t,
                right: -50 - 16 * t,
                child: _blob(190, [
                  c.accent.withValues(alpha: 0.16),
                  c.accent.withValues(alpha: 0),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
