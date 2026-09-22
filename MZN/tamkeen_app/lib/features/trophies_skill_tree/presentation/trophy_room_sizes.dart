import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [TrophyRoomScreen]
class TrophyRoomSizes {
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
  static double get spacingInlineSm => scale(1.2.safeW.clamp(4.0, 8.0));

  // Avatar & Profile
  static double get avatarSize => scale(19.safeW.clamp(68.0, 86.0));
  static double get avatarIconSize => scale(10.safeW.clamp(36.0, 48.0));

  // Tab Selector
  static double get tabHeight => scale(5.2.safeH.clamp(40.0, 50.0));
  static double get tabRadius => scale(4.safeW.clamp(12.0, 18.0));

  // Skill Constellation Tile
  static double get skillTileHeight => scale(16.safeH.clamp(115.0, 145.0));
  static double get skillIconBoxSize => scale(11.5.safeW.clamp(40.0, 52.0));
  static double get skillIconSize => scale(6.safeW.clamp(22.0, 28.0));

  // Chest
  static double get chestHeight => scale(17.safeH.clamp(130.0, 170.0));
  static double get chestButtonHeight => scale(6.5.safeH.clamp(46.0, 56.0));

  // Activity Feed & Logs Icons
  static double get activityIconSize => scale(5.2.safeW.clamp(18.0, 24.0));
  static double get activityItemIconBoxSize => scale(10.5.safeW.clamp(36.0, 44.0));
  static double get activityItemIconSize => scale(5.5.safeW.clamp(18.0, 24.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 22sp (hero title) -> 16sp (card title) -> 14sp (activity title) -> 12sp (tab) -> 10sp (badge / caption / scores) -> 8.5sp (micro)
  static double get heroTitleFontSize => scale((22.0 + AppTypography.fontDelta).safeSp.clamp(18.0, 28.0));
  static double get cardTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get tabFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 15.0));
  static double get activityTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 18.0));
  static double get activityBadgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get activitySubtitleFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get activityScoreFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get badgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get captionFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get microFontSize => scale((8.5 + AppTypography.fontDelta).safeSp.clamp(7.5, 11.5));
}
