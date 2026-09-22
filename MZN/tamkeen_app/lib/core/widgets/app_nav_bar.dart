import 'package:flutter/material.dart';
import 'package:flutter_intro/flutter_intro.dart';
import 'package:provider/provider.dart';
import '../services/intro_tour_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_nav_bar_sizes.dart';

class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final items = [
      (Icons.explore_outlined, Icons.explore, state.tr('nav_adventure')),
      (Icons.menu_book_outlined, Icons.menu_book, state.tr('nav_reading')),
      (Icons.calculate_outlined, Icons.calculate, state.tr('nav_math')),
      (Icons.military_tech_outlined, Icons.military_tech, state.tr('nav_trophies')),
      (Icons.shield_outlined, Icons.shield, state.tr('nav_guardian')),
    ];

    const tourIcons = [
      Icons.explore_rounded,
      Icons.auto_stories_rounded,
      Icons.calculate_rounded,
      Icons.military_tech_rounded,
      Icons.shield_rounded,
    ];

    const tourColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.periwinkle,
      Color(0xFF2563EB),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: AppNavBarSizes.paddingTop,
        bottom: MediaQuery.of(context).padding.bottom + 6,
        left: AppNavBarSizes.paddingHorizontal,
        right: AppNavBarSizes.paddingHorizontal,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = state.currentTabIndex == index;
          final item = items[index];
          final stepOrder = 5 + index;

          return Expanded(
            child: IntroStepBuilder(
              order: stepOrder,
              getOverlayPosition: IntroTourService.getOverlayPosition,
              overlayBuilder: (params) => IntroTourService.buildStepCard(
                params: params,
                order: stepOrder,
                icon: tourIcons[index],
                accentColor: tourColors[index],
              ),
              builder: (context, key) => InkWell(
                key: key,
                onTap: () => state.setTabIndex(index),
                borderRadius: BorderRadius.circular(AppNavBarSizes.itemRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(vertical: AppNavBarSizes.itemPaddingV),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryFixed.withValues(alpha: 0.35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppNavBarSizes.itemRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.$2 : item.$1,
                        size: AppNavBarSizes.iconSize,
                        color: isSelected ? AppColors.primary : AppColors.outline,
                      ),
                      SizedBox(height: AppNavBarSizes.spacingIconText),
                      Text(
                        item.$3,
                        style: AppTypography.labelSm(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ).copyWith(
                          fontSize: isSelected
                              ? AppNavBarSizes.activeLabelFontSize
                              : AppNavBarSizes.labelFontSize,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
