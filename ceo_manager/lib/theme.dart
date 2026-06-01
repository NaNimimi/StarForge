import 'package:flutter/material.dart';

/// StarForge EDU design tokens — Saroy (terracotta) palette.
/// Light + dark variants ported from tokens.css.
class SfColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color muted2;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color primaryInk;
  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color success;
  final Color successSoft;
  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;
  final Color ai;
  final List<Color> aiBg;
  final Color aiBorder;

  const SfColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.muted2,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.primaryInk,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.success,
    required this.successSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.ai,
    required this.aiBg,
    required this.aiBorder,
  });

  static const SfColors light = SfColors(
    bg: Color(0xFFFBF6EC),
    surface: Color(0xFFFFFCF5),
    surface2: Color(0xFFF4EBD8),
    surface3: Color(0xFFEADFC4),
    ink: Color(0xFF1F1B16),
    ink2: Color(0xFF3A332A),
    muted: Color(0xFF847663),
    muted2: Color(0xFFB0A38B),
    border: Color(0xFFE5D9BE),
    borderStrong: Color(0xFFCFC0A0),
    primary: Color(0xFFB85535),
    primaryHover: Color(0xFFA04524),
    primarySoft: Color(0xFFF3D9CC),
    primaryInk: Color(0xFF5A2412),
    accent: Color(0xFFD89A2E),
    accentSoft: Color(0xFFF6E4B8),
    accentInk: Color(0xFF6B4810),
    success: Color(0xFF4F7B3B),
    successSoft: Color(0xFFDDEACA),
    warn: Color(0xFFC68423),
    warnSoft: Color(0xFFF6E4B8),
    danger: Color(0xFFB33A2A),
    dangerSoft: Color(0xFFF3D2CC),
    ai: Color(0xFF8B5A0F),
    aiBg: [Color(0xFFF9EAC4), Color(0xFFF6DCB0)],
    aiBorder: Color(0xFFE2BC72),
  );

  static const SfColors dark = SfColors(
    bg: Color(0xFF14110D),
    surface: Color(0xFF1D1914),
    surface2: Color(0xFF28231C),
    surface3: Color(0xFF332D24),
    ink: Color(0xFFF2EADA),
    ink2: Color(0xFFD8CFBC),
    muted: Color(0xFF9E927E),
    muted2: Color(0xFF6E6555),
    border: Color(0xFF3A3329),
    borderStrong: Color(0xFF4E4435),
    primary: Color(0xFFE58B6A),
    primaryHover: Color(0xFFED9C7F),
    primarySoft: Color(0xFF3A2418),
    primaryInk: Color(0xFFFCDCCA),
    accent: Color(0xFFEBBE5E),
    accentSoft: Color(0xFF3D2F12),
    accentInk: Color(0xFFFCE3A4),
    success: Color(0xFF4F7B3B),
    successSoft: Color(0xFFDDEACA),
    warn: Color(0xFFC68423),
    warnSoft: Color(0xFFF6E4B8),
    danger: Color(0xFFB33A2A),
    dangerSoft: Color(0xFFF3D2CC),
    ai: Color(0xFFF0CB7F),
    aiBg: [Color(0xFF2D241B), Color(0xFF3A2D1E)],
    aiBorder: Color(0xFF66502A),
  );
}

/// Typography helpers mirroring the Manrope / Instrument Serif / JetBrains Mono stack.
class SfType {
  static const String ui = 'Manrope';
  static const String display = 'InstrumentSerif';
  static const String mono = 'JetBrainsMono';
}

/// Inherited theme so widgets can read [SfColors] by role/brightness.
class SfTheme extends InheritedWidget {
  final SfColors colors;
  const SfTheme({super.key, required this.colors, required super.child});

  static SfColors of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<SfTheme>();
    assert(t != null, 'SfTheme not found in context');
    return t!.colors;
  }

  @override
  bool updateShouldNotify(SfTheme oldWidget) => colors != oldWidget.colors;
}
