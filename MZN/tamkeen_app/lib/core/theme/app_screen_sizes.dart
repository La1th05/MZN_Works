// Centralized Export for all Screen & Widget Responsive Sizer Classes
export 'responsive_sizer.dart';
export 'app_typography.dart';
export '../widgets/top_header_bar_sizes.dart';
export '../widgets/app_nav_bar_sizes.dart';
export '../services/intro_tour_sizes.dart';
export '../../features/auth/presentation/login_sizes.dart';
export '../../features/adventure_map/presentation/adventure_map_sizes.dart';
export '../../features/dyscalculia_math/presentation/math_lab_sizes.dart';
export '../../features/dyslexia_reading/presentation/reading_arena_sizes.dart';
export '../../features/guardian_dashboard/presentation/guardian_dashboard_sizes.dart';
export '../../features/trophies_skill_tree/presentation/trophy_room_sizes.dart';

import 'responsive_sizer.dart';
import 'app_typography.dart';
import '../widgets/top_header_bar_sizes.dart';
import '../widgets/app_nav_bar_sizes.dart';
import '../services/intro_tour_sizes.dart';
import '../../features/auth/presentation/login_sizes.dart';
import '../../features/adventure_map/presentation/adventure_map_sizes.dart';
import '../../features/dyscalculia_math/presentation/math_lab_sizes.dart';
import '../../features/dyslexia_reading/presentation/reading_arena_sizes.dart';
import '../../features/guardian_dashboard/presentation/guardian_dashboard_sizes.dart';
import '../../features/trophies_skill_tree/presentation/trophy_room_sizes.dart';

/// Central Unified Class aggregating all Page-Specific Sizes and Typography
/// with Global Scale and Font Delta Controls.
class AppScreenSizes {
  // Page-Specific Delegators
  static TopHeaderBarSizes get topHeader => TopHeaderBarSizes();
  static AppNavBarSizes get navBar => AppNavBarSizes();
  static LoginSizes get login => LoginSizes();
  static AdventureMapSizes get adventure => AdventureMapSizes();
  static ReadingArenaSizes get reading => ReadingArenaSizes();
  static MathLabSizes get math => MathLabSizes();
  static GuardianDashboardSizes get guardian => GuardianDashboardSizes();
  static TrophyRoomSizes get trophy => TrophyRoomSizes();
  static IntroTourSizes get tour => IntroTourSizes();

  // App-wide Typography / Font Scaling Controls
  static double get fontDelta => AppTypography.fontDelta;
  static void increaseFontSize([double delta = 1.0]) => AppTypography.increaseFontDelta(delta);
  static void decreaseFontSize([double delta = 1.0]) => AppTypography.decreaseFontDelta(delta);
  static void setFontDelta(double delta) => AppTypography.setFontDelta(delta);
  static void resetFontSize() => AppTypography.resetFontDelta();

  // App-wide Size Scaling Controls
  static double get globalScaleFactor => AppSizeScaler.globalScaleFactor;
  static void increaseGlobalScale([double step = 0.05]) => AppSizeScaler.increase(step);
  static void decreaseGlobalScale([double step = 0.05]) => AppSizeScaler.decrease(step);
  static void setGlobalScale(double factor) => AppSizeScaler.setScale(factor);
  static void resetGlobalScale() => AppSizeScaler.reset();

  // Universal helper for scalable font size using Sizer & fontDelta
  static double scaleFont(double baseSize) => AppTypography.scale(baseSize);

  // Universal helper for scalable layout dimensions
  static double scaleDimension(num value) => scaleSize(value);
}
