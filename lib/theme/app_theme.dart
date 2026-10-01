import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bir tema modunun renk paleti.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bgTop,
    required this.bg,
    required this.bgBottom,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.primaryLight,
    required this.secondary,
    required this.gold,
    required this.success,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Brightness brightness;
  final Color bgTop, bg, bgBottom, surface, surfaceHigh, border;
  final Color primaryLight, secondary, gold, success, danger;
  final Color textPrimary, textSecondary, textMuted;

  /// Koyu mod: açılış ekranının gece mavisi.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bgTop: Color(0xFF17245C),
    bg: Color(0xFF0B1540),
    bgBottom: Color(0xFF050920),
    surface: Color(0xFF131E54),
    surfaceHigh: Color(0xFF1B2868),
    border: Color(0xFF26357A),
    primaryLight: Color(0xFFA996FF),
    secondary: Color(0xFF9FB2FF),
    gold: Color(0xFFF0B847),
    success: Color(0xFF4FD1A5),
    danger: Color(0xFFFF6B81),
    textPrimary: Color(0xFFF4F1FF),
    textSecondary: Color(0xFFB8C0EA),
    textMuted: Color(0xFF7D87BD),
  );

  /// Açık mod: lavanta tonlu zemin, beyaz kartlar. Vurgu renkleri açık
  /// zeminde okunabilir koyu tonlardadır.
  static const light = AppPalette(
    brightness: Brightness.light,
    bgTop: Color(0xFFF1EEFF),
    bg: Color(0xFFF7F6FD),
    bgBottom: Color(0xFFEFF1FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFECFB),
    border: Color(0xFFE1DEF2),
    primaryLight: Color(0xFF5F43E0),
    secondary: Color(0xFF4660D4),
    gold: Color(0xFFB7790E),
    success: Color(0xFF0F8A62),
    danger: Color(0xFFD0364F),
    textPrimary: Color(0xFF17133A),
    textSecondary: Color(0xFF4B4870),
    textMuted: Color(0xFF85839F),
  );
}

/// Octopus English renk sistemi.
///
/// Palet logodan ve açılış ekranından türetilmiştir: gece mavisi zemin
/// (açılış gradyanı), ahtapot moru (ana renk), "ENGLISH" yazısının lila-mavisi
/// (ikincil renk) ve göz irisinin altını (yalnızca ödül / premium vurgusu).
/// Renk süs için değil anlam için kullanılır.
///
/// Moda bağlı renkler o anki paletten okunur ([palette], ThemeController
/// tarafından ayarlanır); her iki modda aynı olan marka dolguları sabittir.
class AppColors {
  AppColors._();

  static AppPalette palette = AppPalette.dark;
  static bool get isDark => palette.brightness == Brightness.dark;

  // Zemin.
  static Color get bgTop => palette.bgTop;
  static Color get bg => palette.bg;
  static Color get bgBottom => palette.bgBottom;

  // Yüzeyler (kartlar, diyaloglar, giriş alanları).
  static Color get surface => palette.surface;
  static Color get surfaceHigh => palette.surfaceHigh;
  static Color get border => palette.border;

  // Marka.
  static const Color primary = Color(0xFF7C5CF5); // ahtapot moru (dolgu)
  static Color get primaryLight => palette.primaryLight; // ikon/metin vurgusu
  static Color get secondary => palette.secondary; // "ENGLISH" lila-mavisi
  static Color get gold => palette.gold; // iris altını: seri, premium
  static const Color goldSoft = Color(0xFFFFF0B8);

  // Anlamsal.
  static Color get success => palette.success;
  static Color get danger => palette.danger;

  // Beyaz yazı taşıyan dolgular (buton, bildirim) için koyu tonlar.
  static const Color successFill = Color(0xFF15815F);
  static const Color goldFill = Color(0xFFB27414);
  static const Color dangerFill = Color(0xFFD93F58);

  // Metin.
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;

  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgTop, bg, bgBottom],
        stops: const [0, 0.45, 1],
      );

  /// Ana eylem gradyanı: ahtapot moru → "ENGLISH" lila-mavisi.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D4DF0), Color(0xFF8E7BFF), Color(0xFF9FB2FF)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD983), Color(0xFFF0B847)],
  );
}

/// Boşluk ve köşe ölçüleri: tüm ekranlarda aynı ritim.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  static const double page = 20; // ekran kenar boşluğu
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

/// Başlıklar markanın Fredoka yazı tipiyle (uygulamaya gömülü), gövde metni
/// okunabilirlik için sistem yazı tipiyle.
class AppText {
  AppText._();

  static TextStyle display({double size = 28, Color? color}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary, height: 1.15);

  static TextStyle heading({double size = 20, Color? color}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary, height: 1.2);

  static TextStyle get body => TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4);

  static TextStyle get caption => TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static TextStyle get overline => TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => build(AppPalette.dark);
  static ThemeData get light => build(AppPalette.light);

  /// [palette] için tema. Çağrılmadan önce AppColors.palette da ayarlanmış
  /// olmalıdır (bileşen temaları AppColors'tan okur).
  static ThemeData build(AppPalette palette) {
    final previous = AppColors.palette;
    AppColors.palette = palette;
    try {
      return _build(palette);
    } finally {
      AppColors.palette = previous;
    }
  }

  static ThemeData _build(AppPalette palette) {
    final isDark = palette.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: isDark ? AppColors.bg : Colors.white,
      tertiary: AppColors.gold,
      onTertiary: isDark ? AppColors.bg : Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, brightness: palette.brightness, colorScheme: scheme);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppText.heading(size: 19),
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: AppColors.border, width: 1.5),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: TextStyle(color: AppColors.textMuted),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: AppText.heading(size: 20),
        contentTextStyle: AppText.body,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceHigh,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.primaryLight,
        inactiveTrackColor: AppColors.surfaceHigh,
        thumbColor: Colors.white,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primaryLight,
        dividerColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
