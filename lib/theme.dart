import 'package:flutter/material.dart';

/// StarForge EDU design tokens.
///
/// The product uses a warm, low-glare foundation rather than pure white cards
/// on a cool canvas.  Components consume these semantic roles (rather than
/// raw hue names), so light and dark themes preserve the same hierarchy.
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
    bg: Color(0xFFF1EFE6),
    surface: Color(0xFFFAF8EF),
    surface2: Color(0xFFE5E4D2),
    surface3: Color(0xFFD7D5BD),
    ink: Color(0xFF1A1E18),
    ink2: Color(0xFF2F352A),
    muted: Color(0xFF6F7264),
    muted2: Color(0xFFA2A593),
    border: Color(0xFFD9D6BD),
    borderStrong: Color(0xFFB7B399),
    primary: Color(0xFF4F6A3A),
    primaryHover: Color(0xFF3E5A29),
    primarySoft: Color(0xFFDBE5C7),
    primaryInk: Color(0xFF324D22),
    accent: Color(0xFFBA8C2C),
    accentSoft: Color(0xFFF0E1BB),
    accentInk: Color(0xFF674A0D),
    success: Color(0xFF4F7B3B),
    successSoft: Color(0xFFDDEACA),
    warn: Color(0xFFC68423),
    warnSoft: Color(0xFFF6E4B8),
    danger: Color(0xFFB33A2A),
    dangerSoft: Color(0xFFF3D2CC),
    ai: Color(0xFF77551B),
    aiBg: [Color(0xFFF7EDCE), Color(0xFFEEDDAE)],
    aiBorder: Color(0xFFD8BC72),
  );

  /// Returns a copy with a different primary/accent (and tones derived from
  /// them). Used by the live Tweaks panel to swap the palette app-wide.
  SfColors copyWith({
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? primaryInk,
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
  }) => SfColors(
    bg: bg,
    surface: surface,
    surface2: surface2,
    surface3: surface3,
    ink: ink,
    ink2: ink2,
    muted: muted,
    muted2: muted2,
    border: border,
    borderStrong: borderStrong,
    primary: primary ?? this.primary,
    primaryHover: primaryHover ?? this.primaryHover,
    primarySoft: primarySoft ?? this.primarySoft,
    primaryInk: primaryInk ?? this.primaryInk,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    accentInk: accentInk ?? this.accentInk,
    success: success,
    successSoft: successSoft,
    warn: warn,
    warnSoft: warnSoft,
    danger: danger,
    dangerSoft: dangerSoft,
    ai: ai,
    aiBg: aiBg,
    aiBorder: aiBorder,
  );

  /// Re-skin the whole palette around a chosen primary + accent colour,
  /// deriving the hover / soft / ink tones so contrast stays sensible.
  SfColors withPalette(
    Color basePrimary,
    Color baseAccent, {
    required bool dark,
  }) {
    final p = dark ? sfLighten(basePrimary, 0.16) : basePrimary;
    final a = dark ? sfLighten(baseAccent, 0.14) : baseAccent;
    return copyWith(
      primary: p,
      primaryHover: dark ? sfLighten(p, 0.07) : sfDarken(p, 0.08),
      primarySoft: Color.alphaBlend(
        p.withValues(alpha: dark ? 0.22 : 0.18),
        surface,
      ),
      primaryInk: dark ? sfLighten(p, 0.30) : sfDarken(p, 0.28),
      accent: a,
      accentSoft: Color.alphaBlend(
        a.withValues(alpha: dark ? 0.22 : 0.20),
        surface,
      ),
      accentInk: dark ? sfLighten(a, 0.28) : sfDarken(a, 0.30),
    );
  }

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
    primary: Color(0xFFA6C88A),
    primaryHover: Color(0xFFBFDAAA),
    primarySoft: Color(0xFF2F4026),
    primaryInk: Color(0xFFDDF0CF),
    accent: Color(0xFFE4BF68),
    accentSoft: Color(0xFF423518),
    accentInk: Color(0xFFFFE9AF),
    success: Color(0xFF9BCB7F),
    successSoft: Color(0xFF203A22),
    warn: Color(0xFFF2C46F),
    warnSoft: Color(0xFF3D2D12),
    danger: Color(0xFFF29387),
    dangerSoft: Color(0xFF41221F),
    ai: Color(0xFFF0CB7F),
    aiBg: [Color(0xFF2D241B), Color(0xFF3A2D1E)],
    aiBorder: Color(0xFF66502A),
  );
}

