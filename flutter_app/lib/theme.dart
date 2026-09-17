import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF121214);
  static const card = Color(0xFF18181B);
  static const cardBorder = Color(0xFF27272A);
  static const accent = Color(0xFF60A5FA);
  static const textPrimary = Color(0xFFE4E4E7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const learningColor = Color(0xFFFFC107);
  static const matureColor = Color(0xFF28A745);
  static const unknownColor = Color(0xFF6B7280);
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFDC2626);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: background,
      primary: accent,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardColor: card,
    dividerColor: cardBorder,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
      ),
    ),
  );
}
