import 'package:flutter/material.dart';

/// Design tokens matching Tamkeen Learning Adventure specifications (DESIGN.md)
class AppColors {
  // Primary (Focus Teal)
  static const Color primary = Color(0xFF006A62);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF2EC4B6);
  static const Color onPrimaryContainer = Color(0xFF004C46);
  static const Color primaryShadow = Color(0xFF1E8278);
  static const Color primaryFixed = Color(0xFF70F8E8);
  static const Color onPrimaryFixed = Color(0xFF00201D);

  // Secondary (Warm Coral)
  static const Color secondary = Color(0xFFAE2F34);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFF6B6B);
  static const Color onSecondaryContainer = Color(0xFF6D0010);
  static const Color secondaryShadow = Color(0xFFC74343);
  static const Color secondaryFixed = Color(0xFFFFDAD8);
  static const Color onSecondaryFixed = Color(0xFF410006);

  // Tertiary (Sunny Golden Yellow)
  static const Color tertiary = Color(0xFF785A00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFD5AA43);
  static const Color onTertiaryContainer = Color(0xFF564000);
  static const Color sunnyYellow = Color(0xFFFFD166);
  static const Color yellowShadow = Color(0xFFE2B74B);
  static const Color tertiaryFixed = Color(0xFFFFDF9B);
  static const Color onTertiaryFixed = Color(0xFF251A00);

  // Magic & Discovery Accents
  static const Color periwinkle = Color(0xFF6C5CE7);
  static const Color periwinkleLight = Color(0xFFEBE8FF);

  // Neutral Surfaces & Canvas
  static const Color background = Color(0xFFF9F9FF);
  static const Color onBackground = Color(0xFF0B1C32);
  static const Color surface = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF0B1C32);
  static const Color onSurfaceVariant = Color(0xFF3C4947);
  
  // Containers
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD5E3FF);
  static const Color surfaceDim = Color(0xFFCBDBF9);

  // Borders and Outlines
  static const Color outline = Color(0xFF6C7A77);
  static const Color outlineVariant = Color(0xFFBBCAC6);
  static const Color borderLight = Color(0x1F1D2D44);

  // Gentle Feedback (Non-aggressive)
  static const Color amberGentle = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color errorLight = Color(0xFFFFDAD6);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);
  static const Color error = Color(0xFFBA1A1A);

  // Focus Highlight (Dyslexia text highlight)
  static const Color readingHighlight = Color(0xFFFEF3C7);
  static const Color readingHighlightBorder = Color(0xFFFDE68A);
}
