import 'package:flutter/widgets.dart';
import 'theme.dart';
import 'data.dart';

/// Supported UI languages. Index order is reused by the i18n string tables
/// (uz = 0, ru = 1, en = 2) — do not reorder.
enum SfLang { uz, ru, en }

/// A selectable colour palette for the live Tweaks panel — the 10 palettes from
/// the design's "Ko'rinishni sozlash" control. Index 0 (Saroy) keeps the
/// original terracotta palette pixel-identical; others re-skin primary + accent.
class SfPalette {
  final String name; // localised-ish short name
  final String sub; // english descriptor
  final Color primary;
  final Color accent;
  final Color swatch; // light bg swatch for the chip
  const SfPalette(this.name, this.sub, this.primary, this.accent, this.swatch);
}

const List<SfPalette> kPalettes = [
  SfPalette(
    'Saroy',
    'Terracotta',
    Color(0xFFB85535),
    Color(0xFFD89A2E),
    Color(0xFFFBF6EC),
  ),
  SfPalette(
    'Marvarid',
    'Pearl',
    Color(0xFF1F6B66),
    Color(0xFFC4892F),
    Color(0xFFF2F1ED),
  ),
  SfPalette(
    'Samarqand',
    'Indigo',
    Color(0xFF2A3D8F),
    Color(0xFFD8A22A),
    Color(0xFFF4F1E8),
  ),
  SfPalette(
    'Daryo',
    'Sage',
    Color(0xFF4F6A3A),
    Color(0xFFBA8C2C),
    Color(0xFFF1EFE6),
  ),
  SfPalette(
    'Shafaq',
    'Sunset',
    Color(0xFFC2410C),
    Color(0xFFD6608A),
    Color(0xFFFBF1EC),
  ),
  SfPalette(
    'Zumrad',
    'Emerald',
    Color(0xFF0E7C5A),
    Color(0xFFC08A2E),
    Color(0xFFEEF4EF),
  ),
  SfPalette(
    'Lola',
    'Tulip',
    Color(0xFFB3122F),
    Color(0xFFC28A1E),
    Color(0xFFFAF1EF),
  ),
  SfPalette(
    'Tong',
    'Dawn',
    Color(0xFF2563A8),
    Color(0xFFD98A4E),
    Color(0xFFEEF2F7),
  ),
  SfPalette(
    'Qahrabo',
    'Amber',
    Color(0xFFB8791C),
    Color(0xFF3F7A6A),
    Color(0xFFF8F2E8),
  ),
  SfPalette(
    'Siyoh',
    'Ink',
    Color(0xFF2B2A26),
    Color(0xFF9A7B3F),
    Color(0xFFF2F1EE),
  ),
];

/// A nav layout option (web's "Layout · 5"). On mobile the chrome is a fixed
/// bottom-tab shell, so this is stored as a presentation preference; the cards
/// mirror the web control so the design parity is complete.
class SfLayout {
  final String id;
  final String nameKey; // i18n key for the short name
  final String descKey; // i18n key for the sub-description
  const SfLayout(this.id, this.nameKey, this.descKey);
}

const List<SfLayout> kLayouts = [
  SfLayout('sidebar', 'lay_sidebar', 'lay_sidebar_d'),
  SfLayout('rail', 'lay_rail', 'lay_rail_d'),
  SfLayout('topbar', 'lay_topbar', 'lay_topbar_d'),
  SfLayout('dock', 'lay_dock', 'lay_dock_d'),
  SfLayout('zen', 'lay_zen', 'lay_zen_d'),
];

/// Density presets → global text/spacing scale (Ixcham / O'rta / Bo'sh).
const List<double> kDensities = [0.9, 1.0, 1.1];

/// Background pattern options for the app canvas.
enum SfPattern { none, dots, grid, tile, topo }

const List<SfPattern> kPatterns = SfPattern.values;

/// Chat-only wallpaper choices. They are independent from the app canvas so a
/// user can keep a clean dashboard while personalising conversations.
enum SfChatWallpaper {
  telegramClouds,
  whatsappPattern,
  mountains,
  aurora,
  space,
  ocean,
  sakura,
  abstract,
  gradient,
  blur,
  custom,
}

const List<SfChatWallpaper> kChatWallpapers = SfChatWallpaper.values;

