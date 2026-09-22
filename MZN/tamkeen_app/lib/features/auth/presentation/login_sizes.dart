import '../../../core/theme/responsive_sizer.dart';
import '../../../core/theme/app_typography.dart';

/// Dedicated responsive sizing constants for [LoginScreen]
class LoginSizes {
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
  static double get screenPaddingH => scale(6.safeW.clamp(18.0, 32.0));
  static double get screenPaddingV => scale(2.5.safeH.clamp(16.0, 28.0));

  // Logo
  static double get logoSize => scale(22.safeW.clamp(72.0, 96.0));
  static double get logoIconSize => scale(10.safeW.clamp(34.0, 48.0));
  static double get logoRadius => scale(5.safeW.clamp(16.0, 24.0));
  static double get logoBorderWidth => scale(2.5);

  // Spacings
  static double get spacingXs => scale(0.5.safeH.clamp(4.0, 8.0));
  static double get spacingSm => scale(1.2.safeH.clamp(8.0, 14.0));
  static double get spacingMd => scale(2.safeH.clamp(12.0, 20.0));
  static double get spacingLg => scale(2.5.safeH.clamp(16.0, 26.0));

  // Language Pill
  static double get langPillPaddingH => scale(3.5.safeW.clamp(10.0, 18.0));
  static double get langPillPaddingV => scale(0.8.safeH.clamp(5.0, 10.0));
  static double get langPillRadius => scale(5.safeW.clamp(16.0, 24.0));
  static double get langPillIconSize => scale(4.safeW.clamp(14.0, 20.0));

  // Switcher (Sign in vs Register)
  static double get switcherPadding => scale(1.safeW.clamp(3.0, 6.0));
  static double get switcherRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get switcherItemPaddingV => scale(1.2.safeH.clamp(8.0, 14.0));
  static double get switcherItemRadius => scale(3.safeW.clamp(10.0, 16.0));

  // Cloud Profiles Card & List
  static double get cardPadding => scale(4.5.safeW.clamp(14.0, 22.0));
  static double get cardRadius => scale(6.safeW.clamp(18.0, 28.0));
  static double get profileItemPadding => scale(3.safeW.clamp(10.0, 16.0));
  static double get profileItemRadius => scale(4.safeW.clamp(12.0, 18.0));
  static double get avatarRadius => scale(5.safeW.clamp(18.0, 24.0));
  static double get avatarIconSize => scale(5.5.safeW.clamp(18.0, 26.0));
  static double get starIconSize => scale(4.5.safeW.clamp(15.0, 22.0));

  // Form Fields & Buttons
  static double get inputRadius => scale(3.5.safeW.clamp(12.0, 16.0));
  static double get buttonHeight => scale(6.8.safeH.clamp(48.0, 58.0));

  // Typography / Font Sizes (Responsive via Sizer and global fontDelta)
  // Stepped Hierarchy: 22sp (title) -> 14sp (button / card title) -> 12sp (subtitle / tab / body) -> 10sp (caption)
  static double get titleFontSize => scale((22.0 + AppTypography.fontDelta).safeSp.clamp(18.0, 26.0));
  static double get subtitleFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get cardTitleFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 17.0));
  static double get bodyFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
  static double get captionFontSize => scale((10.0 + AppTypography.fontDelta).safeSp.clamp(8.5, 12.5));
  static double get buttonFontSize => scale((14.0 + AppTypography.fontDelta).safeSp.clamp(12.0, 17.0));
  static double get tabFontSize => scale((12.0 + AppTypography.fontDelta).safeSp.clamp(10.5, 15.0));
}
