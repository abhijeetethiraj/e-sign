import 'package:flutter/material.dart';

/// Centralized Color Palette - Light Mode
class AppColors {
  static const primary = Color(0xFFE9203B);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);

  static const foreground = Color(0xFF171717);
  static const mutedForeground = Color(0xFF737373);

  static const secondary = Color(0xFFF5F5F5);
  static const border = Color(0xFFE5E5E5);

  static const success = Color(0xFF22A34B);
  static const warning = Color(0xFFFACC15);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

/// Centralized Color Palette - Dark Mode
class AppColorsDark {
  static const primary = Color(0xFFE9203B); // Bold crimson stays consistent!

  static const background = Color(0xFF0F0F11); // Deep slate dark
  static const surface = Color(0xFF18181B);    // Elevated dark card surface

  static const foreground = Color(0xFFF4F4F5); // Crisp off-white text
  static const mutedForeground = Color(0xFFA1A1AA); // Subtle muted gray

  static const secondary = Color(0xFF27272A);  // Card details / chips
  static const border = Color(0xFF2E2E33);     // Subtle dark border

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFFACC15);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

/// AppTheme configuration providing light and dark ThemeData and dynamic helpers
class AppTheme {
  // Constant primary brand colors
  static const Color primaryBlue = AppColors.primary;
  static const Color secondaryBlue = AppColors.primary;

  // Static constants for backwards-compatibility across the app
  static const Color backgroundLight = AppColors.background;
  static const Color scaffoldBg = AppColors.background;
  static const Color cardBackground = AppColors.surface;

  static const Color textDark = AppColors.foreground;
  static const Color textMuted = AppColors.mutedForeground;
  static const Color borderLight = AppColors.border;
  static const Color softBlueBackground = AppColors.secondary;

  static const Color badgeReadyBg = AppColors.secondary;
  static const Color badgeReadyText = AppColors.foreground;
  static const Color badgeSignedBg = Color(0xFFE8F5E9);
  static const Color badgeSignedText = AppColors.success;

  // ---------------------------------------------------------------------------
  // CONTEXT-AWARE DYNAMIC HELPERS
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldColor(BuildContext context) =>
      isDark(context) ? AppColorsDark.background : AppColors.background;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? AppColorsDark.surface : AppColors.surface;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColorsDark.foreground : AppColors.foreground;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? AppColorsDark.mutedForeground : AppColors.mutedForeground;

  static Color borderColor(BuildContext context) =>
      isDark(context) ? AppColorsDark.border : AppColors.border;

  static Color secondaryBg(BuildContext context) =>
      isDark(context) ? AppColorsDark.secondary : AppColors.secondary;

  static Color badgeReadyBgDynamic(BuildContext context) =>
      isDark(context) ? AppColorsDark.secondary : AppColors.secondary;

  static Color badgeReadyTextDynamic(BuildContext context) =>
      isDark(context) ? AppColorsDark.foreground : AppColors.foreground;

  static Color badgeSignedBgDynamic(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF14532D).withValues(alpha: 0.35)
          : const Color(0xFFE8F5E9);

  static Color badgeSignedTextDynamic(BuildContext context) =>
      isDark(context) ? AppColorsDark.success : AppColors.success;

  // ---------------------------------------------------------------------------
  // LIGHT THEME CONFIGURATION
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Color(0xFFFAFAFA),
        surface: AppColors.surface,
        onSurface: AppColors.foreground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.foreground,
        error: AppColors.error,
        onError: Color(0xFFFAFAFA),
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.foreground),
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DARK THEME CONFIGURATION
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        onPrimary: Color(0xFFFAFAFA),
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.foreground,
        secondary: AppColorsDark.secondary,
        onSecondary: AppColorsDark.foreground,
        error: AppColorsDark.error,
        onError: Color(0xFFFAFAFA),
      ),
      scaffoldBackgroundColor: AppColorsDark.background,
      cardColor: AppColorsDark.surface,
      dividerColor: AppColorsDark.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColorsDark.foreground),
        titleTextStyle: TextStyle(
          color: AppColorsDark.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.primary,
          foregroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.primary,
          side: const BorderSide(color: AppColorsDark.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
