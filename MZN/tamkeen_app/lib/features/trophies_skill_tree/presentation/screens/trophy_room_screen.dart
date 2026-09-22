import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../trophy_room_sizes.dart';

class TrophyRoomScreen extends StatefulWidget {
  const TrophyRoomScreen({super.key});

  @override
  State<TrophyRoomScreen> createState() => _TrophyRoomScreenState();
}

class _TrophyRoomScreenState extends State<TrophyRoomScreen> {
  int _activeTab = 0; // 0: Skill Tree, 1: Badges, 2: Activity
  bool _isChestOpened = false;

  @override
  void initState() {
    super.initState();
    _loadChestState();
  }

  Future<void> _loadChestState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isChestOpened = prefs.getBool('weekly_chest_opened') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: TrophyRoomSizes.screenPaddingH, vertical: TrophyRoomSizes.screenPaddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Explorer Profile Card
          _buildProfileCard(context, state),
          SizedBox(height: TrophyRoomSizes.spacingMd),

          // 2. Tab-dependent Content
          if (_activeTab == 0) ...[
            // Knowledge Constellation Card (Skill Tree)
            _buildConstellationCard(context, state),
            SizedBox(height: TrophyRoomSizes.spacingMd),
            // Weekly Explorer Chest
            _buildWeeklyChestCard(context, state),
          ] else if (_activeTab == 1) ...[
            // Badges Grid View
            _buildBadgesView(context, state),
          ] else ...[
            // Recent Activity Feed View
            _buildActivityView(context, state),
          ],
          SizedBox(height: TrophyRoomSizes.spacingLg),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AppState state) {
    return Container(
      padding: EdgeInsets.all(TrophyRoomSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(TrophyRoomSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Level
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: TrophyRoomSizes.avatarSize,
                    height: TrophyRoomSizes.avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryContainer, width: 3),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/avatar.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.person, size: TrophyRoomSizes.avatarIconSize, color: AppColors.primary),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.sunnyYellow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        state.isArabic ? '⚡ المستوى ${state.level}' : '⚡ Lvl ${state.level}',
                        style: AppTypography.getLexend(
                          fontSize: TrophyRoomSizes.captionFontSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onTertiaryFixed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Title & Badges
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
                            style: AppTypography.headlineSm(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.isArabic
                                ? (state.userRole == 'Student'
                                    ? 'طالب'
                                    : (state.userRole == 'Parent' || state.userRole == 'Guardian' ? 'ولي أمر' : state.userRole))
                                : (state.userRole == 'طالب' ? 'Student' : (state.userRole == 'ولي أمر' ? 'Parent' : state.userRole)),
                            style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.tr('explorer_rank'),
                      style: AppTypography.bodySm(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        _buildProfileStatPill(
                          icon: Icons.star_rounded,
                          color: AppColors.tertiary,
                          bg: AppColors.tertiaryFixed,
                          text: state.isArabic ? '${state.stars} نجمة' : '${state.stars} Stars',
                        ),
                        const SizedBox(width: 8),
                        _buildProfileStatPill(
                          icon: Icons.military_tech_rounded,
                          color: AppColors.primary,
                          bg: AppColors.primaryFixed,
                          text: '${state.unlockedBadgesCount} ${state.isArabic ? 'أوسمة' : 'Badges'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Tabs (Skill Tree, Badges, Activity)
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTabItem(0, Icons.park_rounded, state.tr('tab_skill_tree')),
                _buildTabItem(1, Icons.military_tech_rounded, state.tr('tab_badges')),
                _buildTabItem(2, Icons.bar_chart_rounded, state.tr('tab_activity')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatPill({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: AppTypography.labelSm(color: color).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.outline),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelSm(
                    color: isSelected ? AppColors.primary : AppColors.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConstellationCard(BuildContext context, AppState state) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.tr('knowledge_constellation'),
                        style: AppTypography.getLexend(
                          fontSize: TrophyRoomSizes.cardTitleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.tr('dual_mastery'),
                  style: AppTypography.labelSm(color: AppColors.onTertiaryFixed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Skill Constellation Tree View
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                // Top Row: Fluency Scout (Left) & Geometry Quest (Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSkillNode(
                      icon: Icons.menu_book_rounded,
                      title: state.tr('fluency_scout'),
                      subtitle: state.tr('status_in_progress'),
                      badgeText: '68%',
                      badgeColor: AppColors.primary,
                      nodeColor: const Color(0xFFE0F2FE),
                      iconColor: AppColors.primary,
                      isLocked: false,
                      onTap: () => _showSkillDetailModal(
                        context,
                        title: state.tr('fluency_scout'),
                        subtitle: state.isArabic ? 'طلاقة القراءة وواحة الأصوات' : 'Reading Fluency & Phonetic Glade',
                        category: state.isArabic ? 'القراءة' : 'Reading',
                        mastery: 0.68,
                        advice: state.isArabic
                            ? 'أداؤك ممتاز في نطق المقاطع الصوتية! تابع التمارين اليومية لزيادة سرعة القراءة والطلاقة اللغوية.'
                            : 'Great acoustic pronunciation! Continue daily practice to increase reading speed and phonemic fluency.',
                      ),
                    ),
                    _buildSkillNode(
                      icon: Icons.lock_rounded,
                      title: state.tr('geometry_quest'),
                      subtitle: state.tr('status_locked'),
                      badgeText: '',
                      badgeColor: Colors.transparent,
                      nodeColor: AppColors.surfaceContainer,
                      iconColor: AppColors.outline,
                      isLocked: true,
                      onTap: () => _showSkillDetailModal(
                        context,
                        title: state.tr('geometry_quest'),
                        subtitle: state.isArabic ? 'الهندسة الفضائية والزوايا' : 'Spatial Geometry & Angles',
                        category: state.isArabic ? 'الرياضيات' : 'Math',
                        mastery: 0.0,
                        advice: state.isArabic
                            ? 'هذه المهارة المتقدمة مقفلة حالياً. ستفتح تلقائياً عند وصولك إلى المستوى 8!'
                            : 'This advanced skill is currently locked. It will unlock automatically once you reach Explorer Level 8!',
                      ),
                    ),
                  ],
                ),
                _buildConnectingLine(),

                // Middle Row: Phonics Hero & Equation Hunter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSkillNode(
                      icon: Icons.star_rounded,
                      title: state.tr('phonics_hero'),
                      subtitle: state.tr('status_mastered'),
                      badgeText: '✓',
                      badgeColor: AppColors.primary,
                      nodeColor: AppColors.sunnyYellow,
                      iconColor: AppColors.onTertiaryFixed,
                      isLocked: false,
                      onTap: () => _showSkillDetailModal(
                        context,
                        title: state.tr('phonics_hero'),
                        subtitle: state.isArabic ? 'الأصوات والتحليل الصوتي' : 'Phonics & Acoustic Parsing',
                        category: state.isArabic ? 'القراءة' : 'Reading',
                        mastery: 0.98,
                        advice: state.isArabic
                            ? 'تمكن كامل بنسبة 98%! استطعت تحليل الأصوات اللغوية بدقة عالية وتجاوز تحديات كهف الصدى.'
                            : 'Mastered at 98%! You successfully analyzed phonetic sound waves and conquered Echo Cavern.',
                      ),
                    ),
                    _buildSkillNode(
                      icon: Icons.shield_rounded,
                      title: state.tr('equation_hunter'),
                      subtitle: state.tr('status_mastered'),
                      badgeText: '✓',
                      badgeColor: AppColors.primary,
                      nodeColor: const Color(0xFFBFDBFE),
                      iconColor: const Color(0xFF1D4ED8),
                      isLocked: false,
                      onTap: () => _showSkillDetailModal(
                        context,
                        title: state.tr('equation_hunter'),
                        subtitle: state.isArabic ? 'توازن المعادلات والحساب' : 'Equation Balance & Arithmetic',
                        category: state.isArabic ? 'الرياضيات' : 'Math',
                        mastery: 0.92,
                        advice: state.isArabic
                            ? 'تمكن كامل بنسبة 92%! أظهر النموذج الذكي استيعاباً فائقاً لإعادة التجميع والتوازن الحسابي.'
                            : 'Mastered at 92%! The PyBKT model traced solid mastery over arithmetic equations and regrouping.',
                      ),
                    ),
                  ],
                ),
                _buildConnectingLine(),

                // Bottom Row: Word Master & Math Wizard
                Row(
                  children: [
                    Expanded(
                      child: _buildSkillTile(
                        icon: Icons.spellcheck_rounded,
                        iconBg: AppColors.primaryFixed,
                        iconColor: AppColors.primary,
                        title: state.tr('word_master'),
                        desc: state.isArabic ? 'المستوى 4 • بلورة' : 'Level 4 • Crystal',
                        onTap: () => _showSkillDetailModal(
                          context,
                          title: state.tr('word_master'),
                          subtitle: state.isArabic ? 'المستوى 4 • رتبة البلورة' : 'Level 4 • Crystal Tier',
                          category: state.isArabic ? 'القراءة' : 'Reading',
                          mastery: 0.85,
                          advice: state.isArabic
                              ? 'أنت في رتبة بلورة الكلمات بفضل مفرداتك المكتسبة وطلاقة القراءة المتطورة.'
                              : 'Crystal tier achieved through rich vocabulary acquisition and phonemic awareness.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSkillTile(
                        icon: Icons.calculate_rounded,
                        iconBg: const Color(0xFFDBEAFE),
                        iconColor: const Color(0xFF1D4ED8),
                        title: state.tr('math_wizard'),
                        desc: state.isArabic ? 'المستوى 3 • ياقوت' : 'Level 3 • Sapphire',
                        onTap: () => _showSkillDetailModal(
                          context,
                          title: state.tr('math_wizard'),
                          subtitle: state.isArabic ? 'المستوى 3 • رتبة الياقوت' : 'Level 3 • Sapphire Tier',
                          category: state.isArabic ? 'الرياضيات' : 'Math',
                          mastery: 0.84,
                          advice: state.isArabic
                              ? 'رتبة الياقوت الحسابي! تجاوزت التحديات الحسابية بدقة متقدمة في الرسم والنموذج الذكي.'
                              : 'Sapphire tier achieved! High precision across arithmetic lab equations and PyBKT mastery.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Core Wisdom Root
                GestureDetector(
                  onTap: () => _showSkillDetailModal(
                    context,
                    title: state.tr('core_wisdom_root'),
                    subtitle: state.isArabic ? 'جوهر التآزر المعرفي' : 'Cognitive Synergy Core',
                    category: state.isArabic ? 'إتقان ثنائي' : 'Dual Mastery',
                    mastery: 1.0,
                    advice: state.isArabic
                        ? 'جذر الحكمة الأساسي: هو نقطة التلاقي بين الطلاقة اللغوية والبراعة الحسابية في عقل المتعلم.'
                        : 'Core Wisdom Root: The foundational synergy integrating acoustic language fluency with spatial numeracy.',
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.spa_rounded, color: Color(0xFF4338CA), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          state.tr('core_wisdom_root'),
                          style: AppTypography.labelSm(color: const Color(0xFF4338CA)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingLine() {
    return Container(
      width: 4,
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.outlineVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSkillNode({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color nodeColor,
    required Color iconColor,
    required bool isLocked,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              if (badgeText.isNotEmpty)
                Positioned(
                  bottom: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeText,
                      style: AppTypography.getLexend(
                        fontSize: TrophyRoomSizes.microFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: AppTypography.labelSm()),
          Text(
            subtitle,
            style: AppTypography.labelSm(
              color: isLocked ? AppColors.outline : AppColors.primary,
            ).copyWith(fontSize: TrophyRoomSizes.badgeFontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(title, style: AppTypography.labelSm(), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              desc,
              style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
                fontSize: TrophyRoomSizes.badgeFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSkillDetailModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String category,
    required double mastery,
    required String advice,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.headlineSm()),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.labelSm(color: AppColors.primary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(category, style: AppTypography.labelSm(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.read<AppState>().isArabic ? 'نسبة التمكّن' : 'Mastery Index', style: AppTypography.labelSm()),
                Text('${(mastery * 100).toInt()}%', style: AppTypography.labelMd().copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: mastery,
                minHeight: 10,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advice,
                      style: AppTypography.bodySm(color: const Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(context.read<AppState>().isArabic ? 'حسناً' : 'OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesView(BuildContext context, AppState state) {
    return Container(
      padding: EdgeInsets.all(TrophyRoomSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(TrophyRoomSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    state.isArabic ? 'أوسمة المستكشف' : 'Explorer Badges',
                    style: AppTypography.getLexend(
                      fontSize: TrophyRoomSizes.cardTitleFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unlockedBadgesCount} / ${state.badgesList.length}',
                  style: AppTypography.labelSm(color: AppColors.onPrimaryFixed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
            ),
            itemCount: state.badgesList.length,
            itemBuilder: (ctx, idx) {
              final badge = state.badgesList[idx];
              final isUnlocked = badge['is_unlocked'] == true;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked ? const Color(0xFF86EFAC) : AppColors.borderLight,
                    width: isUnlocked ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          badge['icon'] ?? '🏅',
                          style: TextStyle(
                            fontSize: TrophyRoomSizes.heroTitleFontSize,
                            color: isUnlocked ? null : Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isUnlocked ? (state.isArabic ? 'مكتمل ✓' : 'Unlocked') : (state.isArabic ? 'مغلق 🔒' : 'Locked'),
                            style: AppTypography.labelSm(
                              color: isUnlocked ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            ).copyWith(fontSize: TrophyRoomSizes.microFontSize),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      badge['title'] ?? '',
                      style: AppTypography.labelSm(
                        color: isUnlocked ? AppColors.onSurface : AppColors.outline,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge['desc'] ?? '',
                      style: AppTypography.bodySm(
                        color: isUnlocked ? AppColors.onSurfaceVariant : AppColors.outline,
                      ).copyWith(fontSize: TrophyRoomSizes.badgeFontSize),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityView(BuildContext context, AppState state) {
    return Container(
      padding: EdgeInsets.all(TrophyRoomSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(TrophyRoomSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: TrophyRoomSizes.activityIconSize),
                    SizedBox(width: TrophyRoomSizes.spacingInlineSm),
                    Expanded(
                      child: Text(
                        state.isArabic ? 'سجل الأنشطة والتمارين' : 'Recent Learning Activity',
                        style: AppTypography.getLexend(
                          fontSize: TrophyRoomSizes.activityTitleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.activityLogs.length} ${state.isArabic ? 'عملية' : 'Records'}',
                  style: AppTypography.labelSm().copyWith(fontSize: TrophyRoomSizes.activityBadgeFontSize),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (state.activityLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off_rounded, size: 40, color: AppColors.outline),
                  const SizedBox(height: 8),
                  Text(
                    state.isArabic
                        ? 'لا توجد جلسات مسجلة بعد. عند إتمام أول جلسة قراءة أو حساب، ستظهر تفاصيلها في هذا السجل.'
                        : 'No activity recorded yet. Complete reading and math sessions to see your live chronological log here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.activityLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderLight),
              itemBuilder: (ctx, idx) {
                final log = state.activityLogs[idx];
                final isMath = log['type'] == 'math';
                final rawScore = (log['score'] as String?) ?? '';
                final localizedScore = state.isArabic
                    ? (rawScore == 'Mastered'
                        ? 'متقن'
                        : (rawScore == 'Completed'
                            ? 'مكتمل'
                            : rawScore.replaceAll('WPM', 'ك/د')))
                    : rawScore;

                return Row(
                  children: [
                    Container(
                      width: TrophyRoomSizes.activityItemIconBoxSize,
                      height: TrophyRoomSizes.activityItemIconBoxSize,
                      decoration: BoxDecoration(
                        color: isMath ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isMath ? Icons.calculate_rounded : Icons.menu_book_rounded,
                        color: isMath ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                        size: TrophyRoomSizes.activityItemIconSize,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (state.isArabic ? log['title_ar'] : log['title']) ?? '',
                            style: AppTypography.labelMd(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (state.isArabic ? log['subtitle_ar'] : log['subtitle']) ?? '',
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)
                                .copyWith(fontSize: TrophyRoomSizes.activitySubtitleFontSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMath ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        localizedScore,
                        style: AppTypography.labelSm(
                          color: isMath ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: TrophyRoomSizes.activityScoreFontSize),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChestCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFFFECEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.sunnyYellow,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: AppColors.yellowShadow, offset: Offset(0, 2), blurRadius: 0),
              ],
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.onTertiaryFixed, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.isArabic ? 'جاهز للفتح' : 'READY TO UNLOCK',
                  style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                    fontSize: TrophyRoomSizes.badgeFontSize,
                    letterSpacing: 0.05,
                  ),
                ),
                Text(
                  state.tr('weekly_chest_title'),
                  style: AppTypography.labelMd(),
                ),
                Text(
                  state.tr('weekly_chest_sub'),
                  style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
                    fontSize: TrophyRoomSizes.captionFontSize,
                  ),
                ),
              ],
            ),
          ),
          TactileButton(
            label: _isChestOpened ? (state.isArabic ? 'تم الفتح ✓' : 'Opened ✓') : state.tr('btn_open_gift'),
            variant: TactileButtonVariant.secondary,
            height: 44,
            borderRadius: 16,
            onPressed: _isChestOpened
                ? null
                : () async {
                    setState(() => _isChestOpened = true);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('weekly_chest_opened', true);
                    state.addReward(starsToAdd: 50, xpToAdd: 50);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.isArabic
                                ? '🎉 رائع جداً! حصلت على +50 نجمة ونقطة وتم فتح صندوق المستكشف!'
                                : '🎉 Awesome! +50 Stars & XP Unlocked!',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
