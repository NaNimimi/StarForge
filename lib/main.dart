import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Seeded fresh on each login so every user gets their own dataset and a
  // clean slate. The initial value is a placeholder the login screen never reads.
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

  void _login(SfRole r) => setState(() {
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
              data: mq.copyWith(textScaler: TextScaler.linear(settings.textScale)),
              child: settings.pattern == SfPattern.none
                  ? child!
                  : Stack(
                      children: [
                        child!,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                                painter: _PatternPainter(settings.pattern, c.muted2.withValues(alpha: 0.22))),
                          ),
                        ),
                      ],
                    ),
            );
          },
          // Animated swap between the login shell and the active console.
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
                    key: const ValueKey('login'),
                    onLogin: _login,
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
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
          canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), p);
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
  bool shouldRepaint(_PatternPainter old) => old.pattern != pattern || old.color != color;
}

/// Animated sign-in shell. Three demo accounts (one per console); tap a card to
/// autofill, then "Kirish". No backend — credentials are validated locally.
class LoginScreen extends StatefulWidget {
  final ValueChanged<SfRole> onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late final AnimationController _intro;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final login = _loginCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Fake the round-trip so the spinner reads as a real sign-in.
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    DemoUser? match;
    for (final u in kDemoUsers) {
      if (u.login == login && u.password == pass) {
        match = u;
        break;
      }
    }
    if (match == null) {
      setState(() {
        _busy = false;
        _error = login.isEmpty ? 'err_empty' : 'err_wrong';
      });
      return;
    }
    widget.onLogin(match.role);
  }

  /// Fade + slide a child in along the intro timeline `[start, start+0.5]`.
  Widget _stagger(double start, Widget child) {
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: Transform.scale(scale: 0.97 + 0.03 * anim.value, child: c),
        ),
      ),
      child: child,
    );
  }

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
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    children: [
                  _stagger(0.04, _brand(c)),
                  const SizedBox(height: 30),
                  _stagger(0.08, _heading(c)),
                  const SizedBox(height: 18),
                  _stagger(0.16, _field(c, tr(context, 'login_hint'), _loginCtrl, Icons.person_outline_rounded)),
                  const SizedBox(height: 12),
                  _stagger(0.22, _passwordField(c)),
                  _errorBar(c),
                  const SizedBox(height: 16),
                      _stagger(0.28, _signInButton(c)),
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

  Widget _brand(SfColors c) => Row(
        children: [
          // Gentle breathing pulse on the logo.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: 0.6 + 0.4 * v, child: child),
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
                      offset: const Offset(0, 8)),
                ],
              ),
              child: const Center(child: SfStar(size: 26, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('StarForge EDU',
                  style: TextStyle(
                      fontFamily: SfType.ui,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: c.ink)),
              Text(tr(context, 'brand_sub'),
                  style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
            ],
          ),
        ],
      );

  Widget _heading(SfColors c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'login_title'),
              style: TextStyle(
                  fontFamily: SfType.display,
                  fontSize: 30,
                  height: 1.05,
                  color: c.ink)),
          const SizedBox(height: 4),
          Text(tr(context, 'login_sub'),
              style: TextStyle(fontFamily: SfType.ui, fontSize: 13, color: c.muted)),
        ],
      );

  Widget _field(SfColors c, String hint, TextEditingController ctrl, IconData icon,
      {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _submit(),
      style: TextStyle(fontFamily: SfType.ui, fontSize: 15, color: c.ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: SfType.ui, color: c.muted2, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 20, color: c.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _passwordField(SfColors c) => _field(
        c,
        tr(context, 'pass_hint'),
        _passCtrl,
        Icons.lock_outline_rounded,
        obscure: _obscure,
        suffix: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20, color: c.muted),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );

  Widget _errorBar(SfColors c) => AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: const Color(0xFFB33A2A)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(tr(context, _error!),
                          style: TextStyle(
                              fontFamily: SfType.ui,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB33A2A))),
                    ),
                  ],
                ),
              ),
      );

  Widget _signInButton(SfColors c) {
    return SfTap(
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: c.primary.withValues(alpha: _busy ? 0.18 : 0.34),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _busy ? null : _submit,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _busy
                  ? const SizedBox(
                      key: ValueKey('spin'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr(context, 'sign_in'),
                            style: TextStyle(
                                fontFamily: SfType.ui,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
                      ],
                    ),
            ),
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
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))
        ..repeat(reverse: true);

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
