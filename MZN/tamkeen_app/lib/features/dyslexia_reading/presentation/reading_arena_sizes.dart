import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [ReadingArenaScreen]
class ReadingArenaSizes {
  // Scaling Controls
  static final SizeScaleController controller = SizeScaleController();
  static double get scaleFactor => controller.scaleFactor;
  static void increaseScale([double step = 0.05]) => controller.increase(step);
  static void decreaseScale([double step = 0.05]) => controller.decrease(step);
  static void setScale(double factor) => controller.setScale(factor);
  static void resetScale() => controller.reset();
  static double scale(num value) =>
      (value * controller.scaleFactor * AppSizeScaler.globalScaleFactor);

  // Screen Padding
  static double get screenPaddingH => scale(4.safeW.clamp(12.0, 20.0));
  static double get screenPaddingV => scale(1.5.safeH.clamp(10.0, 18.0));

  // Generic Cards & Containers
  static double get cardPadding => scale(4.5.safeW.clamp(14.0, 22.0));
  static double get cardRadius => scale(5.5.safeW.clamp(18.0, 26.0));
  static double get subCardPadding => scale(3.safeW.clamp(10.0, 16.0));
  static double get subCardRadius => scale(4.safeW.clamp(12.0, 18.0));

  // Spacings
  static double get spacingXs => scale(0.6.safeW.clamp(2.0, 4.0));
  static double get spacingSm => scale(1.safeH.clamp(6.0, 10.0));
  static double get spacingMd => scale(1.8.safeH.clamp(12.0, 18.0));
  static double get spacingLg => scale(2.4.safeH.clamp(16.0, 24.0));
  static double get spacingSection => scale(1.6.safeH.clamp(10.0, 16.0));
  static double get spacingLgSection => scale(2.safeH.clamp(12.0, 18.0));
  static double get spacingInlineSm => scale(1.2.safeW.clamp(4.0, 8.0));
  static double get spacingInlineMd => scale(2.safeW.clamp(6.0, 10.0));
  static double get smallIconSize => scale(4.safeW.clamp(14.0, 18.0));

  // Header Controls
  static double get backButtonSize => scale(10.5.safeW.clamp(38.0, 48.0));
  static double get backIconSize => scale(5.5.safeW.clamp(20.0, 26.0));
  static double get zenToggleSize => scale(9.5.safeW.clamp(34.0, 44.0));
  static double get speedToggleHeight => scale(4.6.safeH.clamp(34.0, 44.0));
  static double get headerStagePillRadius => scale(2.5.safeW.clamp(8.0, 12.0));
  static double get headerTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));

  // Comfort Deck Controls
  static double get comfortDeckPadding => scale(3.safeW.clamp(10.0, 16.0));
  static double get comfortDeckRadius => scale(5.safeW.clamp(16.0, 24.0));
  static double get comfortControlHeight => scale(4.8.safeH.clamp(34.0, 42.0));
  static double get comfortControlRadius => scale(2.8.safeW.clamp(8.0, 12.0));
  static double get comfortIconSize => scale(3.8.safeW.clamp(13.0, 17.0));
  static double get comfortAFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 15.0));
  static double get comfortLabelFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));

  // Audio & Microphone Controls
  static double get micButtonSize => scale(21.safeW.clamp(74.0, 96.0));
  static double get micIconSize => scale(9.5.safeW.clamp(34.0, 46.0));
  static double get listenButtonSize => scale(11.safeW.clamp(40.0, 50.0));
  static double get waveformHeight => scale(4.5.safeH.clamp(30.0, 44.0));

  // Action Buttons
  static double get completeButtonHeight => scale(7.safeH.clamp(50.0, 60.0));
  static double get secondaryButtonHeight => scale(6.safeH.clamp(44.0, 52.0));
  static double get tryAgainButtonHeight => scale(4.6.safeH.clamp(34.0, 40.0));
  static double get continueButtonHeight => scale(6.8.safeH.clamp(50.0, 58.0));

  // Result & Celebration Card
  static double get resultCardPadding => scale(4.5.safeW.clamp(14.0, 22.0));
  static double get resultCardRadius => scale(6.safeW.clamp(20.0, 26.0));
  static double get celebrationEmojiSize => scale(24.0);
  static double get celebrationTitleSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(15.0, 22.0));
  static double get starIconSize => scale(5.5.safeW.clamp(18.0, 24.0));

  // Result Metric Tiles
  static double get metricTilePaddingV => scale(1.2.safeH.clamp(8.0, 12.0));
  static double get metricTilePaddingH => scale(2.safeW.clamp(6.0, 10.0));
  static double get metricTileRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get metricValueFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(15.0, 22.0));
  static double get metricSubtitleFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));

  // Feedback & Discovery Word Tokens
  static double get feedbackPadding => scale(3.safeW.clamp(10.0, 14.0));
  static double get feedbackRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get feedbackIconSize => scale(4.5.safeW.clamp(16.0, 20.0));
  static double get discoveryIconSize => scale(5.safeW.clamp(18.0, 22.0));
  static double get masteredIconSize => scale(4.safeW.clamp(14.0, 18.0));

  // Additional Typography (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 18sp (passage / metric) -> 16sp (header) -> 12sp (comfortA) -> 10sp (badge/caption)
  static double get readingPassageFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 36.0));
  static double get discoveryBadgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get captionFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get badgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
}
