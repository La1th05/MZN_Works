import 'package:flutter/material.dart';
import 'package:flutter_intro/flutter_intro.dart';
import 'package:provider/provider.dart';
import '../services/intro_tour_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'top_header_bar_sizes.dart';

class TopHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const TopHeaderBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(TopHeaderBarSizes.preferredHeight);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: AppColors.surface.withValues(alpha: 0.96),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: TopHeaderBarSizes.bottomPadding,
        left: TopHeaderBarSizes.horizontalPadding,
        right: TopHeaderBarSizes.horizontalPadding,
      ),
      child: Row(
        children: [
          // Left Section: Logo, Title, and Language Switcher
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(TopHeaderBarSizes.logoRadius),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: TopHeaderBarSizes.logoSize,
                    width: TopHeaderBarSizes.logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: TopHeaderBarSizes.logoSize,
                      width: TopHeaderBarSizes.logoSize,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(TopHeaderBarSizes.logoRadius),
                      ),
                      child: Icon(Icons.school, color: Colors.white, size: TopHeaderBarSizes.logoIconSize),
                    ),
                  ),
                ),
                SizedBox(width: TopHeaderBarSizes.spacingXs),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.tr('app_title'),
                        style: AppTypography.getLexend(
                          fontSize: TopHeaderBarSizes.appTitleFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        state.isArabic ? 'تمكين' : 'Tamkeen',
                        style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
                          fontSize: TopHeaderBarSizes.appSubtitleFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: TopHeaderBarSizes.spacingXs),
                // Language Switcher Button (Intro Step 1)
                IntroStepBuilder(
                  order: 1,
                  getOverlayPosition: IntroTourService.getOverlayPosition,
                  overlayBuilder: (params) => IntroTourService.buildStepCard(
                    params: params,
                    order: 1,
                    icon: Icons.language_rounded,
                    accentColor: AppColors.primary,
                  ),
                  builder: (context, key) => GestureDetector(
                    key: key,
                    onTap: () => state.toggleLanguage(),
                    child: Container(
                      height: TopHeaderBarSizes.langButtonHeight,
                      padding: EdgeInsets.symmetric(horizontal: TopHeaderBarSizes.langButtonPaddingH),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(TopHeaderBarSizes.langButtonRadius),
                        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.outlineVariant,
                            offset: Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        state.isArabic ? 'العربية' : 'English',
                        style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                          fontSize: TopHeaderBarSizes.langButtonFontSize,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: TopHeaderBarSizes.spacingXs),
                // Interactive Tour Help Button
                GestureDetector(
                  onTap: () => IntroTourService.startTour(context),
                  child: Container(
                    height: TopHeaderBarSizes.langButtonHeight,
                    width: TopHeaderBarSizes.langButtonHeight,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.outlineVariant,
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: TopHeaderBarSizes.spacingXs),

          // Gamified Stat Badges (Streak, Stars, Diamonds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Streak Flame (Intro Step 2)
              IntroStepBuilder(
                order: 2,
                getOverlayPosition: IntroTourService.getOverlayPosition,
                overlayBuilder: (params) => IntroTourService.buildStepCard(
                  params: params,
                  order: 2,
                  icon: Icons.local_fire_department_rounded,
                  accentColor: AppColors.secondaryContainer,
                ),
                builder: (context, key) => _buildStatBadge(
                  key: key,
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.secondaryContainer,
                  text: '${state.streakDays}',
                  bgColor: AppColors.surfaceContainerLowest,
                  shadowColor: AppColors.surfaceDim,
                ),
              ),
              SizedBox(width: TopHeaderBarSizes.badgeSpacing),

              // Stars Badge (Intro Step 3)
              IntroStepBuilder(
                order: 3,
                getOverlayPosition: IntroTourService.getOverlayPosition,
                overlayBuilder: (params) => IntroTourService.buildStepCard(
                  params: params,
                  order: 3,
                  icon: Icons.star_rounded,
                  accentColor: AppColors.tertiary,
                ),
                builder: (context, key) => _buildStatBadge(
                  key: key,
                  icon: Icons.star,
                  iconColor: AppColors.tertiary,
                  text: '${state.stars}',
                  bgColor: AppColors.tertiaryFixed,
                  shadowColor: AppColors.yellowShadow,
                  textColor: AppColors.onTertiaryFixed,
                ),
              ),
              SizedBox(width: TopHeaderBarSizes.badgeSpacing),

              // Avatar with Level pill (Intro Step 4)
              IntroStepBuilder(
                order: 4,
                getOverlayPosition: IntroTourService.getOverlayPosition,
                overlayBuilder: (params) => IntroTourService.buildStepCard(
                  params: params,
                  order: 4,
                  icon: Icons.person_rounded,
                  accentColor: AppColors.primary,
                ),
                builder: (context, key) => GestureDetector(
                  key: key,
                  onTap: () => _showUserModal(context, state),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: TopHeaderBarSizes.avatarSize,
                        height: TopHeaderBarSizes.avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.white, width: TopHeaderBarSizes.avatarBorderWidth),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/avatar.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              color: Colors.white,
                              size: TopHeaderBarSizes.avatarIconSize,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: TopHeaderBarSizes.levelPillPaddingH,
                            vertical: TopHeaderBarSizes.levelPillPaddingV,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(TopHeaderBarSizes.levelPillRadius),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            state.isArabic ? 'مستوى ${state.level}' : 'Lv.${state.level}',
                            style: AppTypography.getLexend(
                              fontSize: TopHeaderBarSizes.levelPillFontSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserModal(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.all(TopHeaderBarSizes.modalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: TopHeaderBarSizes.modalHandleWidth,
                height: TopHeaderBarSizes.modalHandleHeight,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: TopHeaderBarSizes.modalAvatarRadius,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.person, color: Colors.white, size: TopHeaderBarSizes.modalAvatarIconSize),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.studentName,
                          style: AppTypography.headlineSm(),
                        ),
                        Text(
                          state.isArabic
                              ? '${state.userRole == 'Student' ? 'طالب' : (state.userRole == 'Parent' || state.userRole == 'Guardian' ? 'ولي أمر' : state.userRole)} • المستوى ${state.level}'
                              : '${state.userRole} • Level ${state.level}',
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              state.isArabic
                                  ? 'متصل بالسحابة: ${state.currentProfileId.isNotEmpty ? state.currentProfileId.substring(0, state.currentProfileId.length > 8 ? 8 : state.currentProfileId.length) : ''}...'
                                  : 'Cloud Connected: ${state.currentProfileId.isNotEmpty ? state.currentProfileId.substring(0, state.currentProfileId.length > 8 ? 8 : state.currentProfileId.length) : ''}...',
                              style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Global Font Size Controller
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.format_size_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.tr('font_size'),
                            style: AppTypography.labelMd().copyWith(
                              fontSize: TopHeaderBarSizes.modalOptionTitleFontSize,
                            ),
                          ),
                          Text(
                            state.fontSizeDelta == 0
                                ? state.tr('font_size_standard')
                                : (state.fontSizeDelta > 0
                                    ? '${state.tr('font_size_large')} (+${state.fontSizeDelta.toInt()})'
                                    : '${state.tr('font_size_small')} (${state.fontSizeDelta.toInt()})'),
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
                              fontSize: TopHeaderBarSizes.modalOptionSubFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // A- Button
                    IconButton.filledTonal(
                      onPressed: state.fontSizeDelta > -4.0 ? () => state.decreaseFontSize() : null,
                      icon: Text(state.isArabic ? 'أ-' : 'A-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      tooltip: state.tr('font_size_decrease'),
                    ),
                    const SizedBox(width: 4),
                    // A+ Button
                    IconButton.filled(
                      onPressed: state.fontSizeDelta < 8.0 ? () => state.increaseFontSize() : null,
                      icon: Text(state.isArabic ? 'أ+' : 'A+', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      tooltip: state.tr('font_size_increase'),
                    ),
                  ],
                ),
              ),

              // Switch Account / Logout Option -> Managed securely in Guardian Dashboard
              ListTile(
                leading: const Icon(Icons.shield_outlined, color: AppColors.primary),
                title: Text(
                  state.isArabic ? 'إدارة الحساب وتسجيل الخروج' : 'Account & Log Out',
                  style: AppTypography.labelMd().copyWith(
                    fontSize: TopHeaderBarSizes.modalOptionTitleFontSize,
                  ),
                ),
                subtitle: Text(
                  state.isArabic ? 'متاحة بأمان داخل لوحة تحكم ولي الأمر' : 'Available securely in Guardian Dashboard',
                  style: AppTypography.bodySm().copyWith(
                    fontSize: TopHeaderBarSizes.modalOptionSubFontSize,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  state.setTabIndex(4); // Navigate to Guardian Dashboard
                },
              ),

              // Tour Guide Option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.help_outline_rounded, color: AppColors.primary),
                ),
                title: Text(
                  state.tr('tour_guide_tooltip'),
                  style: AppTypography.labelMd().copyWith(
                    fontSize: TopHeaderBarSizes.modalOptionTitleFontSize,
                  ),
                ),
                subtitle: Text(
                  state.isArabic ? 'بدء الجولة الإرشادية التفاعلية لشرح التطبيق' : 'Start interactive tour explaining all features',
                  style: AppTypography.bodySm().copyWith(
                    fontSize: TopHeaderBarSizes.modalOptionSubFontSize,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  IntroTourService.startTour(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFECEB),
                  child: Icon(Icons.logout_rounded, color: AppColors.secondary),
                ),
                title: Text(state.tr('logout'), style: AppTypography.labelMd()),
                subtitle: Text(
                  state.isArabic ? 'العودة لشاشة الدخول' : 'Return to login screen',
                  style: AppTypography.bodySm().copyWith(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  state.logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBadge({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color bgColor,
    required Color shadowColor,
    Color textColor = AppColors.onSurface,
  }) {
    return Container(
      key: key,
      height: TopHeaderBarSizes.badgeHeight,
      padding: EdgeInsets.symmetric(horizontal: TopHeaderBarSizes.badgePaddingH),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(TopHeaderBarSizes.badgeRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: TopHeaderBarSizes.badgeIconSize),
          SizedBox(width: TopHeaderBarSizes.badgeSpacing),
          Text(
            text,
            style: AppTypography.labelMd(color: textColor),
          ),
        ],
      ),
    );
  }
}
