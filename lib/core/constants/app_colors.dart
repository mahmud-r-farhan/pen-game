import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark AMOLED Core Palette
  static const Color background = Color(0xFF0D0E15);
  static const Color surface = Color(0xFF161824);
  static const Color surfaceLight = Color(0xFF212435);
  static const Color surfaceHover = Color(0xFF2C3047);

  // Vibrant Accents & Gradients
  static const Color primary = Color(0xFF7C4DFF); // Royal Electric Violet
  static const Color primaryAccent = Color(0xFFB388FF);
  static const Color secondary = Color(0xFF00E5FF); // Electric Cyan
  static const Color tertiary = Color(0xFFFF4081); // Neon Pink
  static const Color liveBadge = Color(0xFFFF9100); // Amber Orange

  // Glass & Overlays
  static const Color glassFill = Color(0x331C1E30);
  static const Color glassBorder = Color(0x2EFFFFFF);
  static const Color glassHighlight = Color(0x4DFFFFFF);

  // Status & Text
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFFA0A5C0);
  static const Color textMuted = Color(0xFF6B728E);
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF4081), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xCC1A1C29), Color(0xE612131D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient liveBadgeGradient = LinearGradient(
    colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
