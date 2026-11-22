import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.blue,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.grey,
      surfaceContainerHighest: AppColors.chip,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.like,
    ),
    AppColors.background,
  );

  static ThemeData get dark => _build(
    const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: AppColors.ink,
      secondary: Color(0xFF6C8CFF),
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFF9A9A9A),
      surfaceContainerHighest: AppColors.darkChip,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      error: AppColors.like,
    ),
    AppColors.darkBackground,
  );

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(colorScheme: scheme, brightness: scheme.brightness);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusField),
      borderSide: BorderSide(color: c),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.onSurface),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
      ),
    );
  }
}
