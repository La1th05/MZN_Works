import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'app_colors.dart';

class AppTypography {
  /// Global adjustment to all typography font sizes across the application.
  static double fontDelta = 0.0;

  /// Increase global font size delta
  static void increaseFontDelta([double delta = 1.0]) => fontDelta += delta;

  /// Decrease global font size delta
  static void decreaseFontDelta([double delta = 1.0]) => fontDelta -= delta;

  /// Set exact font size delta
  static void setFontDelta(double delta) => fontDelta = delta;

  /// Reset font size delta back to 0
  static void resetFontDelta() => fontDelta = 0.0;

  /// Safely converts a base font size value to Scalable Pixels (sp) using Sizer,
  /// including the global fontDelta.
  /// Falls back gracefully to raw font size if Sizer has not yet initialized.
  static double scale(double size) {
    final adjustedSize = (size + fontDelta).clamp(4.0, 96.0);
    try {
      return adjustedSize.sp;
    } catch (_) {
      return adjustedSize;
    }
  }

  static double scaleFontSize(double size) => scale(size);

  static TextStyle getLexend({
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double letterSpacing = 0.02,
    Color color = AppColors.onSurface,
  }) {
    return GoogleFonts.lexend(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle getBody({
    required double fontSize,
    required FontWeight fontWeight,
    double? height = 1.6,
    double letterSpacing = 0.025,
    Color color = AppColors.onSurface,
    bool isDyslexicFont = false,
  }) {
    if (isDyslexicFont) {
      // Neuro-accessible font fallback with enlarged spacing
      return GoogleFonts.readexPro(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: (height ?? 1.6) * 1.15,
        letterSpacing: letterSpacing * 1.5,
        color: color,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // Responsive preset typography using Sizer (.sp) with strict mathematical hierarchy:
  // Major tiers step by 4pt: Display (26) -> HeadlineLg (22) -> HeadlineMd (18)
  // Subsequent tiers step by 2pt: HeadlineSm (16) -> BodyLg (14) -> BodyMd (12) -> BodySm (10) -> Micro (8.5)
  static TextStyle displayLg({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(26.0), fontWeight: FontWeight.w800, height: 1.25, color: color);

  static TextStyle headlineLg({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(22.0), fontWeight: FontWeight.w700, height: 1.3, color: color);

  static TextStyle headlineMd({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(18.0), fontWeight: FontWeight.w700, height: 1.35, color: color);

  static TextStyle headlineSm({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(16.0), fontWeight: FontWeight.w600, height: 1.4, color: color);

  static TextStyle bodyLg({Color color = AppColors.onSurface, bool isDyslexic = false}) =>
      getBody(fontSize: scale(14.0), fontWeight: FontWeight.w500, height: 1.65, color: color, isDyslexicFont: isDyslexic);

  static TextStyle bodyMd({Color color = AppColors.onSurface, bool isDyslexic = false}) =>
      getBody(fontSize: scale(12.0), fontWeight: FontWeight.w500, height: 1.6, color: color, isDyslexicFont: isDyslexic);

  static TextStyle bodySm({Color color = AppColors.onSurfaceVariant, bool isDyslexic = false}) =>
      getBody(fontSize: scale(10.0), fontWeight: FontWeight.w500, height: 1.5, color: color, isDyslexicFont: isDyslexic);

  static TextStyle labelLg({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(14.0), fontWeight: FontWeight.w700, height: 1.3, color: color);

  static TextStyle labelMd({Color color = AppColors.onSurface}) =>
      getLexend(fontSize: scale(12.0), fontWeight: FontWeight.w700, height: 1.3, color: color);

  static TextStyle labelSm({Color color = AppColors.onSurfaceVariant}) =>
      getLexend(fontSize: scale(10.0), fontWeight: FontWeight.w600, height: 1.3, color: color);

  static TextStyle micro({Color color = AppColors.onSurfaceVariant}) =>
      getLexend(fontSize: scale(8.5), fontWeight: FontWeight.w600, height: 1.2, color: color);
}
