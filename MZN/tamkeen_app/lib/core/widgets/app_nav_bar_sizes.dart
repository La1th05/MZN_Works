import '../theme/responsive_sizer.dart';
import '../theme/app_typography.dart';

/// Dedicated responsive sizing constants for [AppNavBar]
class AppNavBarSizes {
  // Scaling Controls
  static final SizeScaleController controller = SizeScaleController();
  static double get scaleFactor => controller.scaleFactor;
  static void increaseScale([double step = 0.05]) => controller.increase(step);
  static void decreaseScale([double step = 0.05]) => controller.decrease(step);
  static void setScale(double factor) => controller.setScale(factor);
  static void resetScale() => controller.reset();
  static double scale(num value) =>
      (value * controller.scaleFactor * AppSizeScaler.globalScaleFactor);

  static double get paddingTop => scale(1.safeH.clamp(6.0, 10.0));
  static double get paddingHorizontal => scale(2.safeW.clamp(6.0, 12.0));
  static double get itemPaddingV => scale(0.8.safeH.clamp(4.0, 8.0));
  static double get itemRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get iconSize => scale(6.safeW.clamp(20.0, 26.0));
  static double get spacingIconText => scale(0.5.safeH.clamp(3.0, 6.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 10sp (nav bar labels)
  static double get labelFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get activeLabelFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
}
