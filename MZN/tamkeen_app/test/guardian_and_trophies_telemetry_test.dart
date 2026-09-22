import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamkeen_app/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trophies & Guardian Real Database Telemetry Tests', () {
    late AppState appState;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      appState = AppState();
    });

    test('Badges List includes rich dynamic unlock evaluations', () {
      final badges = appState.badgesList;
      expect(badges.isNotEmpty, isTrue);
      expect(badges.length, greaterThanOrEqualTo(12));

      // Check key milestone badges
      final firstSteps = badges.firstWhere((b) => b['id'] == 'first_steps');
      expect(firstSteps['is_unlocked'], isTrue);

      final streak = badges.firstWhere((b) => b['id'] == 'streak_champion');
      expect(streak['is_unlocked'], isTrue);

      // Geometry quest should stay locked when level < 8
      final geometry = badges.firstWhere((b) => b['id'] == 'geometry_quest');
      expect(geometry['is_unlocked'], isFalse);
    });

    test('Level progression dynamically unlocks high-tier badges', () {
      final initialUnlocked = appState.unlockedBadgesCount;

      // Advance to level 8
      while (appState.level < 8) {
        appState.addReward(starsToAdd: 100, xpToAdd: 100);
      }

      expect(appState.level, greaterThanOrEqualTo(8));
      final updatedBadges = appState.badgesList;
      final geometry = updatedBadges.firstWhere((b) => b['id'] == 'geometry_quest');
      expect(geometry['is_unlocked'], isTrue);
      expect(appState.unlockedBadgesCount, greaterThan(initialUnlocked));
    });

    test('Accommodations toggles update state dynamically', () {
      expect(appState.isDyslexicFont, isFalse);
      appState.toggleDyslexicFont();
      expect(appState.isDyslexicFont, isTrue);

      expect(appState.isZenMode, isTrue);
      appState.toggleZenMode();
      expect(appState.isZenMode, isFalse);
    });

    test('Live Analytics telemetry fallback is realistic and consistent', () {
      // Frustration and flow states should be bounded percentages
      expect(appState.frustrationPercent, inInclusiveRange(0, 100));
      expect(appState.focusPercent, inInclusiveRange(0, 100));
      expect(appState.pyBktMastery, inInclusiveRange(0.0, 1.0));
    });
  });
}