/// Lighten/darken a colour in HSL space — used to derive accent tones.
Color sfLighten(Color c, double amt) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amt).clamp(0.0, 1.0)).toColor();
}

Color sfDarken(Color c, double amt) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amt).clamp(0.0, 1.0)).toColor();
}

/// Typography helpers mirroring the Manrope / Instrument Serif / JetBrains Mono
/// stack. [ui] is mutable so the design panel can swap the body font app-wide.
class SfType {
  static String ui = 'Manrope';
  static const String display = 'InstrumentSerif';
  static const String mono = 'JetBrainsMono';
}

/// Selectable body fonts for the design panel (all bundled).
const List<(String, String)> kFonts = [
  ('Manrope', 'Manrope'),
  ('JetBrainsMono', 'Mono'),
  ('InstrumentSerif', 'Serif'),
];

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

/// Material's default component palette is intentionally opinionated and, if
/// left unconfigured, can reintroduce white controls into an otherwise dark
/// custom UI.  This adapter keeps every stock Material control aligned with
/// the same StarForge tokens used by the bespoke widgets.
ThemeData sfMaterialTheme(SfColors c, {required bool dark}) {
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: c.primary,
    onPrimary: c.surface,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.primaryInk,
    secondary: c.accent,
    onSecondary: c.surface,
    secondaryContainer: c.accentSoft,
    onSecondaryContainer: c.accentInk,
    tertiary: c.ai,
    onTertiary: c.surface,
    tertiaryContainer: c.aiBg.first,
    onTertiaryContainer: c.ink,
    error: c.danger,
    onError: c.surface,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerHighest: c.surface2,
    onSurfaceVariant: c.ink2,
    outline: c.borderStrong,
    outlineVariant: c.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: c.ink,
    onInverseSurface: c.bg,
    inversePrimary: c.primary,
  );
  final inputRounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: SfType.ui,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: c.border,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: SfType.ui,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: c.ink,
      ),
      iconTheme: IconThemeData(color: c.ink),
      actionsIconTheme: IconThemeData(color: c.ink2),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(
        fontFamily: SfType.ui,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: c.ink,
      ),
      contentTextStyle: TextStyle(fontFamily: SfType.ui, color: c.ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      modalBarrierColor: Colors.black.withValues(alpha: dark ? .62 : .38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      dragHandleColor: c.borderStrong,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: TextStyle(fontFamily: SfType.ui, color: c.muted),
      labelStyle: TextStyle(fontFamily: SfType.ui, color: c.ink2),
      floatingLabelStyle: TextStyle(fontFamily: SfType.ui, color: c.primary),
      prefixIconColor: c.muted,
      suffixIconColor: c.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: inputBorder,
      border: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.primary, width: 1.8),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.danger, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.surface,
        disabledBackgroundColor: c.surface3,
        disabledForegroundColor: c.muted,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: SfType.ui,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.surface,
        disabledBackgroundColor: c.surface3,
        disabledForegroundColor: c.muted,
        elevation: 0,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: SfType.ui,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        disabledForegroundColor: c.muted2,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: c.borderStrong),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: SfType.ui,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(40, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: SfType.ui,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.ink2,
        minimumSize: const Size(44, 44),
        shape: inputRounded,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.surface,
      shape: const StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      disabledColor: c.surface3,
      selectedColor: c.primarySoft,
      secondarySelectedColor: c.accentSoft,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontFamily: SfType.ui, color: c.ink2),
      secondaryLabelStyle: TextStyle(
        fontFamily: SfType.ui,
        color: c.primaryInk,
      ),
      brightness: scheme.brightness,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.surface : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.primary : c.surface3,
      ),
      trackOutlineColor: WidgetStatePropertyAll(c.borderStrong),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.surface),
      side: BorderSide(color: c.borderStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.muted,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primarySoft,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: SfType.ui,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.ink2)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(fontFamily: SfType.ui, color: c.bg),
      actionTextColor: c.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(fontFamily: SfType.ui, color: c.bg),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.muted,
      textColor: c.ink,
      subtitleTextStyle: TextStyle(fontFamily: SfType.ui, color: c.muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
