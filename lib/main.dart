import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';
import 'theme.dart';
import 'data.dart';
import 'store.dart';
import 'settings.dart';
import 'i18n.dart';
import 'console.dart';
import 'widgets.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DeviceNotificationService.instance.initialize();
  } catch (_) {
    // Web/desktop previews can run without a native notification bridge.
  }
  AppSettings? restoredSettings;
  try {
    restoredSettings = await AppSettings.load();
  } catch (_) {
    // The preview remains usable if platform storage is unavailable.
  }
  runApp(CeoManagerApp(initialSettings: restoredSettings));
}

/// Maps the authenticated backend profile to the only workspace the account
/// may open. Unknown role strings stay unresolved instead of being promoted to
/// a more privileged local role.
SfRole? sfRoleFromApiProfile(Map<String, dynamic>? profile) {
  if (profile == null) return null;
  final raw = apiValue(profile, const [
    'role',
    'role_name',
    'role_slug',
    'user_role',
    'position',
  ]);
  final normalized = apiText(
    raw,
  ).toLowerCase().replaceAll(RegExp(r'[^a-zа-яё0-9]+'), '_');
  if (normalized.contains('audit') ||
      normalized.contains('auditor') ||
      normalized.contains('compliance')) {
    return SfRole.audit;
  }
  if (normalized.contains('manager') ||
      normalized.contains('administrator') ||
      normalized == 'admin' ||
      normalized.contains('branch_head')) {
    return SfRole.manager;
  }
  if (normalized.contains('ceo') ||
      normalized.contains('owner') ||
      normalized.contains('director') ||
      normalized.contains('superadmin') ||
      normalized.contains('super_admin')) {
    return SfRole.ceo;
  }
  return null;
}

class CeoManagerApp extends StatefulWidget {
  const CeoManagerApp({super.key, this.initialSettings});

  final AppSettings? initialSettings;

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
  late final AppSettings settings;
  // Live v1 API session. It is kept above every route, mirroring the web
  // console's StoreProvider, so a successful connection can hydrate all pages
  // without passing credentials through widgets.
  late final ApiSession apiSession = ApiSession();
  void _onSettings() => setState(() {});

  SfRole? _roleFromLiveProfile() => sfRoleFromApiProfile(apiSession.me);

