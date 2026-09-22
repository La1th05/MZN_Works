import '../theme/responsive_sizer.dart';
import '../theme/app_typography.dart';

/// Dedicated responsive sizing constants for [IntroTourService]
class IntroTourSizes {
  // Scaling Controls
  static final SizeScaleController controller = SizeScaleController();
  static double get scaleFactor => controller.scaleFactor;
  static void increaseScale([double step = 0.05]) => controller.increase(step);
  static void decreaseScale([double step = 0.05]) => controller.decrease(step);
  static void setScale(double factor) => controller.setScale(factor);
  static void resetScale() => controller.reset();
  static double scale(num value) =>
      (value * controller.scaleFactor * AppSizeScaler.globalScaleFactor);

  // Card Structure & Dimensions
  static double get cardMaxWidth => scale(90.safeW.clamp(320.0, 440.0));
  static double get cardRadius => scale(6.safeW.clamp(20.0, 26.0));
  static double get cardInnerRadius => scale(5.5.safeW.clamp(18.0, 24.0));
  static double get cardBorderWidth => scale(2.0);
  static double get cardMarginH => scale(4.safeW.clamp(12.0, 20.0));
  static double get cardMarginV => scale(2.5.safeH.clamp(16.0, 28.0));

  // Header Banner
  static double get headerPaddingH => scale(4.5.safeW.clamp(14.0, 20.0));
  static double get headerPaddingV => scale(1.6.safeH.clamp(10.0, 16.0));
  static double get iconBoxSize => scale(11.safeW.clamp(38.0, 48.0));
  static double get iconBoxRadius => scale(3.5.safeW.clamp(12.0, 16.0));
  static double get iconSize => scale(6.safeW.clamp(20.0, 26.0));
  static double get stepBadgePaddingH => scale(2.safeW.clamp(6.0, 10.0));
  static double get stepBadgePaddingV => scale(0.4.safeH.clamp(2.0, 4.0));
  static double get stepBadgeRadius => scale(2.safeW.clamp(6.0, 10.0));

  // Body Content
  static double get bodyPadding => scale(4.5.safeW.clamp(14.0, 20.0));
  static double get sectionSpacing => scale(1.6.safeH.clamp(10.0, 16.0));
  static double get miniIconBoxSize => scale(6.safeW.clamp(20.0, 26.0));
  static double get miniIconBoxRadius => scale(2.safeW.clamp(6.0, 9.0));
  static double get miniIconSize => scale(4.safeW.clamp(14.0, 18.0));
  static double get symbolBoxPadding => scale(3.safeW.clamp(10.0, 14.0));
  static double get symbolBoxRadius => scale(3.5.safeW.clamp(12.0, 16.0));

  // Footer & Navigation Buttons
  static double get footerPaddingH => scale(4.safeW.clamp(12.0, 18.0));
  static double get footerPaddingV => scale(1.4.safeH.clamp(10.0, 14.0));
  static double get buttonRadius => scale(3.safeW.clamp(10.0, 14.0));
  static double get buttonPaddingH => scale(3.5.safeW.clamp(10.0, 16.0));
  static double get buttonPaddingV => scale(1.safeH.clamp(6.0, 10.0));
  static double get buttonIconSize => scale(4.safeW.clamp(14.0, 18.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 16sp (title) -> 14sp (section title) -> 12sp (body / button) -> 10sp (symbol / step counter)
  static double get stepCounterFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get titleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get sectionTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 16.0));
  static double get bodyFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get symbolFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get buttonFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
}
