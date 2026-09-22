import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/stage_content.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../adventure_map_sizes.dart';

class AdventureMapScreen extends StatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  State<AdventureMapScreen> createState() => _AdventureMapScreenState();
}

class _AdventureMapScreenState extends State<AdventureMapScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingJourneyAudio = false;
  bool _isPlayingNourAudio = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingJourneyAudio = false;
            _isPlayingNourAudio = false;
          });
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (mounted) {
          setState(() {
            _isPlayingJourneyAudio = false;
            _isPlayingNourAudio = false;
          });
        }
      });
      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingJourneyAudio = false;
            _isPlayingNourAudio = false;
          });
        }
      });
    } catch (e) {
      debugPrint('[TTS] AdventureMap init error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakText(String text, {required bool isJourney}) async {
    try {
      if (_isPlayingJourneyAudio || _isPlayingNourAudio) {
        await _flutterTts.stop();
        if ((isJourney && _isPlayingJourneyAudio) || (!isJourney && _isPlayingNourAudio)) {
          if (mounted) {
            setState(() {
              _isPlayingJourneyAudio = false;
              _isPlayingNourAudio = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isPlayingJourneyAudio = isJourney;
          _isPlayingNourAudio = !isJourney;
        });
      }

      final isAr = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      await _flutterTts.setLanguage(isAr ? 'ar-SA' : 'en-US');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] Speak error: $e');
      if (mounted) {
        setState(() {
          _isPlayingJourneyAudio = false;
          _isPlayingNourAudio = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AdventureMapSizes.screenPaddingH, vertical: AdventureMapSizes.screenPaddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. User Journey Card
          _buildUserJourneyCard(context, state),
          SizedBox(height: AdventureMapSizes.spacingMd),

          // 2. Mascot Nour AI Companion Card
          _buildMascotCard(context, state),
          SizedBox(height: AdventureMapSizes.spacingLg),

          // 3. Realm of Words Banner
          _buildRealmBanner(
            title: state.tr('realm_words'),
            subtitle: state.tr('realm_words_sub'),
            icon: Icons.auto_stories_rounded,
            color: AppColors.primary,
            bgColor: const Color(0xFFE0F2FE),
          ),
          SizedBox(height: AdventureMapSizes.spacingLg),

          // 4. Winding Adventure Path
          _buildAdventurePath(context, state),
          SizedBox(height: AdventureMapSizes.spacingLg),

          // 5. Today's Mini Challenges
          _buildMiniChallenges(context, state),
          SizedBox(height: AdventureMapSizes.spacingMd),

          // 6. Daily Mystery Chest
          _buildMysteryChest(context, state),
          SizedBox(height: AdventureMapSizes.spacingLg),
        ],
      ),
    );
  }

  Widget _buildUserJourneyCard(BuildContext context, AppState state) {
    final studentName = state.studentName.isNotEmpty
        ? state.studentName
        : (state.isArabic ? 'المتعلم' : 'Learner');
    final journeySpeechText = state.isArabic
        ? 'مرحباً $studentName! أنت الآن في رحلة المستوى ${state.level}، ولديك ${state.currentXp} من ${state.maxXp} نقطة خبرة. تابع تحقيق أهدافك اليومية واستكشف الخريطة!'
        : 'Hello $studentName! You are on the Level ${state.level} Journey, with ${state.currentXp} out of ${state.maxXp} XP. Keep completing your daily goals and explore the adventure map!';

    return Container(
      padding: EdgeInsets.all(AdventureMapSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AdventureMapSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B1C32),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: AdventureMapSizes.avatarSize,
                height: AdventureMapSizes.avatarSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primaryContainer.withOpacity(0.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.primary, size: AdventureMapSizes.avatarIconSize),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            state.studentName.isNotEmpty
                                ? state.studentName
                                : (state.isArabic ? 'المتعلم' : 'Learner'),
                            style: AppTypography.getLexend(
                              fontSize: AdventureMapSizes.bannerTitleFontSize,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.tr('student_title'),
                            style: AppTypography.labelSm(color: AppColors.onTertiaryFixed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.tr('daily_goals'),
                      style: AppTypography.bodySm(),
                    ),
                  ],
                ),
              ),
              // Speaker icon
              GestureDetector(
                onTap: () => _speakText(journeySpeechText, isJourney: true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: AdventureMapSizes.speakerBoxSize,
                  height: AdventureMapSizes.speakerBoxSize,
                  decoration: BoxDecoration(
                    color: _isPlayingJourneyAudio
                        ? AppColors.primary
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isPlayingJourneyAudio
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isPlayingJourneyAudio
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                    color: _isPlayingJourneyAudio ? Colors.white : AppColors.primary,
                    size: AdventureMapSizes.speakerIconSize,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.isArabic ? 'رحلة المستوى ${state.level}' : 'Level ${state.level} Journey',
                style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
              ),
              Text(
                state.isArabic ? '${state.currentXp} / ${state.maxXp} نقطة' : '${state.currentXp} / ${state.maxXp} XP',
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: state.currentXp / state.maxXp,
              minHeight: 12,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotCard(BuildContext context, AppState state) {
    final mascotSpeech = state.tr('mascot_speech_home');

    return Container(
      padding: EdgeInsets.all(AdventureMapSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AdventureMapSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B1C32),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Companion Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: AdventureMapSizes.mascotSize,
                    height: AdventureMapSizes.mascotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isPlayingNourAudio ? AppColors.primary : AppColors.primaryContainer,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: AppColors.sunnyYellow,
                      child: Icon(Icons.lightbulb_rounded, size: 12, color: AppColors.onTertiaryFixed),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        state.tr('mascot_name'),
                        style: AppTypography.getLexend(
                          fontSize: AdventureMapSizes.bannerTitleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (state.tr('mascot_name_ar').isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          state.tr('mascot_name_ar'),
                          style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.tr('ai_companion'),
                      style: AppTypography.labelSm(color: AppColors.outline),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Listen Button
              GestureDetector(
                onTap: () => _speakText(mascotSpeech, isJourney: false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPlayingNourAudio ? AppColors.error : AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _isPlayingNourAudio
                            ? AppColors.error.withOpacity(0.35)
                            : AppColors.primaryShadow,
                        offset: const Offset(0, 2),
                        blurRadius: _isPlayingNourAudio ? 6 : 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlayingNourAudio ? Icons.stop_rounded : Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlayingNourAudio ? state.tr('btn_stop') : state.tr('btn_listen'),
                        style: AppTypography.labelSm(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Speech Bubble
          GestureDetector(
            onTap: () => _speakText(mascotSpeech, isJourney: false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isPlayingNourAudio
                    ? AppColors.primaryContainer.withOpacity(0.12)
                    : AppColors.surfaceContainerLow.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPlayingNourAudio
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      mascotSpeech,
                      style: AppTypography.bodyMd(color: AppColors.onSurface).copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_isPlayingNourAudio) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.volume_up_rounded,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealmBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.getLexend(
                  fontSize: AdventureMapSizes.cardTitleFontSize,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.labelSm(color: color.withOpacity(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdventurePath(BuildContext context, AppState state) {
    return Column(
      children: [
        // Stage 12: Phonics Glade
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 12,
          title: state.tr('stage_12_title'),
          subtitle: state.tr('stage_12_sub'),
          icon: Icons.spellcheck_rounded,
          isMath: false,
        ),
        _buildPathDashes(),

        // Stage 13: Syllable Springs
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 13,
          title: state.tr('stage_13_title'),
          subtitle: state.tr('stage_13_sub'),
          icon: Icons.hearing_rounded,
          isMath: false,
        ),
        _buildPathDashes(),

        // Stage 14: Echo Cavern
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 14,
          title: state.tr('stage_14_title'),
          subtitle: state.tr('stage_14_sub'),
          icon: Icons.record_voice_over_rounded,
          isMath: false,
        ),
        _buildPathDashes(),

        // Transition: Rope Bridge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Text(
            state.tr('rope_bridge'),
            style: AppTypography.labelSm(color: const Color(0xFF1D4ED8)),
          ),
        ),
        const SizedBox(height: 16),

        // Realm 2 Banner: Citadel of Numbers
        _buildRealmBanner(
          title: state.tr('citadel_numbers'),
          subtitle: state.tr('citadel_numbers_sub'),
          icon: Icons.calculate_rounded,
          color: AppColors.secondary,
          bgColor: const Color(0xFFFFECEB),
        ),
        const SizedBox(height: 16),

        // Stage 15: Equation Fortress
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 15,
          title: state.tr('stage_15_title'),
          subtitle: state.tr('stage_15_sub'),
          icon: Icons.gesture_rounded,
          isMath: true,
        ),
        _buildPathDashes(),

        // Stage 16: Fraction Castle
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 16,
          title: state.tr('stage_16_title'),
          subtitle: state.tr('stage_16_sub'),
          icon: Icons.pie_chart_rounded,
          isMath: true,
        ),
        _buildPathDashes(),

        // Stage 17: Time Portal
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 17,
          title: state.tr('stage_17_title'),
          subtitle: state.tr('stage_17_sub'),
          icon: Icons.access_time_rounded,
          isMath: true,
        ),
        _buildPathDashes(),

        // Stage 18: Master Equation
        _buildDynamicStageNode(
          context: context,
          state: state,
          stageId: 18,
          title: state.tr('stage_18_title'),
          subtitle: state.tr('stage_18_sub'),
          icon: Icons.military_tech_rounded,
          isMath: true,
        ),
      ],
    );
  }

  void _launchStage(AppState state, int stageId, bool isMath) {
    if (isMath) {
      state.setSelectedMathStageId(stageId);
      state.setTabIndex(2);
    } else {
      state.setSelectedReadingStageId(stageId);
      state.setTabIndex(1);
    }
  }

  Widget _buildDynamicStageNode({
    required BuildContext context,
    required AppState state,
    required int stageId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isMath,
  }) {
    final stageInfo = state.stages[stageId] ?? {'status': stageId == 12 ? 'active' : 'locked', 'stars': 0};
    final status = stageInfo['status'] as String? ?? 'locked';
    final stars = (stageInfo['stars'] as num?)?.toInt() ?? 0;

    if (status == 'completed') {
      return _buildCompletedNode(
        state: state,
        title: title,
        subtitle: subtitle,
        icon: icon,
        stars: stars > 0 ? stars : 3,
        isMath: isMath,
        stageId: stageId,
        onTap: () => _launchStage(state, stageId, isMath),
      );
    } else if (status == 'active') {
      return _buildActiveStageNode(
        context: context,
        state: state,
        stageId: stageId,
        title: title,
        subtitle: subtitle,
        icon: icon,
        isMath: isMath,
      );
    } else {
      return _buildLockedNode(
        state: state,
        title: title,
        subtitle: subtitle,
        isMath: isMath,
        stageId: stageId,
      );
    }
  }

  Widget _buildActiveStageNode({
    required BuildContext context,
    required AppState state,
    required int stageId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isMath,
  }) {
    return Column(
      children: [
        // Bouncy Play Now Pill
        GestureDetector(
          onTap: () => _launchStage(state, stageId, isMath),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isMath ? const Color(0xFFD97706) : AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: isMath ? const Color(0xFFB45309) : AppColors.secondaryShadow, offset: const Offset(0, 3), blurRadius: 0),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  state.tr('btn_play_now'),
                  style: AppTypography.labelSm(color: Colors.white).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Active pulsing circle
        GestureDetector(
          onTap: () => _launchStage(state, stageId, isMath),
          child: Container(
            width: AdventureMapSizes.activeNodeSize,
            height: AdventureMapSizes.activeNodeSize,
            decoration: BoxDecoration(
              color: isMath ? const Color(0xFF0D9488) : AppColors.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: (isMath ? const Color(0xFF0D9488) : AppColors.primaryContainer).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
                BoxShadow(color: isMath ? const Color(0xFF0F766E) : AppColors.primaryShadow, offset: const Offset(0, 5), blurRadius: 0),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: AdventureMapSizes.nodeIconSize),
                    Text(
                      '$stageId',
                      style: AppTypography.getLexend(
                        fontSize: AdventureMapSizes.nodeLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Stage Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isMath ? const Color(0xFF0D9488) : AppColors.primaryContainer).withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x14006A62), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(
            children: [
              Text(title, style: AppTypography.headlineSm()),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.bodySm()),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isMath
                          ? (state.isArabic ? 'معمل الحساب' : 'Math Lab')
                          : (state.isArabic ? 'صديق القراءة' : 'Dyslexia Friendly'),
                      style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.isArabic ? '+50 نقطة' : '+50 XP',
                      style: AppTypography.labelSm(color: AppColors.onTertiaryFixed),
                    ),
                  ),
                ],
              ),
              if (isMath) ...[
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final stageContent = StageRepository.getStage(stageId);
                  final precision = (stageContent.minDrawingAccuracy * 100).toInt();
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AdventureMapSizes.accuracyBadgePaddingH,
                      vertical: AdventureMapSizes.accuracyBadgePaddingV,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AdventureMapSizes.accuracyBadgeRadius),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎯', style: TextStyle(fontSize: AdventureMapSizes.emojiFontSize)),
                        const SizedBox(width: 4),
                        Text(
                          state.isArabic ? 'دقة الرسم المطلوبة: $precision%' : 'Target Precision: $precision%',
                          style: AppTypography.labelSm(color: const Color(0xFF92400E)).copyWith(
                            fontSize: AdventureMapSizes.badgeFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPathDashes() {
    return Container(
      width: 6,
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildCompletedNode({
    required AppState state,
    required String title,
    required String subtitle,
    required IconData icon,
    required int stars,
    bool isMath = false,
    int? stageId,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              stars,
              (_) => const Icon(Icons.star_rounded, color: AppColors.sunnyYellow, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.sunnyYellow,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: AppColors.yellowShadow, offset: Offset(0, 4), blurRadius: 0),
              ],
            ),
            child: Icon(icon, color: AppColors.onTertiaryFixed, size: 32),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Text(title, style: AppTypography.labelMd()),
                Text(subtitle, style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                if (isMath && stageId != null) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final stageContent = StageRepository.getStage(stageId);
                    final precision = (stageContent.minDrawingAccuracy * 100).toInt();
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AdventureMapSizes.accuracyBadgePaddingH,
                        vertical: AdventureMapSizes.accuracyBadgePaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(AdventureMapSizes.accuracyBadgeRadius),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        state.isArabic ? '🎯 دقة الرسم: $precision%' : '🎯 $precision% Precision',
                        style: AppTypography.labelSm(color: const Color(0xFF065F46)).copyWith(
                          fontSize: AdventureMapSizes.badgeFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        state.isArabic ? 'إعادة لاحتساب النقاط' : 'Replay For Score',
                        style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                          fontSize: AdventureMapSizes.captionFontSize,
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
    );
  }



  Widget _buildLockedNode({
    required AppState state,
    required String title,
    required String subtitle,
    bool isMath = false,
    int? stageId,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: AppColors.surfaceDim, offset: Offset(0, 3), blurRadius: 0),
            ],
          ),
          child: const Icon(Icons.lock_rounded, color: AppColors.outline, size: 24),
        ),
        const SizedBox(height: 6),
        Text(title, style: AppTypography.labelMd(color: AppColors.outline)),
        Text(subtitle, style: AppTypography.labelSm(color: AppColors.outlineVariant)),
        if (isMath && stageId != null) ...[
          const SizedBox(height: 4),
          Builder(builder: (_) {
            final stageContent = StageRepository.getStage(stageId);
            final precision = (stageContent.minDrawingAccuracy * 100).toInt();
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: AdventureMapSizes.accuracyBadgePaddingH,
                vertical: AdventureMapSizes.accuracyBadgePaddingV,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AdventureMapSizes.accuracyBadgeRadius),
              ),
              child: Text(
                state.isArabic ? '🎯 الدقة المطلوبة: $precision%' : '🎯 Target: $precision%',
                style: AppTypography.labelSm(color: AppColors.outline).copyWith(
                  fontSize: AdventureMapSizes.captionFontSize,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMiniChallenges(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(state.tr('todays_challenges'), style: AppTypography.headlineSm()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(state.tr('challenges_available'), style: AppTypography.labelSm()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                icon: Icons.spellcheck_rounded,
                iconBg: AppColors.primaryFixed,
                iconColor: AppColors.primary,
                title: state.tr('word_harmony'),
                desc: state.tr('word_harmony_desc'),
                starsReward: state.isArabic ? '+30 نجمة' : '+30 Stars',
                btnColor: AppColors.primaryContainer,
                onTap: () => state.setTabIndex(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                icon: Icons.grain_rounded,
                iconBg: AppColors.secondaryFixed,
                iconColor: AppColors.secondary,
                title: state.tr('dot_counting'),
                desc: state.tr('dot_counting_desc'),
                starsReward: state.isArabic ? '+25 نجمة' : '+25 Stars',
                btnColor: AppColors.secondaryContainer,
                onTap: () => state.setTabIndex(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
    required String starsReward,
    required Color btnColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTypography.labelMd(), maxLines: 1),
          const SizedBox(height: 2),
          Text(desc, style: AppTypography.bodySm(), maxLines: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                starsReward,
                style: AppTypography.labelSm(color: AppColors.tertiary).copyWith(fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: onTap,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: btnColor,
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryChest(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFDF9B), Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.yellowShadow, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x1ADB8E00), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.tertiary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.tr('mystery_chest'),
                  style: AppTypography.getLexend(
                    fontSize: AdventureMapSizes.cardTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.tr('chest_unlocks_in'),
                  style: AppTypography.bodySm(color: AppColors.onTertiaryFixed),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: AppColors.yellowShadow, offset: Offset(0, 2), blurRadius: 0),
              ],
            ),
            child: Text(
              state.tr('btn_peek'),
              style: AppTypography.labelSm(color: AppColors.onTertiaryFixed).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
