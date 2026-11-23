// lib/core/constants/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class KolomTheme {
  static const Color darkBackground = AppColors.bgObsidian;
  static const Color cardDark = AppColors.glassSurface;
  static const Color goldAccent = AppColors.goldTiffinCoin;
  static const Color coinAmber = AppColors.goldTiffinCoin;
  static const Color neonCyan = AppColors.cyanSpin;
  static const Color neonGreen = AppColors.emeraldTurn;
  static const Color neonRed = AppColors.crimsonStrike;
  static const Color textMuted = AppColors.slateMuted;

  // Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    double radius = 16,
    Color? borderColor,
    Color? surfaceColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? AppColors.glassSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: 1.0,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

  // Active Player Turn Glowing Border
  static BoxDecoration activeTurnDecoration({required bool isYourTurn, double radius = 16}) {
    final activeColor = isYourTurn ? AppColors.emeraldTurn : AppColors.crimsonStrike;
    return BoxDecoration(
      color: AppColors.glassSurfaceHeavy,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: activeColor,
        width: 1.8,
      ),
      boxShadow: [
        BoxShadow(
          color: activeColor.withValues(alpha: 0.35),
          blurRadius: 14,
          spreadRadius: 1.0,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgObsidian,
      primaryColor: AppColors.goldTiffinCoin,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldTiffinCoin,
        secondary: AppColors.cyanSpin,
        surface: AppColors.glassSurface,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.chalkWhite,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.chalkWhite,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.chalkWhite,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.chalkWhite,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.chalkWhite,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: AppColors.slateMuted,
        ),
      ),
    );
  }

  // Monospace font for coin counters, timers, and strike numbers
  static TextStyle monoNumeric({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    Color color = AppColors.chalkWhite,
  }) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
