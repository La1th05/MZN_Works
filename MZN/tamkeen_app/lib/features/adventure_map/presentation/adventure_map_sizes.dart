import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [AdventureMapScreen]
class AdventureMapSizes {
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

  // Journey Card Avatar & Speaker
  static double get avatarSize => scale(12.safeW.clamp(42.0, 54.0));
  static double get avatarIconSize => scale(7.safeW.clamp(24.0, 32.0));
  static double get speakerBoxSize => scale(9.safeW.clamp(32.0, 42.0));
  static double get speakerIconSize => scale(5.safeW.clamp(18.0, 24.0));

  // Mascot Card
  static double get mascotSize => scale(11.5.safeW.clamp(40.0, 50.0));
  static double get speechBubblePadding => scale(3.safeW.clamp(10.0, 16.0));

  // Realm Banner
  static double get bannerPaddingH => scale(4.safeW.clamp(12.0, 18.0));
  static double get bannerPaddingV => scale(1.2.safeH.clamp(8.0, 14.0));
  static double get bannerRadius => scale(5.safeW.clamp(16.0, 22.0));
  static double get bannerIconSize => scale(5.5.safeW.clamp(18.0, 26.0));

  // Path Nodes
  static double get activeNodeSize => scale(18.safeW.clamp(64.0, 80.0));
  static double get normalNodeSize => scale(15.5.safeW.clamp(56.0, 70.0));
  static double get nodeIconSize => scale(7.5.safeW.clamp(26.0, 34.0));
  static double get starIconSize => scale(4.5.safeW.clamp(15.0, 22.0));

  // Mini Challenges & Chest
  static double get challengeIconBoxSize => scale(10.5.safeW.clamp(38.0, 48.0));
  static double get challengeIconSize => scale(5.5.safeW.clamp(18.0, 26.0));
  static double get chestIconSize => scale(10.safeW.clamp(36.0, 48.0));
  static double get chestButtonHeight => scale(5.5.safeH.clamp(40.0, 50.0));

  // Accuracy Badges
  static double get accuracyBadgePaddingH => scale(2.5.safeW.clamp(6.0, 10.0));
  static double get accuracyBadgePaddingV => scale(0.6.safeH.clamp(2.0, 5.0));
  static double get accuracyBadgeRadius => scale(3.safeW.clamp(8.0, 12.0));
  static double get accuracyBadgeIconSize => scale(3.5.safeW.clamp(11.0, 15.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 18sp (realm title) -> 16sp (banner title) -> 14sp (card title / button) -> 12sp (node / speech / emoji) -> 10sp (badge / caption)
  static double get realmTitleFontSize => scale((18.0 + AppTypography.fontDelta).safeSp.clamp(15.0, 24.0));
  static double get bannerTitleFontSize => scale((16.0 + AppTypography.fontDelta).safeSp.clamp(14.0, 20.0));
  static double get cardTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 18.0));
  static double get buttonFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 17.0));
  static double get nodeLabelFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get speechFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get emojiFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.0, 15.0));
  static double get badgeFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get captionFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
}
