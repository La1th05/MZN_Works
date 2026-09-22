import 'package:flutter_test/flutter_test.dart';
import 'package:tamkeen_app/core/theme/app_screen_sizes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppTypography.resetFontDelta();
    AppSizeScaler.reset();
    LoginSizes.resetScale();
    TopHeaderBarSizes.resetScale();
    AppNavBarSizes.resetScale();
    AdventureMapSizes.resetScale();
    MathLabSizes.resetScale();
    ReadingArenaSizes.resetScale();
    GuardianDashboardSizes.resetScale();
    TrophyRoomSizes.resetScale();
  });

  tearDown(() {
    AppTypography.setFontDelta(5.0);
    AppSizeScaler.reset();
    LoginSizes.resetScale();
    TopHeaderBarSizes.resetScale();
    AppNavBarSizes.resetScale();
    AdventureMapSizes.resetScale();
    MathLabSizes.resetScale();
    ReadingArenaSizes.resetScale();
    GuardianDashboardSizes.resetScale();
    TrophyRoomSizes.resetScale();
  });

  group('AppSizeScaler Global Engine Tests', () {
    test('Default scale is 1.0', () {
      expect(AppSizeScaler.globalScaleFactor, 1.0);
      expect(scaleSize(100), 100.0);
      expect(50.scaled, 50.0);
    });

    test('Increase and decrease scale', () {
      AppSizeScaler.increase(0.2);
      expect(AppSizeScaler.globalScaleFactor, closeTo(1.2, 0.001));
      expect(scaleSize(100), closeTo(120.0, 0.001));

      AppSizeScaler.decrease(0.4);
      expect(AppSizeScaler.globalScaleFactor, closeTo(0.8, 0.001));
      expect(scaleSize(100), closeTo(80.0, 0.001));

      AppSizeScaler.reset();
      expect(AppSizeScaler.globalScaleFactor, 1.0);
    });

    test('Scale factor clamped between min and max bounds', () {
      AppSizeScaler.setScale(10.0);
      expect(AppSizeScaler.globalScaleFactor, 3.0);

      AppSizeScaler.setScale(0.1);
      expect(AppSizeScaler.globalScaleFactor, 0.5);
    });
  });

  group('Per-Screen Size Class Scaling Integration Tests', () {
    test('LoginSizes local scaling operates independently and cleanly', () {
      final baseLogo = LoginSizes.logoSize;
      expect(LoginSizes.scaleFactor, 1.0);

      LoginSizes.increaseScale(0.2); // 1.2
      expect(LoginSizes.logoSize, closeTo(baseLogo * 1.2, 0.01));

      LoginSizes.decreaseScale(0.4); // 0.8
      expect(LoginSizes.logoSize, closeTo(baseLogo * 0.8, 0.01));

      LoginSizes.resetScale();
      expect(LoginSizes.logoSize, closeTo(baseLogo, 0.01));
    });

    test('Global scale and local class scale multiply seamlessly', () {
      final baseButtonHeight = LoginSizes.buttonHeight;

      AppSizeScaler.setScale(1.1);
      LoginSizes.setScale(1.2);

      // Total scale = 1.1 * 1.2 = 1.32
      expect(LoginSizes.buttonHeight, closeTo(baseButtonHeight * 1.32, 0.01));
    });

    test('All size classes respond to scale adjustments', () {
      final baseTopBar = TopHeaderBarSizes.preferredHeight;
      TopHeaderBarSizes.increaseScale(0.1);
      expect(TopHeaderBarSizes.preferredHeight, closeTo(baseTopBar * 1.1, 0.01));

      final baseNavBar = AppNavBarSizes.iconSize;
      AppNavBarSizes.increaseScale(0.1);
      expect(AppNavBarSizes.iconSize, closeTo(baseNavBar * 1.1, 0.01));

      final baseAdvMap = AdventureMapSizes.activeNodeSize;
      AdventureMapSizes.increaseScale(0.1);
      expect(AdventureMapSizes.activeNodeSize, closeTo(baseAdvMap * 1.1, 0.01));

      final baseMath = MathLabSizes.canvasHeight;
      MathLabSizes.increaseScale(0.1);
      expect(MathLabSizes.canvasHeight, closeTo(baseMath * 1.1, 0.01));

      final baseReading = ReadingArenaSizes.micButtonSize;
      ReadingArenaSizes.increaseScale(0.1);
      expect(ReadingArenaSizes.micButtonSize, closeTo(baseReading * 1.1, 0.01));

      final baseGuardian = GuardianDashboardSizes.headerIconBoxSize;
      GuardianDashboardSizes.increaseScale(0.1);
      expect(GuardianDashboardSizes.headerIconBoxSize, closeTo(baseGuardian * 1.1, 0.01));

      final baseTrophy = TrophyRoomSizes.chestHeight;
      TrophyRoomSizes.increaseScale(0.1);
      expect(TrophyRoomSizes.chestHeight, closeTo(baseTrophy * 1.1, 0.01));
    });
  });

  group('AppTypography Font Scaling Tests', () {
    test('Font delta increases and applies to text styles', () {
      AppTypography.resetFontDelta();
      expect(AppTypography.fontDelta, 0.0);

      AppTypography.increaseFontDelta(5.0);
      expect(AppTypography.fontDelta, 5.0);

      final style = AppTypography.headlineSm();
      // Base is 14.5, with +5 it should be 19.5 (or .sp in Sizer)
      expect(style.fontSize, isNotNull);
      expect(style.fontSize!, greaterThan(14.5));

      AppTypography.decreaseFontDelta(2.0);
      expect(AppTypography.fontDelta, 3.0);
    });
  });
}
