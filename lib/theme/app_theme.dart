import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Octopus English renk sistemi.
///
/// Palet logodan ve açılış ekranından türetilmiştir: gece mavisi zemin
/// (açılış gradyanı), ahtapot moru (ana renk), "ENGLISH" yazısının lila-mavisi
/// (ikincil renk) ve göz irisinin altını (yalnızca ödül / premium vurgusu).
/// Renk süs için değil anlam için kullanılır.
class AppColors {
  AppColors._();

  // Zemin — açılış ekranı gradyanıyla aynı.
  static const Color bgTop = Color(0xFF17245C);
  static const Color bg = Color(0xFF0B1540);
  static const Color bgBottom = Color(0xFF050920);

  // Yüzeyler (kartlar, diyaloglar, giriş alanları).
  static const Color surface = Color(0xFF131E54);
  static const Color surfaceHigh = Color(0xFF1B2868);
  static const Color border = Color(0xFF26357A);

  // Marka.
  static const Color primary = Color(0xFF7C5CF5); // ahtapot moru (dolgu)
  static const Color primaryLight = Color(0xFFA996FF); // koyu zeminde ikon/metin
  static const Color secondary = Color(0xFF9FB2FF); // "ENGLISH" lila-mavisi
  static const Color gold = Color(0xFFF0B847); // iris altını: seri, premium
  static const Color goldSoft = Color(0xFFFFF0B8);

  // Anlamsal.
  static const Color success = Color(0xFF4FD1A5);
  static const Color danger = Color(0xFFFF6B81);

  // Beyaz yazı taşıyan dolgular (buton, bildirim) için koyu tonlar.
  static const Color successFill = Color(0xFF15815F);
  static const Color goldFill = Color(0xFFB27414);
  static const Color dangerFill = Color(0xFFD93F58);

  // Metin.
  static const Color textPrimary = Color(0xFFF4F1FF);
  static const Color textSecondary = Color(0xFFB8C0EA);
  static const Color textMuted = Color(0xFF7D87BD);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bg, bgBottom],
    stops: [0, 0.45, 1],
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
    colors: [Color(0xFFFFD983), gold],
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

  static TextStyle display({double size = 28, Color color = AppColors.textPrimary}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.15);

  static TextStyle heading({double size = 20, Color color = AppColors.textPrimary}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: FontWeight.w600, color: color, height: 1.2);

  static const TextStyle body = TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4);

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.bg,
      tertiary: AppColors.gold,
      onTertiary: AppColors.bg,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
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
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppText.heading(size: 19),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
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
          side: const BorderSide(color: AppColors.border, width: 1.5),
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
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: AppText.heading(size: 20),
        contentTextStyle: AppText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
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
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
      tabBarTheme: const TabBarThemeData(
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
