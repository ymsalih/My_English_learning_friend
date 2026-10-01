import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Açık / koyu / sistem modu seçimini yönetir ve cihazda saklar.
///
/// AppColors renkleri statik bir paletten okunduğu için mod değişince bütün
/// ekranlar yeniden çizilir (açık sayfalar dahil, gezinme yığını korunur).
class ThemeController extends ValueNotifier<ThemeMode> with WidgetsBindingObserver {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();
  static const String _prefsKey = 'theme_mode';

  /// Uygulama açılışında (runApp'ten önce) bir kez çağrılır.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      value = ThemeMode.system;
    }
    _applyPalette();
    WidgetsBinding.instance.addObserver(this);
  }

  Brightness get effectiveBrightness => switch (value) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  bool get isDark => effectiveBrightness == Brightness.dark;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    _applyAndRebuild();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {}
  }

  @override
  void didChangePlatformBrightness() {
    if (value == ThemeMode.system) {
      _applyAndRebuild();
      notifyListeners();
    }
  }

  void _applyPalette() {
    final dark = isDark;
    AppColors.palette = dark ? AppPalette.dark : AppPalette.light;
    SystemChrome.setSystemUIOverlayStyle(
      dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );
  }

  void _applyAndRebuild() {
    _applyPalette();
    // Renkleri doğrudan AppColors'tan okuyan widget'lar tema bağımlılığı
    // taşımadığı için hepsi yeniden çizilmeye işaretlenir.
    void markDirty(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markDirty);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(markDirty);
  }
}
