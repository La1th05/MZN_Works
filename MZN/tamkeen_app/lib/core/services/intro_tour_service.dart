import 'package:flutter/material.dart';
import 'package:flutter_intro/flutter_intro.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'intro_tour_sizes.dart';

class IntroTourService {
  static const String _tourPrefKey = 'has_completed_intro_tour';
  static const int totalSteps = 9;

  static String _keyFor(String? profileId) {
    if (profileId != null && profileId.isNotEmpty) {
      return '${_tourPrefKey}_$profileId';
    }
    return _tourPrefKey;
  }

  /// Check if user has already completed the onboarding tour for their profile
  static Future<bool> hasCompletedTour([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId != null && profileId.isNotEmpty) {
      final profileVal = prefs.getBool(_keyFor(profileId));
      if (profileVal != null) return profileVal;
      return false; // New profile hasn't completed it!
    }
    return prefs.getBool(_tourPrefKey) ?? false;
  }

  /// Mark the tour as completed for this profile and globally
  static Future<void> markTourCompleted([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourPrefKey, true);
    if (profileId != null && profileId.isNotEmpty) {
      await prefs.setBool(_keyFor(profileId), true);
    }
  }

  /// Reset the tour preference for a specific profile (e.g. for brand new account)
  static Future<void> resetTourPreferenceForProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(profileId));
  }

  /// Reset the tour preference so it can run again
  static Future<void> resetTourPreference([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tourPrefKey);
    if (profileId != null && profileId.isNotEmpty) {
      await prefs.remove(_keyFor(profileId));
    }
  }

  /// Start the intro tour from the given context
  static void startTour(BuildContext context) {
    try {
      final intro = Intro.of(context);
      debugPrint('[IntroTourService] Starting intro tour with reset=true');
      intro.start(reset: true);
    } catch (e, stack) {
      debugPrint('[IntroTourService] Error starting intro tour: $e\n$stack');
    }
  }

  /// Calculates responsive overlay positioning across full screen width with safe vertical offsets
  static OverlayPosition getOverlayPosition({
    required Size size,
    required Size screenSize,
    required Offset offset,
  }) {
    // If target widget is in the top 45% of the screen (e.g. Header), place card below it.
    // If target widget is in the bottom half (e.g. Bottom Navigation), place card above it.
    final isInUpperHalf = offset.dy < (screenSize.height * 0.45);

    if (isInUpperHalf) {
      return OverlayPosition(
        top: offset.dy + size.height + 10,
        left: 0,
        right: 0,
        width: screenSize.width,
        crossAxisAlignment: CrossAxisAlignment.center,
      );
    } else {
      final bottomArea = screenSize.height - offset.dy;
      return OverlayPosition(
        bottom: bottomArea + 10,
        left: 0,
        right: 0,
        width: screenSize.width,
        crossAxisAlignment: CrossAxisAlignment.center,
      );
    }
  }

  /// Build a rich, child-friendly and parent-friendly overlay card for a specific step
  static Widget buildStepCard({
    BuildContext? context,
    required StepWidgetParams params,
    required int order,
    required IconData icon,
    required Color accentColor,
  }) {
    return Consumer<AppState>(
      builder: (cardCtx, state, _) {
        final isAr = state.isArabic;

        final title = state.tr('tour_step_${order}_title');
        final functionText = state.tr('tour_step_${order}_func');
        final symbolText = state.tr('tour_step_${order}_sym');

        final isFirst = order == 1;
        final isLast = order == totalSteps;
        final screenWidth = MediaQuery.of(cardCtx).size.width;
        final screenHeight = MediaQuery.of(cardCtx).size.height;

        return Directionality(
          textDirection: state.textDirection,
          child: Center(
            child: Container(
              width: screenWidth * 0.92,
              constraints: BoxConstraints(maxWidth: IntroTourSizes.cardMaxWidth),
              margin: EdgeInsets.symmetric(
                horizontal: IntroTourSizes.cardMarginH,
                vertical: IntroTourSizes.cardMarginV,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(IntroTourSizes.cardRadius),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: IntroTourSizes.cardBorderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(IntroTourSizes.cardInnerRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: IntroTourSizes.headerPaddingH,
                    vertical: IntroTourSizes.headerPaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    border: Border(
                      bottom: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: IntroTourSizes.iconBoxSize,
                        height: IntroTourSizes.iconBoxSize,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(IntroTourSizes.iconBoxRadius),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: IntroTourSizes.iconSize),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: IntroTourSizes.stepBadgePaddingH,
                                vertical: IntroTourSizes.stepBadgePaddingV,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(IntroTourSizes.stepBadgeRadius),
                              ),
                              child: Text(
                                '${state.tr('tour_step_counter')} $order ${state.tr('tour_of')} $totalSteps',
                                style: AppTypography.labelSm(color: accentColor).copyWith(
                                  fontSize: IntroTourSizes.stepCounterFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              style: AppTypography.headlineSm().copyWith(
                                fontSize: IntroTourSizes.titleFontSize,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Skip Tour Button
                      IconButton(
                        onPressed: () {
                          markTourCompleted(state.currentProfileId);
                          params.onFinish();
                        },
                        icon: const Icon(Icons.close_rounded, color: AppColors.outline),
                        tooltip: state.tr('tour_btn_skip'),
                      ),
                    ],
                  ),
                ),

                // Body: Function & Symbolism (Scrollable with max height constraint to prevent overflow on small screens)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.42,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(IntroTourSizes.bodyPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: How it works
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(IntroTourSizes.miniIconBoxRadius),
                              ),
                              child: Icon(Icons.touch_app_rounded, color: const Color(0xFF2563EB), size: IntroTourSizes.miniIconSize),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.tr('tour_function_title'),
                                    style: AppTypography.labelSm(color: const Color(0xFF1D4ED8)).copyWith(
                                      fontSize: IntroTourSizes.sectionTitleFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    functionText,
                                    style: AppTypography.bodySm(color: AppColors.onSurface).copyWith(
                                      fontSize: IntroTourSizes.bodyFontSize,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: IntroTourSizes.sectionSpacing),

                        // Section 2: What it represents / Symbolism
                        Container(
                          padding: EdgeInsets.all(IntroTourSizes.symbolBoxPadding),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(IntroTourSizes.symbolBoxRadius),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('✨', style: TextStyle(fontSize: IntroTourSizes.bodyFontSize)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.tr('tour_symbol_title'),
                                      style: AppTypography.labelSm(color: const Color(0xFF92400E)).copyWith(
                                        fontSize: IntroTourSizes.sectionTitleFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      symbolText,
                                      style: AppTypography.bodySm(color: const Color(0xFF78350F)).copyWith(
                                        height: 1.4,
                                        fontSize: IntroTourSizes.symbolFontSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: IntroTourSizes.footerPaddingH,
                    vertical: IntroTourSizes.footerPaddingV,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Skip Tour Text Button
                      TextButton(
                        onPressed: () {
                          markTourCompleted(state.currentProfileId);
                          params.onFinish();
                        },
                        child: Text(
                          state.tr('tour_btn_skip'),
                          style: AppTypography.labelSm(color: AppColors.outline).copyWith(
                            fontSize: IntroTourSizes.buttonFontSize,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Prev Button
                      if (!isFirst) ...[
                        OutlinedButton(
                          onPressed: params.onPrev,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onSurface,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(IntroTourSizes.buttonRadius),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: IntroTourSizes.buttonPaddingH,
                              vertical: IntroTourSizes.buttonPaddingV,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAr ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                                size: IntroTourSizes.buttonIconSize,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                state.tr('tour_btn_prev'),
                                style: AppTypography.labelSm().copyWith(
                                  fontSize: IntroTourSizes.buttonFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Next / Finish Button
                      ElevatedButton(
                        onPressed: () {
                          if (isLast) {
                            markTourCompleted(state.currentProfileId);
                            params.onFinish();
                          } else {
                            params.onNext?.call();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLast ? const Color(0xFF16A34A) : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(IntroTourSizes.buttonRadius),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: IntroTourSizes.buttonPaddingH,
                            vertical: IntroTourSizes.buttonPaddingV,
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? state.tr('tour_btn_finish') : state.tr('tour_btn_next'),
                              style: AppTypography.labelSm(color: Colors.white).copyWith(
                                fontSize: IntroTourSizes.buttonFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isLast
                                  ? Icons.check_circle_rounded
                                  : (isAr ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded),
                              size: IntroTourSizes.buttonIconSize,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
}
}
