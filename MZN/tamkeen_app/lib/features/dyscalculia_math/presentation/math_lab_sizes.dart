import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [MathEquationLabScreen]
class MathLabSizes {
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

  // Cards
  static double get cardPadding => scale(4.safeW.clamp(12.0, 18.0));
  static double get cardRadius => scale(5.5.safeW.clamp(18.0, 26.0));

  // Spacings
  static double get spacingSm => scale(1.safeH.clamp(8.0, 12.0));
  static double get spacingMd => scale(1.8.safeH.clamp(14.0, 20.0));
  static double get spacingLg => scale(2.4.safeH.clamp(18.0, 26.0));

  // Zen Header
  static double get headerBadgePaddingH => scale(2.5.safeW.clamp(8.0, 14.0));
  static double get headerBadgePaddingV => scale(0.8.safeH.clamp(4.0, 8.0));
  static double get headerIconSize => scale(4.safeW.clamp(14.0, 18.0));
  static double get progressBarHeight => scale(1.safeH.clamp(6.0, 10.0));

  // Manipulatives
  static double get cubeSize => scale(7.5.safeW.clamp(26.0, 36.0));
  static double get rodHeight => scale(8.5.safeH.clamp(60.0, 85.0));
  static double get rodWidth => scale(5.5.safeW.clamp(20.0, 30.0));

  // Interactive Drawing Canvas
  static double get canvasHeight => scale(28.safeH.clamp(210.0, 290.0));
  static double get canvasRadius => scale(5.5.safeW.clamp(18.0, 26.0));
  static double get toolButtonSize => scale(10.safeW.clamp(36.0, 46.0));
  static double get toolIconSize => scale(5.safeW.clamp(18.0, 24.0));

  // Keypad
  static double get keypadKeyHeight => scale(7.safeH.clamp(50.0, 66.0));
  static double get keypadKeyRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get keypadFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(16.0, 26.0));

  // Action Buttons
  static double get checkButtonHeight => scale(7.safeH.clamp(50.0, 60.0));
  static double get calmBreakHeight => scale(6.safeH.clamp(44.0, 52.0));

  // Drawing Accuracy Gauge & Precision Indicators
  static double get accuracyGaugePaddingH => scale(3.5.safeW.clamp(10.0, 16.0));
  static double get accuracyGaugePaddingV => scale(1.2.safeH.clamp(6.0, 10.0));
  static double get accuracyGaugeRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get accuracyIndicatorHeight => scale(0.8.safeH.clamp(5.0, 8.0));
  static double get accuracyBadgeRadius => scale(2.5.safeW.clamp(8.0, 12.0));
  static double get accuracyIconSize => scale(4.5.safeW.clamp(14.0, 18.0));
  static double get precisionDialogRadius => scale(6.safeW.clamp(18.0, 26.0));
  static double get precisionDialogPadding => scale(4.5.safeW.clamp(14.0, 22.0));
  static double get spacingXs => scale(0.6.safeW.clamp(2.0, 4.0));
  static double get spacingInlineSm => scale(1.2.safeW.clamp(4.0, 8.0));
  static double get spacingInlineMd => scale(2.safeW.clamp(6.0, 10.0));

  // Equation Number Boxes (Dynamic Expanding)
  static double get equationBoxMinWidth => scale(13.5.safeW.clamp(48.0, 58.0));
  static double get equationBoxHeight => scale(6.2.safeH.clamp(48.0, 56.0));
  static double get equationBoxPaddingH => scale(3.0.safeW.clamp(10.0, 16.0));
  static double get equationBoxPaddingV => scale(0.8.safeH.clamp(4.0, 8.0));
  static double get equationBoxRadius => scale(4.5.safeW.clamp(14.0, 18.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 18sp (equation / numbers) -> 16sp (keypad / header) -> 12sp (hint) -> 10sp (badge)
  static double get equationFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 22.0));
  static double get equationResultFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 22.0));
  static double get hintFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get headerTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get badgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get ghostDigitFontSize => scale(90.0);
}
