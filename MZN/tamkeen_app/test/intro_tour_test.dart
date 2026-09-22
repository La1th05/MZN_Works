import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamkeen_app/core/services/intro_tour_service.dart';
import 'package:tamkeen_app/core/services/intro_tour_sizes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IntroTourService Comprehensive Tests', () {
    test('Default tour status is uncompleted for fresh installation', () async {
      final completed = await IntroTourService.hasCompletedTour();
      expect(completed, false);
    });

    test('Default tour status is uncompleted for new profile ID', () async {
      final completed = await IntroTourService.hasCompletedTour('profile_abc_123');
      expect(completed, false);
    });

    test('Marking tour completed saves globally and for current profile', () async {
      await IntroTourService.markTourCompleted('student_42');

      final globalCompleted = await IntroTourService.hasCompletedTour();
      final profileCompleted = await IntroTourService.hasCompletedTour('student_42');
      final otherProfileCompleted = await IntroTourService.hasCompletedTour('student_99');

      expect(globalCompleted, true);
      expect(profileCompleted, true);
      // Brand new profile should not have completed it
      expect(otherProfileCompleted, false);
    });

    test('Resetting tour preference clears completion status for replay', () async {
      await IntroTourService.markTourCompleted('student_42');
      expect(await IntroTourService.hasCompletedTour('student_42'), true);

      await IntroTourService.resetTourPreference('student_42');
      expect(await IntroTourService.hasCompletedTour('student_42'), false);
    });

    test('Resetting tour preference for specific profile keeps global clean', () async {
      await IntroTourService.markTourCompleted('student_new');
      expect(await IntroTourService.hasCompletedTour('student_new'), true);

      await IntroTourService.resetTourPreferenceForProfile('student_new');
      expect(await IntroTourService.hasCompletedTour('student_new'), false);
    });

    test('Total steps is 9', () {
      expect(IntroTourService.totalSteps, 9);
    });

    test('getOverlayPosition places upper half widgets below target and spans screen width', () {
      const screenSize = Size(390, 844);
      const widgetSize = Size(60, 40);
      const topOffset = Offset(100, 50); // Near header at top of screen

      final pos = IntroTourService.getOverlayPosition(
        size: widgetSize,
        screenSize: screenSize,
        offset: topOffset,
      );

      expect(pos.width, 390.0);
      expect(pos.left, 0.0);
      expect(pos.right, 0.0);
      expect(pos.top, 50 + 40 + 10); // 100
      expect(pos.bottom, isNull);
      expect(pos.crossAxisAlignment, CrossAxisAlignment.center);
    });

    test('getOverlayPosition places lower half widgets above target and spans screen width', () {
      const screenSize = Size(390, 844);
      const widgetSize = Size(60, 50);
      const bottomOffset = Offset(50, 780); // In bottom nav bar

      final pos = IntroTourService.getOverlayPosition(
        size: widgetSize,
        screenSize: screenSize,
        offset: bottomOffset,
      );

      expect(pos.width, 390.0);
      expect(pos.left, 0.0);
      expect(pos.right, 0.0);
      expect(pos.top, isNull);
      expect(pos.bottom, (844 - 780) + 10); // 74.0
      expect(pos.crossAxisAlignment, CrossAxisAlignment.center);
    });

    test('IntroTourSizes responsive tokens scale properly', () {
      expect(IntroTourSizes.cardMaxWidth, greaterThanOrEqualTo(300.0));
      expect(IntroTourSizes.titleFontSize, greaterThan(0));
      expect(IntroTourSizes.bodyFontSize, greaterThan(0));
      expect(IntroTourSizes.symbolFontSize, greaterThan(0));
      expect(IntroTourSizes.stepCounterFontSize, greaterThan(0));
    });
  });
}
