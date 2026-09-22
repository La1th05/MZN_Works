import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/stage_content.dart';
import '../../../../core/services/ai_bridge_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../math_lab_sizes.dart';

class MathEquationLabScreen extends StatefulWidget {
  const MathEquationLabScreen({super.key});

  @override
  State<MathEquationLabScreen> createState() => _MathEquationLabScreenState();
}

class _MathEquationLabScreenState extends State<MathEquationLabScreen> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _isEraser = false;
  int _hintLevel = 1;
  int _startTime = 0;
  int _attempts = 1;

  // CNN Handwriting recognition state
  bool _isRecognizing = false;
  String? _lastRecognizedSymbol;
  double? _lastConfidence;
  Timer? _debounceTimer;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _speakHint(String text) async {
    try {
      await _flutterTts.stop();
      final isAr = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      await _flutterTts.setLanguage(isAr ? 'ar-SA' : 'en-US');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] Math hint speak error: $e');
    }
  }

  /// Rasterize vector strokes into Base64 PNG image (white background, black stroke) for CNN
  Future<String?> _strokesToBase64Png(Size size) async {
    if (_strokes.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));

      // 1. Solid white background
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // 2. Thick black stroke matching CNN training distribution
      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.isEmpty) continue;
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }

      final picture = recorder.endRecording();
      final width = size.width.clamp(100.0, 400.0).toInt();
      final height = size.height.clamp(100.0, 400.0).toInt();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('[Canvas] Failed to convert strokes to PNG: $e');
      return null;
    }
  }

  /// Send drawn image to best_symbol_cnn2.pt model on server
  Future<void> _recognizeDrawing(Size size, AppState state, {bool append = false}) async {
    if (_strokes.isEmpty) return;

    setState(() => _isRecognizing = true);

    final b64 = await _strokesToBase64Png(size);
    if (b64 == null) {
      if (mounted) setState(() => _isRecognizing = false);
      return;
    }

    final result = await AIBridgeService.recognizeHandwrittenSymbol(imageBase64: b64);
    if (!mounted) return;

    setState(() {
      _isRecognizing = false;
      if (!result.isBlank && result.symbol.isNotEmpty) {
        _lastRecognizedSymbol = result.symbol;
        _lastConfidence = result.confidence;

        if (append) {
          state.updateMathInputResult(state.mathInputResult + result.symbol);
        } else {
          state.updateMathInputResult(result.symbol);
        }
      }
    });
  }

  void _clearCanvas() {
    _debounceTimer?.cancel();
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _lastRecognizedSymbol = null;
      _lastConfidence = null;
      _isRecognizing = false;
    });
    context.read<AppState>().updateMathInputResult('');
  }

  void _undoStroke(Size size, AppState state) {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      if (_strokes.isEmpty) {
        _clearCanvas();
      } else {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 350), () {
          _recognizeDrawing(size, state);
        });
      }
    }
  }

  void _eraseAt(Offset pos, Size size, AppState state) {
    const double radius = 22.0;
    setState(() {
      _strokes.removeWhere((stroke) {
        return stroke.any((point) => (point - pos).distance <= radius);
      });
      if (_strokes.isEmpty) {
        _clearCanvas();
      } else {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 350), () {
          _recognizeDrawing(size, state);
        });
      }
    });
  }

  void _checkAnswer(AppState state) async {
    final responseTime = DateTime.now().millisecondsSinceEpoch - _startTime;
    final stage = StageRepository.getStage(state.activeMathStageId);
    final eqString = '${stage.num1} ${stage.operation} ${stage.num2}';

    final eval = await AIBridgeService.evaluateMath(
      expectedAnswer: stage.expectedAnswer.toString(),
      studentAnswer: state.mathInputResult,
      responseTimeMs: responseTime,
      hintCount: _hintLevel,
      attempts: _attempts,
    );

    if (!mounted) return;

    final isDrawingUsed = _strokes.isNotEmpty;
    final drawingAccuracy = _lastConfidence ?? 0.0;
    final requiredAccuracy = stage.minDrawingAccuracy;

    if (eval.isCorrect) {
      if (isDrawingUsed && drawingAccuracy < requiredAccuracy) {
        // Answer is correct, but drawing precision was below this challenge's required threshold!
        setState(() => _attempts += 1);
        final currentAccPercent = (drawingAccuracy * 100).toInt();
        final targetAccPercent = (requiredAccuracy * 100).toInt();
        final guidanceMsg = state.isArabic
            ? 'رائع يا بطل! حسابك صحيح (${stage.expectedAnswer})، ولكن دقة رسم الرقم هي $currentAccPercent% والمطلوب في هذا التحدي $targetAccPercent% على الأقل لتجاوزه. حاول كتابة الرقم بوضوح ودقة أكبر!'
            : 'Great job! Your calculation is correct (${stage.expectedAnswer}), but drawing accuracy is $currentAccPercent% and this stage requires $targetAccPercent% to pass. Draw it more clearly to advance!';

        _speakHint(guidanceMsg);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MathLabSizes.precisionDialogRadius),
            ),
            title: Row(
              children: [
                const Text('🎯 '),
                Expanded(
                  child: Text(
                    state.isArabic ? 'الحساب صحيح ولكن دقة الرسم تحتاج تحسين!' : 'Correct Math! Drawing Needs Polish',
                    style: AppTypography.headlineSm(),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guidanceMsg, style: AppTypography.bodyMd()),
                SizedBox(height: MathLabSizes.spacingMd),
                Container(
                  padding: EdgeInsets.all(MathLabSizes.accuracyGaugePaddingH),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(MathLabSizes.accuracyBadgeRadius),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.isArabic ? 'دقة رسمك الحالية:' : 'Your Accuracy:', style: AppTypography.labelSm()),
                          Text('$currentAccPercent%', style: AppTypography.labelSm(color: const Color(0xFFD97706)).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: MathLabSizes.spacingXs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MathLabSizes.accuracyIndicatorHeight),
                        child: LinearProgressIndicator(
                          value: drawingAccuracy.clamp(0.0, 1.0),
                          backgroundColor: Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                          minHeight: MathLabSizes.accuracyIndicatorHeight,
                        ),
                      ),
                      SizedBox(height: MathLabSizes.spacingInlineSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.isArabic ? 'المطلوب لاجتياز التحدي:' : 'Required Target:', style: AppTypography.labelSm(color: AppColors.primary)),
                          Text('🎯 $targetAccPercent%', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TactileButton(
                label: state.isArabic ? 'إعادة الرسم بدقة أعلى ✏️' : 'Redraw With Higher Precision ✏️',
                variant: TactileButtonVariant.primary,
                height: MathLabSizes.checkButtonHeight * 0.85,
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearCanvas();
                },
              ),
            ],
          ),
        );
        return;
      }

      // Passed both Math Calculation & Drawing Accuracy!
      final activeStage = state.activeMathStageId;
      final nextStage = activeStage < 18 ? activeStage + 1 : 18;

      int stars = 3;
      if (isDrawingUsed) {
        if (drawingAccuracy >= requiredAccuracy + 0.15) {
          stars = 3;
        } else if (drawingAccuracy >= requiredAccuracy + 0.05) {
          stars = 2;
        } else {
          stars = 1;
        }
      }

      await state.completeStage(activeStage, starsEarned: stars, nextStageId: nextStage);
      await SupabaseService.recordMathSession(
        profileId: state.currentProfileId,
        stageId: activeStage,
        equation: eqString,
        studentAnswer: state.mathInputResult,
        isCorrect: true,
        responseTimeMs: responseTime,
        hintCount: _hintLevel,
        attempts: _attempts,
        pKnowledge: eval.pKnowledge,
        adaptiveDifficulty: eval.adaptiveDifficulty,
        frustrationIndex: eval.frustrationIndex,
        confusedIndex: eval.confusedIndex,
        studentName: state.studentName.isNotEmpty ? state.studentName : 'Learner',
      );
      await state.initFromStorage();

      if (!mounted) return;

      final accPercent = (drawingAccuracy * 100).toInt();
      final targetPercent = (requiredAccuracy * 100).toInt();
      final nextStageContent = StageRepository.getStage(nextStage);
      final nextTargetPercent = (nextStageContent.minDrawingAccuracy * 100).toInt();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MathLabSizes.precisionDialogRadius)),
          title: Row(
            children: [
              const Text('🌟 '),
              Expanded(
                child: Text(
                  state.isArabic ? 'إتقان رائع ودقة ممتازة!' : 'Brilliant Mastery & Precision!',
                  style: AppTypography.headlineSm(),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eval.feedbackMessage, style: AppTypography.bodyMd()),
              SizedBox(height: MathLabSizes.spacingSm),
              if (isDrawingUsed) ...[
                Container(
                  padding: EdgeInsets.all(MathLabSizes.accuracyGaugePaddingH),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(MathLabSizes.accuracyBadgeRadius),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.isArabic ? 'دقة رسمك في التحدي:' : 'Drawing Precision:', style: AppTypography.labelSm(color: const Color(0xFF065F46))),
                          Text(
                            state.isArabic
                                ? '🎯 $accPercent% (المطلوب: $targetPercent%)'
                                : '🎯 $accPercent% (Target: $targetPercent%)',
                            style: AppTypography.labelSm(color: const Color(0xFF059669)).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: MathLabSizes.spacingXs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MathLabSizes.accuracyIndicatorHeight),
                        child: LinearProgressIndicator(
                          value: drawingAccuracy.clamp(0.0, 1.0),
                          backgroundColor: Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          minHeight: MathLabSizes.accuracyIndicatorHeight,
                        ),
                      ),
                      if (activeStage < 18) ...[
                        SizedBox(height: MathLabSizes.spacingInlineSm),
                        Text(
                          state.isArabic ? '⚡ التحدي القادم سيتطلب دقة أعلى: $nextTargetPercent%!' : '⚡ Next Challenge Target: $nextTargetPercent% Precision!',
                          style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: MathLabSizes.spacingSm),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isArabic
                            ? 'مستوى التمكّن: ${(eval.pKnowledge * 100).toInt()}% • التالي: ${eval.adaptiveDifficulty}'
                            : 'PyBKT Mastery: ${(eval.pKnowledge * 100).toInt()}% • Next: ${eval.adaptiveDifficulty}',
                        style: AppTypography.labelSm(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TactileButton(
              label: state.isArabic ? 'المرحلة التالية' : 'Next Equation',
              onPressed: () {
                Navigator.pop(ctx);
                _clearCanvas();
                state.setTabIndex(0);
              },
            ),
          ],
        ),
      );
    } else {
      setState(() => _attempts += 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eval.feedbackMessage),
          backgroundColor: AppColors.amberGentle,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showCalmBreak(AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFF0FDF4),
        title: Row(
          children: [
            const Icon(Icons.spa_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              state.isArabic ? 'استراحة تنفس هادئ' : 'Calm Breathing Break',
              style: AppTypography.headlineSm(color: AppColors.primary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withOpacity(0.2),
              ),
              child: const Icon(Icons.self_improvement_rounded, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              state.isArabic
                ? 'خذ نفساً عميقاً عبر أنفك... واحبسه لثانيتين... ثم أخرجه ببطء.'
                : 'Breathe in slowly through your nose... hold for 2 seconds... and gently release.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(),
            ),
          ],
        ),
        actions: [
          Center(
            child: TactileButton(
              label: state.isArabic ? 'أشعر بالانتعاش الآن ✨' : 'I Feel Refreshed ✨',
              variant: TactileButtonVariant.primary,
              height: 48,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentStatus = state.stages[state.activeMathStageId]?['status'] ?? 'locked';
    if (currentStatus == 'locked') {
      return _buildLockedStageGate(context, state);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: MathLabSizes.screenPaddingH, vertical: MathLabSizes.screenPaddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Zen Mode & Step Bar
          _buildZenHeader(context, state),
          SizedBox(height: MathLabSizes.spacingSm),

          // 2. Quest & Visual Toggles
          _buildTogglesRow(context, state),
          SizedBox(height: MathLabSizes.spacingSm),

          // 3. Equation & Concrete Manipulatives Card
          _buildEquationCard(context, state),
          SizedBox(height: MathLabSizes.spacingMd),

          // 4. Dual Input Switcher (Magic Canvas vs Keypad)
          _buildInputSwitcher(context, state),
          SizedBox(height: MathLabSizes.spacingSm),

          // 5. CNN Vision Model Pill
          _buildCnnModelIndicator(context, state),
          SizedBox(height: MathLabSizes.spacingSm),

          // 6. Interactive Drawing Canvas OR Big Keypad
          if (!state.isBigKeypadActive)
            _buildInteractiveCanvas(context, state)
          else
            _buildBigKeypad(context, state),
          SizedBox(height: MathLabSizes.spacingMd),

          // 7. Mascot Friendly Hint (Nour)
          _buildMascotHint(context, state),
          SizedBox(height: MathLabSizes.spacingMd),

          // 8. Bottom Action Buttons
          TactileButton(
            label: state.tr('check_answer'),
            variant: TactileButtonVariant.primary,
            height: MathLabSizes.checkButtonHeight,
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            onPressed: () => _checkAnswer(state),
          ),
          SizedBox(height: MathLabSizes.spacingSm),

          TactileButton(
            label: state.tr('calm_breathing_break'),
            variant: TactileButtonVariant.neutral,
            height: MathLabSizes.calmBreakHeight,
            icon: const Icon(Icons.spa_outlined, color: AppColors.primary),
            onPressed: () => _showCalmBreak(state),
          ),
          SizedBox(height: MathLabSizes.spacingLg),
        ],
      ),
    );
  }

  Widget _buildZenHeader(BuildContext context, AppState state) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF2563EB), size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        state.tr('zen_mode'),
                        style: AppTypography.labelSm(color: const Color(0xFF1E40AF)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.tertiary, size: 16),
                  const SizedBox(width: 4),
                  Text(state.tr('gentle_growth'), style: AppTypography.labelSm(color: AppColors.onTertiaryFixed)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(state.tr('step_progress'), style: AppTypography.labelSm()),
            const SizedBox(),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const LinearProgressIndicator(
            value: 3 / 5,
            minHeight: 8,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
          ),
        ),
      ],
    );
  }

  Widget _buildTogglesRow(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeMathStageId);
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_rounded, color: AppColors.onPrimaryFixed, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    stage.title(state.isArabic),
                    style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => state.toggleVisualBlocks(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.showVisualBlocks ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF1D4ED8),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  state.showVisualBlocks
                      ? state.tr('hide_visuals')
                      : (state.isArabic ? 'إظهار المكعبات البصرية' : 'Show visual blocks'),
                  style: AppTypography.labelSm(color: const Color(0xFF1D4ED8)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquationCard(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeMathStageId);
    final tens1 = (stage.num1 ~/ 10).clamp(0, 9);
    final tens2 = (stage.num2 ~/ 10).clamp(0, 9);
    final ones1 = (stage.num1 % 10).clamp(0, 9);
    final ones2 = (stage.num2 % 10).clamp(0, 9);

    final tensSummary = stage.operation == '+' ? '${(tens1 + tens2) * 10}' : '${tens1 * 10} - ${tens2 * 10}';
    final onesSummary = stage.operation == '+' ? '${ones1 + ones2}' : '$ones1 ${stage.operation} $ones2';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Equation numbers row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNumberChip('${stage.num1}', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  stage.operation,
                  textAlign: TextAlign.center,
                  style: AppTypography.getLexend(
                    fontSize: MathLabSizes.equationFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              ),
              _buildNumberChip('${stage.num2}', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '=',
                  textAlign: TextAlign.center,
                  style: AppTypography.getLexend(
                    fontSize: MathLabSizes.equationFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.outline,
                    height: 1.1,
                  ),
                ),
              ),
              // Answer Box with golden outline (auto-expanding based on number)
              Container(
                constraints: BoxConstraints(
                  minWidth: MathLabSizes.equationBoxMinWidth,
                  minHeight: MathLabSizes.equationBoxHeight,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: MathLabSizes.equationBoxPaddingH,
                  vertical: MathLabSizes.equationBoxPaddingV,
                ),
                decoration: BoxDecoration(
                  color: AppColors.readingHighlight,
                  borderRadius: BorderRadius.circular(MathLabSizes.equationBoxRadius),
                  border: Border.all(color: AppColors.yellowShadow, width: 2, style: BorderStyle.solid),
                ),
                alignment: Alignment.center,
                child: Text(
                  state.mathInputResult.isEmpty ? '?' : state.mathInputResult,
                  textAlign: TextAlign.center,
                  style: AppTypography.getLexend(
                    fontSize: MathLabSizes.equationResultFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tertiary,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),

          if (state.showVisualBlocks) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderLight),
            const SizedBox(height: 12),

            // Tens Rods Manipulatives
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.view_column_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.tr('tens_rods'),
                          style: AppTypography.labelSm(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(tensSummary, style: AppTypography.labelMd(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // num1 tens rods
                Row(
                  children: List.generate(
                    tens1,
                    (_) => Container(
                      width: 10,
                      height: 38,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(stage.operation, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                // num2 tens rods
                Row(
                  children: List.generate(
                    tens2,
                    (_) => Container(
                      width: 10,
                      height: 38,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: stage.operation == '-' ? const Color(0xFFEF4444).withValues(alpha: 0.7) : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ones Cubes Manipulatives
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.grain_rounded, color: AppColors.tertiary, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.tr('ones_cubes'),
                          style: AppTypography.labelSm(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(onesSummary, style: AppTypography.labelMd(color: AppColors.tertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // num1 ones cubes
                Row(
                  children: List.generate(
                    ones1,
                    (_) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sunnyYellow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(stage.operation, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                // num2 ones cubes
                Row(
                  children: List.generate(
                    ones2,
                    (_) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: stage.operation == '-' ? const Color(0xFFEF4444).withOpacity(0.7) : AppColors.sunnyYellow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberChip(String text, Color bg, Color textColor) {
    return Container(
      constraints: BoxConstraints(
        minWidth: MathLabSizes.equationBoxMinWidth,
        minHeight: MathLabSizes.equationBoxHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: MathLabSizes.equationBoxPaddingH,
        vertical: MathLabSizes.equationBoxPaddingV,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MathLabSizes.equationBoxRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.getLexend(
          fontSize: MathLabSizes.equationFontSize,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildInputSwitcher(BuildContext context, AppState state) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => state.setInputMethod(isBigKeypad: false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: !state.isBigKeypadActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !state.isBigKeypadActive
                      ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note_rounded,
                        color: !state.isBigKeypadActive ? AppColors.primary : AppColors.outline, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      state.tr('magic_canvas'),
                      style: AppTypography.labelSm(
                        color: !state.isBigKeypadActive ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => state.setInputMethod(isBigKeypad: true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: state.isBigKeypadActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: state.isBigKeypadActive
                      ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dialpad_rounded,
                        color: state.isBigKeypadActive ? AppColors.primary : AppColors.outline, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      state.tr('big_keypad'),
                      style: AppTypography.labelSm(
                        color: state.isBigKeypadActive ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCnnModelIndicator(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeMathStageId);
    final targetPercent = (stage.minDrawingAccuracy * 100).toInt();
    final currentConfidence = _lastConfidence ?? 0.0;
    final currentConfPercent = (currentConfidence * 100).toInt();
    final meetsTarget = currentConfidence >= stage.minDrawingAccuracy;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MathLabSizes.accuracyGaugePaddingH,
        vertical: MathLabSizes.accuracyGaugePaddingV,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(MathLabSizes.accuracyGaugeRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: MathLabSizes.accuracyIconSize),
              SizedBox(width: MathLabSizes.spacingInlineSm),
              Text(state.tr('cnn_vision_model'), style: AppTypography.labelSm(color: AppColors.primary)),
              SizedBox(width: MathLabSizes.spacingInlineSm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MathLabSizes.spacingInlineMd,
                  vertical: MathLabSizes.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(MathLabSizes.accuracyBadgeRadius),
                ),
                child: Text(
                  state.mathInputResult.isEmpty ? '—' : state.mathInputResult,
                  style: AppTypography.labelSm(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: MathLabSizes.spacingInlineSm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MathLabSizes.spacingInlineSm,
                  vertical: MathLabSizes.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(MathLabSizes.accuracyBadgeRadius),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  '🎯 $targetPercent%',
                  style: AppTypography.labelSm(color: const Color(0xFF92400E)).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_isRecognizing)
            Row(
              children: [
                SizedBox(
                  width: MathLabSizes.accuracyIconSize * 0.8,
                  height: MathLabSizes.accuracyIconSize * 0.8,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: MathLabSizes.spacingInlineSm),
                Text(
                  state.isArabic ? 'جاري التعرّف...' : 'Recognizing...',
                  style: AppTypography.labelSm(color: AppColors.primary),
                ),
              ],
            )
          else if (_lastRecognizedSymbol != null)
            Row(
              children: [
                Icon(
                  meetsTarget ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: meetsTarget ? const Color(0xFF10B981) : const Color(0xFFD97706),
                  size: MathLabSizes.accuracyIconSize,
                ),
                SizedBox(width: MathLabSizes.spacingXs),
                Text(
                  '$_lastRecognizedSymbol ($currentConfPercent%${meetsTarget ? ' ✓' : ' < $targetPercent%'})',
                  style: AppTypography.labelSm(
                    color: meetsTarget ? const Color(0xFF065F46) : const Color(0xFFB45309),
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: MathLabSizes.accuracyIconSize),
                SizedBox(width: MathLabSizes.spacingXs),
                Text(state.tr('cnn_status_ready'), style: AppTypography.labelSm(color: AppColors.primary)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCanvas(BuildContext context, AppState state) {
    return Container(
      height: MathLabSizes.canvasHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MathLabSizes.canvasRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final canvasSize = Size(maxW, maxH);

          Offset clampPoint(Offset p) {
            return Offset(
              p.dx.clamp(4.0, maxW - 4.0),
              p.dy.clamp(4.0, maxH - 4.0),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(MathLabSizes.canvasRadius),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Dotted Grid Pattern Background & Ghost Number
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridAndGhostPainter(),
                  ),
                ),

                // User Drawing Gesture Area - uses _EagerPanGestureRecognizer to claim touch exclusively and prevent parent SingleChildScrollView scrolling
                Positioned.fill(
                  child: RawGestureDetector(
                    gestures: <Type, GestureRecognizerFactory>{
                      _EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
                        () => _EagerPanGestureRecognizer(),
                        (_EagerPanGestureRecognizer instance) {
                          instance.onStart = (details) {
                            final pt = clampPoint(details.localPosition);
                            if (_isEraser) {
                              _eraseAt(pt, canvasSize, state);
                              return;
                            }
                            _debounceTimer?.cancel();
                            setState(() {
                              _currentStroke = [pt];
                              _strokes.add(_currentStroke!);
                              _lastRecognizedSymbol = null;
                            });
                          };
                          instance.onUpdate = (details) {
                            final pt = clampPoint(details.localPosition);
                            if (_isEraser) {
                              _eraseAt(pt, canvasSize, state);
                              return;
                            }
                            setState(() {
                              _currentStroke?.add(pt);
                            });
                          };
                          instance.onEnd = (_) {
                            _currentStroke = null;
                            if (!_isEraser && _strokes.isNotEmpty) {
                              _debounceTimer?.cancel();
                              _debounceTimer = Timer(const Duration(milliseconds: 650), () {
                                if (mounted && _strokes.isNotEmpty) {
                                  _recognizeDrawing(canvasSize, state);
                                }
                              });
                            }
                          };
                          instance.onCancel = () {
                            _currentStroke = null;
                          };
                        },
                      ),
                    },
                    child: CustomPaint(
                      painter: StrokePainter(strokes: _strokes),
                    ),
                  ),
                ),

                // Live CNN Feedback Bubble
                if (_isRecognizing || _lastRecognizedSymbol != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryContainer),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRecognizing) ...[
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.isArabic ? 'الذكاء يحلل...' : 'CNN reading...',
                              style: AppTypography.labelSm(color: AppColors.primary),
                            ),
                          ] else if (_lastRecognizedSymbol != null) ...[
                            const Icon(Icons.bolt_rounded, color: AppColors.secondary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$_lastRecognizedSymbol',
                              style: AppTypography.getLexend(
                                fontWeight: FontWeight.bold,
                                fontSize: MathLabSizes.headerTitleFontSize,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                state.updateMathInputResult(state.mathInputResult + _lastRecognizedSymbol!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      state.isArabic
                                          ? 'تمت إضافة الخانة ($_lastRecognizedSymbol)'
                                          : 'Appended ($_lastRecognizedSymbol) to answer',
                                    ),
                                    duration: const Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  state.isArabic ? '+ إضافة' : '+ Append',
                                  style: AppTypography.labelSm(color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Floating Tools Toolbar (Pencil, Eraser, Trash, AI Recon, Undo)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      _buildToolIcon(
                        icon: Icons.edit_rounded,
                        isActive: !_isEraser,
                        onTap: () => setState(() => _isEraser = false),
                      ),
                      const SizedBox(width: 8),
                      _buildToolIcon(
                        icon: Icons.cleaning_services_rounded,
                        isActive: _isEraser,
                        onTap: () => setState(() => _isEraser = true),
                      ),
                      const SizedBox(width: 8),
                      _buildToolIcon(
                        icon: Icons.delete_outline_rounded,
                        isActive: false,
                        onTap: _clearCanvas,
                      ),
                      const SizedBox(width: 8),
                      // Trigger CNN recognition immediately
                      _buildToolIcon(
                        icon: Icons.auto_awesome_rounded,
                        isActive: _isRecognizing,
                        onTap: () => _recognizeDrawing(canvasSize, state),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: _buildToolIcon(
                    icon: Icons.undo_rounded,
                    isActive: false,
                    onTap: () => _undoStroke(canvasSize, state),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolIcon({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MathLabSizes.toolButtonSize,
        height: MathLabSizes.toolButtonSize,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Icon(icon, color: isActive ? Colors.white : AppColors.outline, size: MathLabSizes.toolIconSize),
      ),
    );
  }

  Widget _buildBigKeypad(BuildContext context, AppState state) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];

    return Container(
      padding: EdgeInsets.all(MathLabSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(MathLabSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, idx) {
          final key = keys[idx];
          return GestureDetector(
            onTap: () {
              if (key == 'C') {
                state.updateMathInputResult('');
              } else if (key == '⌫') {
                if (state.mathInputResult.isNotEmpty) {
                  state.updateMathInputResult(
                    state.mathInputResult.substring(0, state.mathInputResult.length - 1),
                  );
                }
              } else {
                state.updateMathInputResult(state.mathInputResult + key);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(MathLabSizes.keypadKeyRadius),
                boxShadow: const [
                  BoxShadow(color: AppColors.surfaceDim, offset: Offset(0, 3), blurRadius: 0),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                key,
                style: AppTypography.getLexend(fontSize: MathLabSizes.keypadFontSize, fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMascotHint(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeMathStageId);
    final hint = stage.nourHint(state.isArabic);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Image.asset('assets/images/logo.png', errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.tr('nour_hint_title'),
                  style: AppTypography.getLexend(
                    fontSize: MathLabSizes.hintFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _speakHint(hint),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                  child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: AppTypography.bodyMd(color: const Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              setState(() => _hintLevel += 1);
            },
            child: Text(
              state.tr('need_next_clue'),
              style: AppTypography.labelSm(color: const Color(0xFF2563EB)).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedStageGate(BuildContext context, AppState state) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: MathLabSizes.screenPaddingH, vertical: 40),
        child: Container(
          padding: EdgeInsets.all(MathLabSizes.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(MathLabSizes.cardRadius),
            border: Border.all(color: AppColors.borderLight, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.outline, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                state.tr('stage_locked_title'),
                style: AppTypography.headlineSm(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.tr('stage_locked_desc'),
                style: AppTypography.bodyMd(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TactileButton(
                label: state.tr('btn_back_to_map'),
                variant: TactileButtonVariant.primary,
                height: MathLabSizes.checkButtonHeight,
                icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                onPressed: () => state.setTabIndex(0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridAndGhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = AppColors.borderLight.withOpacity(0.4)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    const spacing = 20.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // Draw faint ghost number "73"
    final textPainter = TextPainter(
      text: TextSpan(
        text: '73',
        style: TextStyle(
          fontSize: MathLabSizes.ghostDigitFontSize,
          fontWeight: FontWeight.w900,
          color: const Color(0x1F006A62),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  StrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)));

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 2.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom PanGestureRecognizer that eagerly and immediately resolves accepted in the
/// gesture arena on PointerDown, preventing parent SingleChildScrollView from intercepting
/// and scrolling while the user writes or draws on the canvas.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager handwriting pan';
}

