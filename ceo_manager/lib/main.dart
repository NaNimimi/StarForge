import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'data.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StarForge EDU · CEO Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: SfColors.light.bg,
        fontFamily: SfType.ui,
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
      ),
      home: role == null
          ? RolePicker(onPick: (r) => setState(() => role = r))
          : Console(
              cfg: kRoleConfigs[role]!,
              onSwitchRole: () => setState(() => role = null),
            ),
    );
  }
}

/// Launch screen that lets you enter one of the three consoles.
class RolePicker extends StatelessWidget {
  final ValueChanged<SfRole> onPick;
  const RolePicker({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = SfColors.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(13)),
                        child: const Center(child: SfStar(size: 24, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('StarForge EDU',
                              style: TextStyle(
                                  fontFamily: SfType.ui,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: c.ink)),
                          Text("O'quv markazi boshqaruvi",
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text('KONSOLNI TANLANG',
                      style: TextStyle(
                          fontFamily: SfType.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: c.muted)),
                  const SizedBox(height: 14),
                  for (final entry in kRoleConfigs.entries)
                    _RoleTile(cfg: entry.value, onTap: () => onPick(entry.key)),
                  const SizedBox(height: 20),
                  Text(
                    'Demo · namuna maʼlumotlar bilan. Backend ulanmagan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted2),
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

class _RoleTile extends StatelessWidget {
  final RoleConfig cfg;
  final VoidCallback onTap;
  const _RoleTile({required this.cfg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SfColors.light;
    final accent = cfg.accent(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SfAvatar(name: cfg.who, size: 48, color: accent),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cfg.label,
                              style: TextStyle(
                                  fontFamily: SfType.ui, fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                            child: Text(cfg.scope,
                                style: TextStyle(
                                    fontFamily: SfType.ui, fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${cfg.who} · ${cfg.roleTitle}',
                          style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.muted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: c.muted2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
