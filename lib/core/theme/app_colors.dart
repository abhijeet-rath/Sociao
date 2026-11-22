import 'package:material_ui/material_ui.dart';

/// Fixed brand colours. Surface/text colours come from the ColorScheme so
/// light and dark themes both work.
class AppColors {
  const AppColors._();

  static const ink = Color(0xFF171717);
  static const background = Color(0xFFFAFAFA);
  static const grey = Color(0xFF8A8A8A);
  static const chip = Color(0xFFF2F2F2);
  static const border = Color(0xFFEDEDED);
  static const blue = Color(0xFF2F55D4);
  static const like = Color(0xFFE53935);

  // Dark theme counterparts.
  static const darkBackground = Color(0xFF0F0F0F);
  static const darkSurface = Color(0xFF1B1B1B);
  static const darkChip = Color(0xFF262626);
  static const darkBorder = Color(0xFF2E2E2E);
}

/// Spacing / radius tokens.
class AppSpacing {
  const AppSpacing._();

  static const page = 20.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const radiusCard = 24.0;
  static const radiusField = 16.0;
  static const radiusPill = 100.0;

  /// Max content width on large screens.
  static const maxContentWidth = 600.0;
}
