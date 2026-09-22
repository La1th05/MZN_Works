import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamkeen_app/core/models/stage_content.dart';
import 'package:tamkeen_app/core/state/app_state.dart';
import 'package:tamkeen_app/features/dyscalculia_math/presentation/math_lab_sizes.dart';
import 'package:tamkeen_app/features/adventure_map/presentation/adventure_map_sizes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progressive Drawing Precision & Escalating Stages', () {
    test('Stages 15 through 18 have strictly escalating drawing accuracy thresholds', () {
      final stage15 = StageRepository.getStage(15);
      final stage16 = StageRepository.getStage(16);
      final stage17 = StageRepository.getStage(17);
      final stage18 = StageRepository.getStage(18);

      expect(stage15.minDrawingAccuracy, 0.50, reason: 'Stage 15 entry precision should be 50%');
      expect(stage16.minDrawingAccuracy, 0.65, reason: 'Stage 16 intermediate precision should be 65%');
      expect(stage17.minDrawingAccuracy, 0.75, reason: 'Stage 17 advanced precision should be 75%');
      expect(stage18.minDrawingAccuracy, 0.85, reason: 'Stage 18 master precision should be 85%');

      // Verify each stage is strictly harder (requires higher precision) than previous
      expect(stage16.minDrawingAccuracy > stage15.minDrawingAccuracy, isTrue);
      expect(stage17.minDrawingAccuracy > stage16.minDrawingAccuracy, isTrue);
      expect(stage18.minDrawingAccuracy > stage17.minDrawingAccuracy, isTrue);
    });

    test('Stage 18 Master Equation has valid mathematical specification', () {
      final stage18 = StageRepository.getStage(18);

      expect(stage18.stageId, 18);
      expect(stage18.isMath, isTrue);
      expect(stage18.num1, 38);
      expect(stage18.num2, 26);
      expect(stage18.operation, '+');
      expect(stage18.expectedAnswer, '64');
      expect(stage18.minDrawingAccuracy, 0.85);
      expect(stage18.title(false), '18. Master Equation');
      expect(stage18.title(true), '18. عرش العباقرة');
    });

    test('AppState includes stages 15, 16, 17, 18 and selects active math stage accurately', () {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();

      expect(state.stages.containsKey(15), isTrue);
      expect(state.stages.containsKey(16), isTrue);
      expect(state.stages.containsKey(17), isTrue);
      expect(state.stages.containsKey(18), isTrue);

      // Default active math stage is 15
      expect(state.activeMathStageId, 15);

      // Selecting unlocked stage works
      state.stages[18] = {'status': 'active', 'stars': 0};
      state.setSelectedMathStageId(18);
      expect(state.activeMathStageId, 18);

      state.stages[16] = {'status': 'active', 'stars': 0};
      state.setSelectedMathStageId(16);
      expect(state.activeMathStageId, 16);
    });

    test('MathLabSizes and AdventureMapSizes provide responsive tokens for precision UI', () {
      expect(MathLabSizes.accuracyGaugePaddingH, greaterThan(0));
      expect(MathLabSizes.accuracyGaugePaddingV, greaterThan(0));
      expect(MathLabSizes.accuracyGaugeRadius, greaterThan(0));
      expect(MathLabSizes.accuracyIndicatorHeight, greaterThan(0));
      expect(MathLabSizes.accuracyBadgeRadius, greaterThan(0));
      expect(MathLabSizes.accuracyIconSize, greaterThan(0));
      expect(MathLabSizes.precisionDialogRadius, greaterThan(0));

      expect(AdventureMapSizes.accuracyBadgePaddingH, greaterThan(0));
      expect(AdventureMapSizes.accuracyBadgePaddingV, greaterThan(0));
      expect(AdventureMapSizes.accuracyBadgeRadius, greaterThan(0));
      expect(AdventureMapSizes.accuracyBadgeIconSize, greaterThan(0));
    });
  });
}
