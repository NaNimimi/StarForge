import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String> readNotificationKeys;
  final Set<String> hiddenNotificationKeys;

  AppSettings({
    this.dark = false,
    this.lang = SfLang.uz,
    this.palette = 0,
    this.layout = 0,
    this.density = 1,
    // Decorative patterns must be opt-in. Rendering a dot layer before the
    // first screen has painted makes cold starts look like a loading glitch.
    this.pattern = SfPattern.none,
    this.chatDesign = SfChatDesign.telegram,
    this.chatWallpaper = SfChatWallpaper.telegramClouds,
    this.chatWallpaperPath,
    this.font = 0,
    this.currency = SfCurrency.uzs,
    Set<String>? readNotificationKeys,
    Set<String>? hiddenNotificationKeys,
  }) : readNotificationKeys = readNotificationKeys ?? <String>{},
       hiddenNotificationKeys = hiddenNotificationKeys ?? <String>{} {
    gCurrency = currency;
    SfType.ui = kFonts[font].$1;
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    int index(String key, int length, int fallback) {
      final value = prefs.getInt(key);
      return value != null && value >= 0 && value < length ? value : fallback;
    }

    return AppSettings(
      dark: prefs.getBool('appearance.dark') ?? false,
      lang: SfLang.values[index('appearance.lang', SfLang.values.length, 0)],
      palette: index('appearance.palette', kPalettes.length, 0),
      layout: index('appearance.layout', kLayouts.length, 0),
      density: index('appearance.density', kDensities.length, 1),
      pattern: SfPattern
          .values[index('appearance.pattern', SfPattern.values.length, 0)],
      chatDesign:
          SfChatDesign.values[index(
            'appearance.chat_design',
            SfChatDesign.values.length,
            0,
          )],
      chatWallpaper:
          SfChatWallpaper.values[index(
            'appearance.chat_wallpaper',
            SfChatWallpaper.values.length,
            0,
          )],
      chatWallpaperPath: prefs.getString('appearance.chat_wallpaper_path'),
      font: index('appearance.font', kFonts.length, 0),
      currency: SfCurrency
          .values[index('appearance.currency', SfCurrency.values.length, 0)],
      readNotificationKeys:
          (prefs.getStringList('notifications.read') ?? const []).toSet(),
      hiddenNotificationKeys:
          (prefs.getStringList('notifications.hidden') ?? const []).toSet(),
    );
  }

  void _commit() {
    unawaited(_save());
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('appearance.dark', dark),
      prefs.setInt('appearance.lang', lang.index),
      prefs.setInt('appearance.palette', palette),
      prefs.setInt('appearance.layout', layout),
      prefs.setInt('appearance.density', density),
      prefs.setInt('appearance.pattern', pattern.index),
      prefs.setInt('appearance.chat_design', chatDesign.index),
      prefs.setInt('appearance.chat_wallpaper', chatWallpaper.index),
      prefs.setInt('appearance.font', font),
      prefs.setInt('appearance.currency', currency.index),
      prefs.setStringList(
        'notifications.read',
        readNotificationKeys.toList(growable: false),
      ),
      prefs.setStringList(
        'notifications.hidden',
        hiddenNotificationKeys.toList(growable: false),
      ),
      if (chatWallpaperPath == null)
        prefs.remove('appearance.chat_wallpaper_path')
      else
        prefs.setString('appearance.chat_wallpaper_path', chatWallpaperPath!),
    ]);
  }

  SfColors get colors {
    final base = dark ? SfColors.dark : SfColors.light;
    if (palette == 0) return base; // default Saroy is left pixel-identical
    final p = kPalettes[palette];
    return base.withPalette(p.primary, p.accent, dark: dark);
  }

  double get textScale => kDensities[density];

  String _notificationKey(SfRole role, String id) => '${role.name}|$id';

  bool notificationIsRead(SfRole role, String id) =>
      readNotificationKeys.contains(_notificationKey(role, id));

  bool notificationIsHidden(SfRole role, String id) =>
      hiddenNotificationKeys.contains(_notificationKey(role, id));

  void markNotificationRead(SfRole role, String id) {
    if (!readNotificationKeys.add(_notificationKey(role, id))) return;
    _commit();
  }

  void markNotificationsRead(SfRole role, Iterable<String> ids) {
    final before = readNotificationKeys.length;
    readNotificationKeys.addAll(ids.map((id) => _notificationKey(role, id)));
    if (before != readNotificationKeys.length) _commit();
  }

  void hideNotification(SfRole role, String id) {
    final key = _notificationKey(role, id);
    final hiddenChanged = hiddenNotificationKeys.add(key);
    final readChanged = readNotificationKeys.add(key);
    if (hiddenChanged || readChanged) _commit();
  }

  Future<void> saveNotificationState() => _save();

  void toggleTheme() {
    dark = !dark;
    _commit();
  }

  void setDark(bool v) {
    if (dark == v) return;
    dark = v;
    _commit();
  }

  void setLang(SfLang l) {
    if (lang == l) return;
    lang = l;
    _commit();
  }

  void setPalette(int i) {
    if (palette == i) return;
    palette = i;
    _commit();
  }

  void setLayout(int i) {
    if (layout == i) return;
    layout = i;
    _commit();
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
    _commit();
  }

  void setPattern(SfPattern p) {
    if (pattern == p) return;
    pattern = p;
    _commit();
  }

  void setChatWallpaper(SfChatWallpaper wallpaper) {
    if (chatWallpaper == wallpaper) return;
    chatWallpaper = wallpaper;
    _commit();
  }

  void setChatDesign(SfChatDesign design) {
    if (chatDesign == design) return;
    chatDesign = design;
    _commit();
  }

  void setChatWallpaperPath(String path) {
    chatWallpaper = SfChatWallpaper.custom;
    chatWallpaperPath = path;
    _commit();
  }

  void setFont(int i) {
    if (font == i) return;
    font = i;
    SfType.ui = kFonts[i].$1;
    _commit();
  }

  void setCurrency(SfCurrency cur) {
    if (currency == cur) return;
    currency = cur;
    gCurrency = cur;
    _commit();
  }

  void reset() {
    dark = false;
    palette = 0;
    layout = 0;
    density = 1;
    pattern = SfPattern.none;
    chatDesign = SfChatDesign.telegram;
    chatWallpaper = SfChatWallpaper.telegramClouds;
    chatWallpaperPath = null;
    font = 0;
    currency = SfCurrency.uzs;
    gCurrency = SfCurrency.uzs;
    SfType.ui = 'Manrope';
    _commit();
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

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