  void _onApiSession() {
    if (!mounted || !apiSession.authenticated) return;
    final liveRole = _roleFromLiveProfile();
    if (liveRole != null && liveRole != role) {
      _openWorkspace(liveRole);
    }
  }

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings ?? AppSettings();
    settings.addListener(_onSettings);
    apiSession.addListener(_onApiSession);
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    apiSession.removeListener(_onApiSession);
    settings.dispose();
    apiSession.dispose();
    super.dispose();
  }

  void _openWorkspace(SfRole r) => setState(() {
    role = r;
    store = AppStore.seed(r);
  });

  @override
  Widget build(BuildContext context) {
    final c = settings.colors;
    return ApiScope(
      session: apiSession,
      child: SettingsScope(
        settings: settings,
        child: AppScope(
          store: store,
          child: MaterialApp(
            title: 'StarForge EDU · CEO Manager',
            debugShowCheckedModeBanner: false,
            theme: sfMaterialTheme(c, dark: settings.dark),
            // Apply the live density (text-scale) tweak globally and paint the
            // chosen background pattern behind every route.
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final app = SfTheme(
                colors: c,
                child: settings.pattern == SfPattern.none
                    ? child ?? const SizedBox.shrink()
                    : Stack(
                        children: [
                          child ?? const SizedBox.shrink(),
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
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: c.surface,
                  statusBarIconBrightness: settings.dark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarIconBrightness: settings.dark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: MediaQuery(
                  data: mq.copyWith(
                    // Density is a product preference, not a replacement for
                    // the user’s system accessibility setting.  Keep the OS
                    // scale and apply the small density adjustment on top.
                    textScaler: TextScaler.linear(
                      mq.textScaler.scale(1) * settings.textScale,
                    ),
                  ),
                  child: app,
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
                      onSwitchRole: () {
                        // A live account may only open the workspace granted
                        // by `/users/me`; arbitrary role switching is reserved
                        // for the explicit offline product preview.
                        if (apiSession.authenticated) {
                          final liveRole = _roleFromLiveProfile();
                          if (liveRole != null && liveRole != role) {
                            _openWorkspace(liveRole);
                          }
                          return;
                        }
                        setState(() => role = null);
                      },
                    ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 840;
                  final chooser = _workspaceChooser(context, c);
                  if (!wide) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          children: [
                            _brand(context, c),
                            const SizedBox(height: 34),
                            chooser,
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(
                          children: [
                            Expanded(flex: 6, child: _hero(c)),
                            const SizedBox(width: 30),
                            SizedBox(width: 420, child: chooser),
                          ],
                        ),
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

  Widget _brand(BuildContext context, SfColors c) => Row(
    children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: SfStar(size: 26, color: c.surface)),
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

  Widget _workspaceChooser(BuildContext context, SfColors c) => DecoratedBox(
    decoration: BoxDecoration(
      color: c.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: c.border),
      boxShadow: [
        BoxShadow(
          color: c.ink.withValues(alpha: .12),
          blurRadius: 42,
          offset: const Offset(0, 20),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERATING MODE',
            style: TextStyle(
              fontFamily: SfType.mono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Boshqaruv nuqtasini tanlang',
            style: TextStyle(
              fontFamily: SfType.display,
              fontStyle: FontStyle.italic,
              fontSize: 31,
              height: 1,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Har bir ish maydoni o‘zining muhim qarorlari va oqimlariga moslangan.',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 12.5,
              height: 1.45,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 22),
          _WorkspaceCard(
            role: SfRole.ceo,
            icon: Icons.account_balance_rounded,
            title: 'CEO Manager',
            subtitle: 'Filiallar, odamlar va umumiy ko‘rsatkichlar',
            color: c.primary,
            onTap: () => onLogin(SfRole.ceo),
          ),
          const SizedBox(height: 10),
          _WorkspaceCard(
            role: SfRole.manager,
            icon: Icons.business_center_rounded,
            title: 'Manager',
            subtitle: 'Filial operatsiyalari va tasdiqlashlar',
            color: c.success,
            onTap: () => onLogin(SfRole.manager),
          ),
          const SizedBox(height: 10),
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
  );

  Widget _hero(SfColors c) => Container(
    height: double.infinity,
    padding: const EdgeInsets.all(46),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c.ink,
          Color.alphaBlend(c.primary.withValues(alpha: .62), c.ink),
          Color.alphaBlend(c.accent.withValues(alpha: .22), c.ink),
        ],
      ),
      borderRadius: BorderRadius.circular(36),
      boxShadow: [
        BoxShadow(
          color: c.primary.withValues(alpha: .30),
          blurRadius: 54,
          offset: const Offset(0, 28),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: c.surface.withValues(alpha: .18)),
              ),
              child: SfStar(size: 24, color: c.accent),
            ),
            const SizedBox(width: 12),
            Text(
              'STARFORGE / EDU',
              style: TextStyle(
                fontFamily: SfType.mono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: c.surface.withValues(alpha: .8),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          'Education\nwithout\nblind spots.',
          style: TextStyle(
            fontFamily: SfType.display,
            fontStyle: FontStyle.italic,
            fontSize: 61,
            height: .9,
            letterSpacing: -1.8,
            color: c.surface,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 430,
          child: Text(
            'Bitta jonli nazorat markazida faoliyat, pul oqimi va odamlar uchun aniq qarorlar.',
            style: TextStyle(
              fontFamily: SfType.ui,
              fontSize: 15,
              height: 1.5,
              color: c.surface.withValues(alpha: .74),
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            _heroStat(c, '07', 'faol filial'),
            const SizedBox(width: 30),
            _heroStat(c, '1.8K', 'o‘quvchi'),
            const SizedBox(width: 30),
            _heroStat(c, 'LIVE', 'qarorlar oqimi'),
          ],
        ),
      ],
    ),
  );

  Widget _heroStat(SfColors c, String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontFamily: SfType.mono,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.accent,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: SfType.ui,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: c.surface.withValues(alpha: .58),
        ),
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

/// Static tonal fields behind the login form. They give the page depth without
/// a looping decorative animation or any dependence on motion preferences.
class _LoginBackdrop extends StatelessWidget {
  final SfColors c;
  const _LoginBackdrop(this.c);

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
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            top: -72,
            left: -70,
            child: _blob(240, [
              c.primary.withValues(alpha: 0.20),
              c.primary.withValues(alpha: 0),
            ]),
          ),
          Positioned(
            bottom: -118,
            right: -60,
            child: _blob(280, [
              c.accent.withValues(alpha: 0.18),
              c.accent.withValues(alpha: 0),
            ]),
          ),
          Positioned(
            top: 248,
            right: -50,
            child: _blob(190, [
              c.primarySoft.withValues(alpha: 0.50),
              c.primarySoft.withValues(alpha: 0),
            ]),
          ),
        ],
      ),
    );
  }
}
