import '../theme/responsive_sizer.dart';
import '../theme/app_typography.dart';

/// Dedicated responsive sizing constants for [TopHeaderBar]
class TopHeaderBarSizes {
  // Scaling Controls
  static final SizeScaleController controller = SizeScaleController();
  static double get scaleFactor => controller.scaleFactor;
  static void increaseScale([double step = 0.05]) => controller.increase(step);
  static void decreaseScale([double step = 0.05]) => controller.decrease(step);
  static void setScale(double factor) => controller.setScale(factor);
  static void resetScale() => controller.reset();
  static double scale(num value) =>
      (value * controller.scaleFactor * AppSizeScaler.globalScaleFactor);

  // Bar Dimensions
  static double get preferredHeight => scale(9.safeH.clamp(68.0, 84.0));
  static double get horizontalPadding => scale(2.safeW.clamp(6.0, 12.0));
  static double get bottomPadding => scale(1.safeH.clamp(6.0, 10.0));

  // Logo
  static double get logoSize => scale(8.5.safeW.clamp(28.0, 40.0));
  static double get logoRadius => scale(2.6.safeW.clamp(8.0, 14.0));
  static double get logoIconSize => scale(5.safeW.clamp(18.0, 24.0));

  // Spacing
  static double get spacingXs => scale(1.2.safeW.clamp(4.0, 8.0));
  static double get spacingSm => scale(1.6.safeW.clamp(6.0, 10.0));

  // Language Switcher
  static double get langButtonHeight => scale(4.2.safeH.clamp(30.0, 40.0));
  static double get langButtonPaddingH => scale(2.safeW.clamp(6.0, 12.0));
  static double get langButtonRadius => scale(5.safeW.clamp(16.0, 24.0));

  // Stat Badges
  static double get badgeHeight => scale(4.2.safeH.clamp(30.0, 40.0));
  static double get badgePaddingH => scale(1.8.safeW.clamp(5.0, 10.0));
  static double get badgeRadius => scale(4.5.safeW.clamp(14.0, 22.0));
  static double get badgeIconSize => scale(4.5.safeW.clamp(15.0, 20.0));
  static double get badgeSpacing => scale(1.safeW.clamp(3.0, 6.0));

  // Avatar & Level
  static double get avatarSize => scale(9.5.safeW.clamp(34.0, 44.0));
  static double get avatarIconSize => scale(5.5.safeW.clamp(18.0, 26.0));
  static double get avatarBorderWidth => scale(2.0);
  static double get levelPillRadius => scale(2.5.safeW.clamp(8.0, 12.0));
  static double get levelPillPaddingH => scale(1.4.safeW.clamp(4.0, 8.0));
  static double get levelPillPaddingV => scale(0.3.safeH.clamp(1.5, 4.0));

  // User BottomSheet Modal
  static double get modalPadding => scale(5.5.safeW.clamp(18.0, 28.0));
  static double get modalHandleWidth => scale(10.safeW.clamp(36.0, 48.0));
  static double get modalHandleHeight => scale(0.6.safeH.clamp(3.5, 6.0));
  static double get modalAvatarRadius => scale(7.safeW.clamp(24.0, 34.0));
  static double get modalAvatarIconSize => scale(8.safeW.clamp(28.0, 38.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 16sp (app / modal title) -> 14sp (modal option) -> 12sp (badge / lang / modal sub) -> 10sp (subtitles / option sub) -> 8.5sp (level pill)
  static double get appTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get appSubtitleFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get langButtonFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 14.0));
  static double get badgeValueFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 14.0));
  static double get levelPillFontSize => scale((8.5 + AppTypography.fontDelta).safeSp.clamp(7.5, 11.5));
  static double get modalTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get modalSubtitleFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 14.0));
  static double get modalOptionTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 16.0));
  static double get modalOptionSubFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
}
