import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamkeen_app/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Level Progression & Sequential Stage Unlocking Tests', () {
    test('Initial state: Level 1, 0 XP, Stage 12 active, all other stages strictly locked', () {
      final state = AppState();

      expect(state.level, 1, reason: 'Initial level should be 1');
      expect(state.currentXp, 0, reason: 'Initial XP should be 0');
      expect(state.maxXp, 100, reason: 'Max XP per level should be 100 for steady progression');
      expect(state.stages[12]?['status'], 'active');

      // Stages 13 through 18 must be strictly locked initially
      for (int stageId = 13; stageId <= 18; stageId++) {
        expect(state.stages[stageId]?['status'], 'locked',
            reason: 'Stage $stageId must start locked until previous stage is finished');
      }
    });

    test('Locked stages cannot be selected or jumped to', () {
      final state = AppState();

      // Attempting to select locked reading stage 14 should be ignored
      state.setSelectedReadingStageId(14);
      expect(state.activeReadingStageId, 12,
          reason: 'Cannot select locked stage 14; active stage must remain 12');

      // Attempting to select locked math stage 18 should be ignored
      state.setSelectedMathStageId(18);
      expect(state.activeMathStageId, 15,
          reason: 'Cannot select locked stage 18; active math fallback remains 15');
    });

    test('First completion advances level and sequentially unlocks ONLY the immediate next stage', () async {
      final state = AppState();

      // Completing Stage 12 with 3 stars:
      final result12 = await state.completeStage(12, starsEarned: 3, nextStageId: 13);
      expect(result12['is_first_completion'], isTrue);
      expect(state.stages[12]?['status'], 'completed');
      expect(state.stages[12]?['stars'], 3);

      // Level must have increased from 1 to 2!
      expect(state.level, 2, reason: 'Completing stage 12 with 100 XP must level up the user to Level 2');
      expect(state.currentXp, 0);

      // Stage 13 is now unlocked, but 14 through 18 MUST still be locked
      expect(state.stages[13]?['status'], 'active');
      for (int stageId = 14; stageId <= 18; stageId++) {
        expect(state.stages[stageId]?['status'], 'locked',
            reason: 'Stage $stageId must remain locked until its predecessor is completed');
      }
    });

    test('Chain progression: 12 -> 13 -> 14 -> 15 -> 16 -> 17 -> 18 with level advancement', () async {
      final state = AppState();

      // Complete 12 -> unlocks 13 (Level 2)
      await state.completeStage(12, starsEarned: 3, nextStageId: 13);
      expect(state.stages[13]?['status'], 'active');
      expect(state.level, 2);

      // Complete 13 -> unlocks 14 (Level 3)
      await state.completeStage(13, starsEarned: 3, nextStageId: 14);
      expect(state.stages[14]?['status'], 'active');
      expect(state.level, 3);

      // Complete 14 -> unlocks 15 (Math Lab unlocked! Level 4)
      await state.completeStage(14, starsEarned: 3, nextStageId: 15);
      expect(state.stages[15]?['status'], 'active');
      expect(state.level, 4);

      // Complete 15 -> unlocks 16 (Level 5)
      await state.completeStage(15, starsEarned: 3, nextStageId: 16);
      expect(state.stages[16]?['status'], 'active');
      expect(state.level, 5);

      // Complete 16 -> unlocks 17 (Level 6)
      await state.completeStage(16, starsEarned: 3, nextStageId: 17);
      expect(state.stages[17]?['status'], 'active');
      expect(state.level, 6);

      // Complete 17 -> unlocks 18 (Level 7)
      await state.completeStage(17, starsEarned: 3, nextStageId: 18);
      expect(state.stages[18]?['status'], 'active');
      expect(state.level, 7);

      // Complete 18 (Final Master stage! Level 8)
      await state.completeStage(18, starsEarned: 3, nextStageId: 18);
      expect(state.stages[18]?['status'], 'completed');
      expect(state.level, 8);
    });

    test('Score anti-farming: Replaying an already completed stage does NOT duplicate points', () async {
      final state = AppState();

      // First completion of stage 12 with 3 stars:
      // Base: 50 + (3 * 10) = 80 stars
      await state.completeStage(12, starsEarned: 3, nextStageId: 13);
      final initialStars = state.stars;
      final initialLevel = state.level;
      expect(initialStars, 80);
      expect(initialLevel, 2);

      // Replaying stage 12 with the SAME 3 stars:
      final replayResult = await state.completeStage(12, starsEarned: 3, nextStageId: 13);
      expect(replayResult['is_first_completion'], isFalse);
      expect(replayResult['stars_added'], 0,
          reason: 'Replaying with same score must award 0 delta stars (no point farming!)');

      // Total stars and level must remain unchanged!
      expect(state.stars, initialStars);
      expect(state.level, initialLevel);
    });

    test('Score recalculation: Replaying with better score awards delta, lower score readjusts points', () async {
      final state = AppState();

      // Complete stage 12 with 1 star:
      // Base: 50 + (1 * 10) = 60 stars
      await state.completeStage(12, starsEarned: 1, nextStageId: 13);
      expect(state.stars, 60);
      expect(state.stages[12]?['stars'], 1);

      // Replay and improve to 3 stars:
      // Delta: (3 - 1) * 10 = +20 stars!
      final improveResult = await state.completeStage(12, starsEarned: 3, nextStageId: 13);
      expect(improveResult['is_first_completion'], isFalse);
      expect(improveResult['stars_added'], 20);
      expect(state.stars, 80);
      expect(state.stages[12]?['stars'], 3);

      // Replay and get 2 stars:
      // Points readjust to new evaluation: (2 - 3) * 10 = -10 stars!
      final lowerResult = await state.completeStage(12, starsEarned: 2, nextStageId: 13);
      expect(lowerResult['is_first_completion'], isFalse);
      expect(lowerResult['stars_added'], -10);
      expect(state.stars, 70);
      expect(state.stages[12]?['stars'], 2);
    });
  });
}