/// Bubble/chrome treatment for every chat. This is separate from the
/// wallpaper: a Telegram-style conversation can still use a dark wallpaper.
enum SfChatDesign {
  telegram,
  whatsapp,
  modernDark,
  glass,
  gradient,
  minimal,
  neon,
  nature,
}

const List<SfChatDesign> kChatDesigns = SfChatDesign.values;

/// Global, login-independent app preferences and the live "Tweaks" controls:
/// palette (10), theme, density, background pattern, language.
///
/// Lives above [AppScope]/MaterialApp so a sign-out/sign-in keeps the user's
/// choices. Mutations call [notifyListeners] — the root state listens and
/// rebuilds the whole app so every screen re-themes/re-translates instantly.
class AppSettings extends ChangeNotifier {
  bool dark;
  SfLang lang;
  int palette; // index into kPalettes
  int layout; // index into kLayouts
  int density; // index into kDensities
  SfPattern pattern;
  SfChatDesign chatDesign;
  SfChatWallpaper chatWallpaper;
  String? chatWallpaperPath;
  int font; // index into kFonts
  SfCurrency currency;

  AppSettings({
    this.dark = false,
    this.lang = SfLang.uz,
    this.palette = 0,
    this.layout = 0,
    this.density = 1,
    this.pattern = SfPattern.dots,
    this.chatDesign = SfChatDesign.telegram,
    this.chatWallpaper = SfChatWallpaper.telegramClouds,
    this.chatWallpaperPath,
    this.font = 0,
    this.currency = SfCurrency.uzs,
  }) {
    gCurrency = currency;
    SfType.ui = kFonts[font].$1;
  }

  SfColors get colors {
    final base = dark ? SfColors.dark : SfColors.light;
    if (palette == 0) return base; // default Saroy is left pixel-identical
    final p = kPalettes[palette];
    return base.withPalette(p.primary, p.accent, dark: dark);
  }

  double get textScale => kDensities[density];

  void toggleTheme() {
    dark = !dark;
    notifyListeners();
  }

  void setDark(bool v) {
    if (dark == v) return;
    dark = v;
    notifyListeners();
  }

  void setLang(SfLang l) {
    if (lang == l) return;
    lang = l;
    notifyListeners();
  }

  void setPalette(int i) {
    if (palette == i) return;
    palette = i;
    notifyListeners();
  }

  void setLayout(int i) {
    if (layout == i) return;
    layout = i;
    notifyListeners();
  }

  void cycleLang() {
    final v = SfLang.values;
    setLang(v[(lang.index + 1) % v.length]);
  }

  void cycleCurrency() {
    final v = SfCurrency.values;
    setCurrency(v[(currency.index + 1) % v.length]);
  }

  void setDensity(int i) {
    if (density == i) return;
    density = i;
    notifyListeners();
  }

  void setPattern(SfPattern p) {
    if (pattern == p) return;
    pattern = p;
    notifyListeners();
  }

  void setChatWallpaper(SfChatWallpaper wallpaper) {
    if (chatWallpaper == wallpaper) return;
    chatWallpaper = wallpaper;
    notifyListeners();
  }

  void setChatDesign(SfChatDesign design) {
    if (chatDesign == design) return;
    chatDesign = design;
    notifyListeners();
  }

  void setChatWallpaperPath(String path) {
    chatWallpaper = SfChatWallpaper.custom;
    chatWallpaperPath = path;
    notifyListeners();
  }

  void setFont(int i) {
    if (font == i) return;
    font = i;
    SfType.ui = kFonts[i].$1;
    notifyListeners();
  }

  void setCurrency(SfCurrency cur) {
    if (currency == cur) return;
    currency = cur;
    gCurrency = cur;
    notifyListeners();
  }

  void reset() {
    dark = false;
    palette = 0;
    layout = 0;
    density = 1;
    pattern = SfPattern.dots;
    chatDesign = SfChatDesign.telegram;
    chatWallpaper = SfChatWallpaper.telegramClouds;
    chatWallpaperPath = null;
    font = 0;
    currency = SfCurrency.uzs;
    gCurrency = SfCurrency.uzs;
    SfType.ui = 'Manrope';
    notifyListeners();
  }
}

/// Inherited access to [AppSettings]; descendants that read it rebuild on change.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(s?.notifier != null, 'SettingsScope not found in context');
    return s!.notifier!;
  }
}
