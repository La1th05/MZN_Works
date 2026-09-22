import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [GuardianDashboardScreen]
class GuardianDashboardSizes {
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

  // Header Box
  static double get headerIconBoxSize => scale(11.safeW.clamp(40.0, 50.0));
  static double get headerIconSize => scale(6.safeW.clamp(22.0, 28.0));
  static double get lockBoxSize => scale(9.safeW.clamp(32.0, 42.0));

  // Metric Cards
  static double get metricPadding => scale(3.safeW.clamp(10.0, 16.0));
  static double get metricRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get metricIconSize => scale(6.safeW.clamp(20.0, 28.0));

  // Progress Bar
  static double get progressBarHeight => scale(1.2.safeH.clamp(8.0, 12.0));

  // Insights
  static double get insightIconBoxSize => scale(9.5.safeW.clamp(34.0, 44.0));
  static double get insightIconSize => scale(5.5.safeW.clamp(18.0, 24.0));

  // Logout Card
  static double get logoutButtonHeight => scale(6.safeH.clamp(44.0, 56.0));
  static double get logoutIconSize => scale(5.5.safeW.clamp(20.0, 26.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 18sp (header) -> 16sp (section / metric) -> 14sp (card title) -> 12sp (body) -> 10sp (badge/caption) -> 8.5sp (micro)
  static double get headerTitleFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(15.0, 24.0));
  static double get sectionTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get cardTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 18.0));
  static double get metricValueFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get bodyFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get badgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get captionFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get microFontSize => scale((8.5 + AppTypography.fontDelta).safeSp.clamp(7.5, 11.5));
}
