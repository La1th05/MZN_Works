import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../../core/models/stage_content.dart';
import '../../../../core/services/ai_bridge_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../reading_arena_sizes.dart';

class ReadingArenaScreen extends StatefulWidget {
  const ReadingArenaScreen({super.key});

  @override
  State<ReadingArenaScreen> createState() => _ReadingArenaScreenState();
}

class _ReadingArenaScreenState extends State<ReadingArenaScreen> with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isPlayingAudio = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  late AnimationController _waveController;

  ReadingAnalysisResult? _analysisResult;
  int _activeWordIndex = -1;
  Timer? _goldenGlideTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initTts();
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _activeWordIndex = -1;
          });
          _stopGoldenGlide();
        }
      });
      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _activeWordIndex = -1;
          });
          _stopGoldenGlide();
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _activeWordIndex = -1;
          });
          _stopGoldenGlide();
        }
      });
    } catch (e) {
      debugPrint('[TTS] Init error: $e');
    }
  }

  void _startGoldenGlide(List<String> words, double speedFactor) {
    _goldenGlideTimer?.cancel();
    if (words.isEmpty) return;

    if (mounted) {
      setState(() {
        _activeWordIndex = 0;
      });
    }

    final intervalMs = ((850 / (speedFactor > 0 ? speedFactor : 1.0)).clamp(400, 1600)).round();

    _goldenGlideTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_activeWordIndex < words.length - 1) {
          _activeWordIndex++;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _stopGoldenGlide() {
    _goldenGlideTimer?.cancel();
    _goldenGlideTimer = null;
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _stopGoldenGlide();
    _waveController.dispose();
    _audioRecorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _speakText(String text, double speed) async {
    try {
      if (_isPlayingAudio) {
        await _flutterTts.stop();
      }
      setState(() => _isPlayingAudio = true);
      final isAr = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      await _flutterTts.setLanguage(isAr ? 'ar-SA' : 'en-US');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5 * speed);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] Speak error: $e');
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  void _handleMicTap() async {
    final appState = context.read<AppState>();
    final stage = StageRepository.getStage(appState.activeReadingStageId);
    final expectedText = appState.isArabic ? stage.textAr : stage.textEn;

    if (_isRecording) {
      _recordTimer?.cancel();
      _stopGoldenGlide();
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      String? audioBase64;
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            audioBase64 = base64Encode(bytes);
            debugPrint('[Record] Captured audio file: ${bytes.length} bytes');
          }
        }
      } catch (e) {
        debugPrint('[Record] Audio stop error: $e');
      }

      final durationSec = _recordDuration > 0 ? _recordDuration.toDouble() : 8.0;
      final result = await AIBridgeService.analyzeReading(
        expectedText: expectedText,
        audioBase64: audioBase64,
        durationSeconds: durationSec,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisResult = result;
        });
      }
    } else {
      // Start Real Audio Recording
      try {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          if (mounted) {
            final isAr = Provider.of<AppState>(context, listen: false).isArabic;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  isAr ? 'يرجى منح إذن الميكروفون لتسجيل القراءة' : 'Please grant microphone permission',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/reading_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );
        debugPrint('[Record] Started recording WAV to: $filePath');
      } catch (e) {
        debugPrint('[Record] Start recording error: $e');
        if (mounted) {
          final isAr = Provider.of<AppState>(context, listen: false).isArabic;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                isAr ? 'تعذر تشغيل الميكروفون، يرجى المحاولة ثانية' : 'Could not start microphone',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final passageWords = expectedText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      _startGoldenGlide(passageWords, appState.audioSpeed);

      setState(() {
        _isRecording = true;
        _analysisResult = null;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _recordDuration++;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentStatus = state.stages[state.activeReadingStageId]?['status'] ?? 'locked';
    if (currentStatus == 'locked') {
      return _buildLockedStageGate(context, state);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: ReadingArenaSizes.screenPaddingH, vertical: ReadingArenaSizes.screenPaddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Stage Top Bar
          _buildStageHeader(context, state),
          SizedBox(height: ReadingArenaSizes.spacingSm),

          // 2. Dyslexia Comfort Deck Toolbar
          _buildComfortDeck(context, state),
          SizedBox(height: ReadingArenaSizes.spacingSm),

          // 3. Mascot Guidance Bubble
          _buildMascotGuidance(context, state),
          SizedBox(height: ReadingArenaSizes.spacingSm),

          // Focus Ruler (if enabled)
          if (state.isFocusRulerActive) ...[
            _buildFocusRulerBar(state),
            SizedBox(height: ReadingArenaSizes.spacingSm),
          ],

          // 4. Interactive Reading Passage
          _buildPassageCard(context, state),
          SizedBox(height: ReadingArenaSizes.spacingSm),

          // 5. Phoneme Sound-out helper
          _buildSoundOutHelper(context, state),
          SizedBox(height: ReadingArenaSizes.spacingMd),

          // 6. Voice Recording Arena
          _buildRecordingSection(context, state),
          SizedBox(height: ReadingArenaSizes.spacingMd),

          // 7. Gamified Results Card (Shown after recording and AI analysis)
          if (_analysisResult != null) ...[
            _buildCelebrationCard(context, state),
            SizedBox(height: ReadingArenaSizes.spacingLg),
          ],
        ],
      ),
    );
  }

  Widget _buildStageHeader(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Back Arrow
          GestureDetector(
            onTap: () => state.setTabIndex(0), // Back to map
            child: Container(
              width: ReadingArenaSizes.backButtonSize,
              height: ReadingArenaSizes.backButtonSize,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: AppColors.outlineVariant, offset: Offset(0, 2), blurRadius: 0),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.primary, size: ReadingArenaSizes.backIconSize),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        state.isArabic ? 'المرحلة ${state.activeReadingStageId}' : 'Stage ${state.activeReadingStageId}',
                        style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        StageRepository.getStage(state.activeReadingStageId).subtitle(state.isArabic),
                        style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  StageRepository.getStage(state.activeReadingStageId).title(state.isArabic),
                  style: AppTypography.getLexend(
                    fontSize: ReadingArenaSizes.headerTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Zen visibility icon
          GestureDetector(
            onTap: () => state.toggleZenMode(),
            child: Container(
              width: ReadingArenaSizes.zenToggleSize,
              height: ReadingArenaSizes.zenToggleSize,
              decoration: BoxDecoration(
                color: state.isZenMode ? AppColors.primaryFixed : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                state.isZenMode ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Audio Speed Toggle
          GestureDetector(
            onTap: () => state.cycleAudioSpeed(),
            child: Container(
              height: ReadingArenaSizes.speedToggleHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: AppColors.outlineVariant, offset: Offset(0, 2), blurRadius: 0),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    state.isArabic ? '×${state.audioSpeed}' : '${state.audioSpeed}x',
                    style: AppTypography.labelSm(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComfortDeck(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(state.tr('comfort_deck'), style: AppTypography.labelSm()),
                ],
              ),
              // Focus Ruler button
              GestureDetector(
                onTap: () => state.toggleFocusRuler(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.isFocusRulerActive ? AppColors.primaryContainer : AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: state.isFocusRulerActive ? AppColors.primaryShadow : const Color(0xFF4FDBCC),
                        offset: const Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_stream_rounded,
                          color: state.isFocusRulerActive ? Colors.white : AppColors.onPrimaryFixed, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        state.tr('focus_ruler'),
                        style: AppTypography.labelSm(
                          color: state.isFocusRulerActive ? Colors.white : AppColors.onPrimaryFixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Font Size Controller
              Expanded(
                flex: 4,
                child: Container(
                  height: ReadingArenaSizes.comfortControlHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(ReadingArenaSizes.comfortControlRadius),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => state.decreaseFontSize(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          color: Colors.transparent,
                          child: Text(
                            state.isArabic ? 'أ-' : 'A-',
                            style: AppTypography.getLexend(fontSize: ReadingArenaSizes.comfortAFontSize, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Text(
                        state.tr('font_size'),
                        style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(fontSize: ReadingArenaSizes.comfortLabelFontSize),
                      ),
                      GestureDetector(
                        onTap: () => state.increaseFontSize(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          color: Colors.transparent,
                          child: Text(
                            state.isArabic ? 'أ+' : 'A+',
                            style: AppTypography.getLexend(fontSize: ReadingArenaSizes.comfortAFontSize, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: ReadingArenaSizes.spacingInlineSm),

              // Spacing 1.8x
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => state.toggleSpacing(),
                  child: Container(
                    height: ReadingArenaSizes.comfortControlHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: state.is18xSpacing ? const Color(0xFFB2F2EC) : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(ReadingArenaSizes.comfortControlRadius),
                      border: state.is18xSpacing ? Border.all(color: AppColors.primaryContainer) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_line_spacing_rounded, color: AppColors.primary, size: ReadingArenaSizes.comfortIconSize),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            state.tr('spacing_18x'),
                            style: AppTypography.labelSm().copyWith(fontSize: ReadingArenaSizes.comfortLabelFontSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: ReadingArenaSizes.spacingInlineSm),

              // OpenDyslexic Toggle
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => state.toggleDyslexicFont(),
                  child: Container(
                    height: ReadingArenaSizes.comfortControlHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: state.isDyslexicFont ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(ReadingArenaSizes.comfortControlRadius),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.font_download_rounded,
                          color: state.isDyslexicFont ? Colors.white : AppColors.primary,
                          size: ReadingArenaSizes.comfortIconSize,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            state.tr('opendyslexic'),
                            style: AppTypography.labelSm(
                              color: state.isDyslexicFont ? Colors.white : AppColors.primary,
                            ).copyWith(fontSize: ReadingArenaSizes.comfortLabelFontSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFocusRulerBar(AppState state) {
    final isAr = state.isArabic;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x33F59E0B),
            Color(0x66FBBF24),
            Color(0x33F59E0B),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: const Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFF59E0B), width: 2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22F59E0B),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.straighten_rounded, color: Color(0xFFB45309), size: 16),
          const SizedBox(width: 8),
          Text(
            isAr
                ? 'مسطرة التركيز الذهبية مفعّلة: توجه نظرك وتمنع تشتت الأسطر'
                : 'Golden Focus Ruler Active: Guides eye tracking & prevents line jumping',
            style: AppTypography.labelSm(color: const Color(0xFF78350F)).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: ReadingArenaSizes.discoveryBadgeFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotGuidance(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Image.asset('assets/images/logo.png', errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.tr('mascot_reading_instruction'),
              style: AppTypography.bodySm(color: const Color(0xFF1E3A8A)),
            ),
          ),
          GestureDetector(
            onTap: () => _speakText(state.tr('mascot_reading_instruction'), 0.9),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageCard(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeReadingStageId);
    final baseFontSize = ReadingArenaSizes.readingPassageFontSize;
    final lineHeight = state.is18xSpacing ? 1.9 : 1.5;
    final isAr = state.isArabic;
    final text = stage.text(isAr);
    final discoveryWord = stage.discoveryWord(isAr);
    final words = text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  stage.title(isAr),
                  style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_isPlayingAudio) {
                    _flutterTts.stop();
                    _stopGoldenGlide();
                    setState(() {
                      _isPlayingAudio = false;
                      _activeWordIndex = -1;
                    });
                  } else {
                    _startGoldenGlide(words, state.audioSpeed);
                    _speakText(text, state.audioSpeed);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPlayingAudio ? const Color(0xFFFEF3C7) : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: _isPlayingAudio ? Border.all(color: const Color(0xFFF59E0B), width: 1.5) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlayingAudio ? Icons.pause_circle_rounded : Icons.volume_up_rounded,
                        color: _isPlayingAudio ? const Color(0xFFB45309) : AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlayingAudio
                            ? (isAr ? 'إيقاف' : 'Pause')
                            : (isAr ? 'استمع للقصة' : 'Listen'),
                        style: AppTypography.labelSm(
                          color: _isPlayingAudio ? const Color(0xFFB45309) : AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gliding Golden Light Guidance Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                    ? const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)]
                    : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                  ? const [
                      BoxShadow(
                        color: Color(0x33F59E0B),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                            ? const Color(0xFFD97706)
                            : const Color(0xFF64748B),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                            ? (isAr
                                ? 'الضوء الذهبي المنساب: كلمة ${_activeWordIndex + 1} من ${words.length}'
                                : 'Golden Light Gliding: Word ${_activeWordIndex + 1} of ${words.length}')
                            : (isAr
                                ? 'الخط الذهبي: يبدأ الانسياب تلقائياً مع بدء القراءة'
                                : 'Golden Light: Glides automatically when reading begins'),
                        style: AppTypography.labelSm(
                          color: (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                              ? const Color(0xFF92400E)
                              : const Color(0xFF475569),
                        ).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: ReadingArenaSizes.discoveryBadgeFontSize,
                        ),
                      ),
                    ),
                    if (words.isNotEmpty && _activeWordIndex >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${((_activeWordIndex + 1) / words.length * 100).clamp(0, 100).toInt()}%',
                          style: TextStyle(
                            fontSize: ReadingArenaSizes.captionFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: words.isNotEmpty && _activeWordIndex >= 0
                        ? ((_activeWordIndex + 1) / words.length).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (_isRecording || _isPlayingAudio || _activeWordIndex >= 0)
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.readingHighlight.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.readingHighlightBorder),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 10,
              children: words.asMap().entries.map((entry) {
                final index = entry.key;
                final w = entry.value;
                final isActive = index == _activeWordIndex;
                final isPast = _activeWordIndex >= 0 && index < _activeWordIndex;
                final isTarget = discoveryWord.isNotEmpty && (w.contains(discoveryWord) || discoveryWord.contains(w));

                if (isActive) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeWordIndex = index);
                      _speakText(w, 0.75);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 2.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66F59E0B),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            w,
                            style: AppTypography.getBody(
                              fontSize: baseFontSize,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF78350F),
                              isDyslexicFont: state.isDyslexicFont,
                              height: lineHeight,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            height: 3.5,
                            width: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (isPast) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeWordIndex = index);
                      _speakText(w, 0.75);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        w,
                        style: AppTypography.getBody(
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                          isDyslexicFont: state.isDyslexicFont,
                          height: lineHeight,
                        ),
                      ),
                    ),
                  );
                } else if (isTarget) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeWordIndex = index);
                      _speakText(w, 0.7);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.readingHighlightBorder,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        w,
                        style: AppTypography.getBody(
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          isDyslexicFont: state.isDyslexicFont,
                          height: lineHeight,
                        ),
                      ),
                    ),
                  );
                } else {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeWordIndex = index);
                      _speakText(w, 0.8);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        w,
                        style: AppTypography.getBody(
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface,
                          isDyslexicFont: state.isDyslexicFont,
                          height: lineHeight,
                        ),
                      ),
                    ),
                  );
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundOutHelper(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeReadingStageId);
    final isAr = state.isArabic;
    final breakdown = stage.soundBreakdown(isAr);
    final discWord = stage.discoveryWord(isAr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_alt_rounded, color: AppColors.periwinkle, size: 22),
          const SizedBox(width: 8),
          Text(
            discWord,
            style: AppTypography.labelSm(color: AppColors.periwinkle).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              breakdown,
              style: AppTypography.getLexend(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.periwinkle,
                letterSpacing: 0.05,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _speakText(breakdown.replaceAll('•', ' '), 0.6),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.periwinkle.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, color: AppColors.periwinkle, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingSection(BuildContext context, AppState state) {
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
          // Status indicator with live timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? Colors.red
                      : (_isAnalyzing ? AppColors.secondaryContainer : AppColors.primaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              if (_isRecording) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '00:${_recordDuration.toString().padLeft(2, '0')}',
                    style: AppTypography.labelSm(color: const Color(0xFFDC2626)).copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    state.isArabic ? 'أستمع لنطقك الآن... تتبع الضوء الذهبي!' : 'Listening now... follow the golden light!',
                    style: AppTypography.labelSm(color: Colors.red).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (_isAnalyzing) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    state.isArabic ? 'جارٍ تحليل النطق بالذكاء الاصطناعي...' : 'Evaluating with Dyslexia AI...',
                    style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Flexible(
                  child: Text(
                    state.isArabic ? 'اضغط على الميكروفون لبدء القراءة' : 'Tap microphone to start reading',
                    style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // 2.5D Big Microphone Button
          GestureDetector(
            onTap: _isAnalyzing ? null : _handleMicTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Pulse Halo
                if (_isRecording)
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (_, __) => Container(
                      width: 90 + (_waveController.value * 20),
                      height: 90 + (_waveController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryContainer.withOpacity(0.25 * (1 - _waveController.value)),
                      ),
                    ),
                  ),

                // Button Body with Bottom Extrusion
                Container(
                  width: ReadingArenaSizes.micButtonSize,
                  height: ReadingArenaSizes.micButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? AppColors.secondaryContainer : AppColors.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: _isRecording ? AppColors.secondaryShadow : AppColors.primaryShadow,
                        offset: const Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: ReadingArenaSizes.micIconSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animated Soundwave bars
          if (_isRecording)
            AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final heights = [14.0, 26.0, 18.0, 24.0, 12.0];
                  final factor = (index % 2 == 0 ? _waveController.value : (1 - _waveController.value));
                  return Container(
                    width: 5,
                    height: heights[index] * (0.6 + 0.4 * factor),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 10),

          // Listen to Nour helper (TTS Audio Playback)
          GestureDetector(
            onTap: () {
              final stage = StageRepository.getStage(state.activeReadingStageId);
              _speakText(stage.text(state.isArabic), state.audioSpeed);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPlayingAudio ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryContainer.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isPlayingAudio ? Icons.volume_up_rounded : Icons.play_circle_fill_rounded,
                    color: _isPlayingAudio ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPlayingAudio
                        ? (state.isArabic ? 'نور تقرأ الآن...' : 'Nour is speaking...')
                        : state.tr('listen_to_nour'),
                    style: AppTypography.labelSm(
                      color: _isPlayingAudio ? Colors.white : AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard(BuildContext context, AppState state) {
    final stage = StageRepository.getStage(state.activeReadingStageId);
    final isAr = state.isArabic;
    final discWord = stage.discoveryWord(isAr);
    final discMeaning = stage.discoveryMeaning(isAr);
    final acc = _analysisResult?.accuracyPercent ?? 0.0;
    final int stars = acc >= 80 ? 3 : (acc >= 50 ? 2 : (acc > 0 ? 1 : 0));
    final String celebrationTitle = acc >= 80
        ? (isAr ? 'قراءة متميزة ورائعة!' : 'Magnificent Reading!')
        : (acc >= 50
            ? (isAr ? 'محاولة جيدة، واصل!' : 'Good Effort, Keep Going!')
            : (isAr ? 'تحتاج لمزيد من التدريب' : 'Needs More Practice'));
    final String celebrationEmoji = acc >= 80 ? '🎉 ' : (acc >= 50 ? '👍 ' : '💪 ');
    final String accuracySubtitle = acc >= 80
        ? (isAr ? 'صقر متألق!' : 'Super Falcon!')
        : (acc >= 50 ? (isAr ? 'تقدم ثابت!' : 'Steady Progress!') : (isAr ? 'حاول مجددًا!' : 'Keep Trying!'));
    final String pacingSubtitle = acc >= 50 ? (isAr ? 'منتظم' : 'Steady') : (isAr ? 'يحتاج ضبط' : 'Needs Pacing');
    final String expressionSubtitle = acc >= 70 ? (isAr ? 'وقفات لطيفة' : 'Gentle Pauses') : (isAr ? 'تحتاج وضوح' : 'Needs Practice');

    return Container(
      padding: EdgeInsets.all(ReadingArenaSizes.resultCardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(ReadingArenaSizes.resultCardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(celebrationEmoji, style: AppTypography.getLexend(fontSize: ReadingArenaSizes.celebrationEmojiSize, fontWeight: FontWeight.normal)),
                    SizedBox(width: ReadingArenaSizes.spacingXs),
                    Expanded(
                      child: Text(
                        celebrationTitle,
                        style: AppTypography.getLexend(fontSize: ReadingArenaSizes.celebrationTitleSize, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: ReadingArenaSizes.spacingInlineMd),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < stars ? const Color(0xFFF59E0B) : AppColors.outlineVariant,
                    size: ReadingArenaSizes.starIconSize,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ReadingArenaSizes.spacingSection),

          // Metric Tiles (Pacing, Accuracy, Expression)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: state.tr('pacing_label'),
                  value: _analysisResult != null ? '${_analysisResult!.wordsPerMinute}' : '0',
                  subtitle: pacingSubtitle,
                  color: AppColors.primary,
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              SizedBox(width: ReadingArenaSizes.spacingInlineMd),
              Expanded(
                child: _buildMetricTile(
                  label: state.tr('accuracy_label'),
                  value: _analysisResult != null ? '${_analysisResult!.accuracyPercent.toInt()}%' : '0%',
                  subtitle: accuracySubtitle,
                  color: acc >= 80 ? const Color(0xFF10B981) : (acc >= 50 ? const Color(0xFFD97706) : const Color(0xFFEF4444)),
                  bgColor: acc >= 80 ? const Color(0xFFECFDF5) : (acc >= 50 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                ),
              ),
              SizedBox(width: ReadingArenaSizes.spacingInlineMd),
              Expanded(
                child: _buildMetricTile(
                  label: state.tr('expression_label'),
                  value: _analysisResult != null ? '${_analysisResult!.expressionScore}' : '1.0',
                  subtitle: expressionSubtitle,
                  color: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF3E8FF),
                ),
              ),
            ],
          ),

          // AI Feedback & Transcribed Voice Banner
          if (_analysisResult != null && (_analysisResult!.feedbackMessage.isNotEmpty || _analysisResult!.spokenText.isNotEmpty)) ...[
            SizedBox(height: ReadingArenaSizes.spacingSection),
            Container(
              padding: EdgeInsets.all(ReadingArenaSizes.feedbackPadding),
              decoration: BoxDecoration(
                color: acc >= 60 ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(ReadingArenaSizes.feedbackRadius),
                border: Border.all(
                  color: acc >= 60 ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_analysisResult!.spokenText.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.record_voice_over_rounded, size: ReadingArenaSizes.smallIconSize, color: AppColors.primary),
                        SizedBox(width: ReadingArenaSizes.spacingInlineSm),
                        Expanded(
                          child: Text(
                            isAr ? 'ما سمعه الذكاء الاصطناعي من نطقك:' : 'What AI Heard From Your Voice:',
                            style: AppTypography.labelSm().copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ReadingArenaSizes.spacingXs),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: ReadingArenaSizes.spacingInlineMd, vertical: ReadingArenaSizes.spacingInlineSm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ReadingArenaSizes.comfortControlRadius),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        '"${_analysisResult!.spokenText}"',
                        style: AppTypography.bodySm(color: Colors.black87).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                    SizedBox(height: ReadingArenaSizes.spacingInlineMd),
                  ],
                  if (_analysisResult!.feedbackMessage.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          acc >= 60 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: acc >= 60 ? const Color(0xFF10B981) : const Color(0xFFD97706),
                          size: ReadingArenaSizes.feedbackIconSize,
                        ),
                        SizedBox(width: ReadingArenaSizes.spacingInlineSm),
                        Expanded(
                          child: Text(
                            _analysisResult!.feedbackMessage,
                            style: AppTypography.bodySm(
                              color: acc >= 60 ? const Color(0xFF1E3A8A) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: ReadingArenaSizes.spacingSection),

          // Mastered vs Discovery Word
          Container(
            padding: EdgeInsets.all(ReadingArenaSizes.feedbackPadding),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(ReadingArenaSizes.feedbackRadius),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: ReadingArenaSizes.masteredIconSize),
                          SizedBox(width: ReadingArenaSizes.spacingXs),
                          Expanded(
                            child: Text(
                              '${state.tr('words_mastered')}: ${_analysisResult?.wordsMastered ?? 0}',
                              style: AppTypography.labelSm().copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: ReadingArenaSizes.spacingInlineMd),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: ReadingArenaSizes.spacingInlineMd, vertical: ReadingArenaSizes.spacingXs),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(ReadingArenaSizes.comfortControlRadius),
                      ),
                      child: Text(
                        state.tr('discovery_word'),
                        style: AppTypography.labelSm(color: AppColors.onSecondaryFixed),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ReadingArenaSizes.spacingInlineMd),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.sunnyYellow, size: ReadingArenaSizes.discoveryIconSize),
                    SizedBox(width: ReadingArenaSizes.spacingInlineMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(discWord, style: AppTypography.labelMd()),
                          Text(discMeaning, style: AppTypography.bodySm()),
                        ],
                      ),
                    ),
                    TactileButton(
                      label: state.tr('btn_try_again'),
                      variant: TactileButtonVariant.primary,
                      height: ReadingArenaSizes.tryAgainButtonHeight,
                      borderRadius: ReadingArenaSizes.comfortControlRadius,
                      icon: Icon(Icons.replay_rounded, size: ReadingArenaSizes.smallIconSize, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _analysisResult = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: ReadingArenaSizes.spacingLg),

          // Big 2.5D Action Button
          TactileButton(
            label: acc >= 50 ? state.tr('btn_continue_quest') : (isAr ? 'إعادة المحاولة والمتابعة' : 'Try Again To Continue'),
            variant: TactileButtonVariant.primary,
            height: ReadingArenaSizes.continueButtonHeight,
            onPressed: () async {
              if (acc < 50) {
                setState(() {
                  _analysisResult = null;
                });
                return;
              }
              final activeStage = state.activeReadingStageId;
              final nextStage = activeStage < 14 ? activeStage + 1 : 15;
              await state.completeStage(activeStage, starsEarned: stars, nextStageId: nextStage);
              final finalAcc = _analysisResult?.accuracyPercent ?? (acc > 0 ? acc : 85.0);
              final wpmVal = _analysisResult?.wordsPerMinute ?? 65;
              final errResidual = (100.0 - finalAcc).clamp(0.0, 100.0);
              await SupabaseService.recordDyslexiaSession(
                profileId: state.currentProfileId,
                stageId: activeStage,
                passageTitle: stage.title(isAr),
                accuracy: finalAcc,
                wpm: wpmVal,
                expression: _analysisResult?.expressionScore ?? 4.0,
                wordsMastered: _analysisResult?.wordsMastered ?? 10,
                discoveryWord: discWord,
                discoveryMeaning: discMeaning,
                substitutionsPct: double.parse((errResidual * 0.45).toStringAsFixed(1)),
                hesitationsPct: double.parse((errResidual * 0.35).toStringAsFixed(1)),
                omissionsPct: double.parse((errResidual * 0.20).toStringAsFixed(1)),
                phoneticNotes: isAr
                    ? 'تركيز صوتي: الحروف المتقاربة لفظاً والمدود الصوتية'
                    : 'Phonetic focus: Consonant blends and short vowels',
                studentName: state.studentName.isNotEmpty ? state.studentName : (isAr ? 'المتعلم' : 'Learner'),
              );
              await state.initFromStorage();
              state.setTabIndex(0); // Return to map with new stage unlocked
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ReadingArenaSizes.metricTilePaddingV,
        horizontal: ReadingArenaSizes.metricTilePaddingH,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ReadingArenaSizes.metricTileRadius),
      ),
      child: Column(
        children: [
          Text(label, style: AppTypography.labelSm(color: color)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.getLexend(
              fontSize: ReadingArenaSizes.metricValueFontSize,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: AppTypography.labelSm(color: color.withOpacity(0.85))
                  .copyWith(fontSize: ReadingArenaSizes.metricSubtitleFontSize),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedStageGate(BuildContext context, AppState state) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ReadingArenaSizes.screenPaddingH, vertical: 40),
        child: Container(
          padding: EdgeInsets.all(ReadingArenaSizes.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
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
                height: 48,
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
