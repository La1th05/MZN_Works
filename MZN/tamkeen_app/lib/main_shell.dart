import 'package:flutter/material.dart';
import 'package:flutter_intro/flutter_intro.dart';
import 'package:provider/provider.dart';
import 'core/services/intro_tour_service.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_nav_bar.dart';
import 'core/widgets/top_header_bar.dart';
import 'features/adventure_map/presentation/screens/adventure_map_screen.dart';
import 'features/dyslexia_reading/presentation/screens/reading_arena_screen.dart';
import 'features/dyscalculia_math/presentation/screens/math_equation_lab_screen.dart';
import 'features/trophies_skill_tree/presentation/screens/trophy_room_screen.dart';
import 'features/guardian_dashboard/presentation/screens/guardian_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final Widget _introShell;

  @override
  void initState() {
    super.initState();
    // Maintain a single persistent instance of Intro so its internal _stepsMap
    // is never erased or reset when child widgets or AppState rebuilds.
    _introShell = Intro(
      maskColor: Colors.black.withValues(alpha: 0.70),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: const _MainShellContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _introShell;
  }
}

class _MainShellContent extends StatefulWidget {
  const _MainShellContent();

  @override
  State<_MainShellContent> createState() => _MainShellContentState();
}

class _MainShellContentState extends State<_MainShellContent> {
  bool _hasCheckedTour = false;

  void _checkFirstLaunch(BuildContext introContext) async {
    if (_hasCheckedTour) return;
    _hasCheckedTour = true;
    final state = Provider.of<AppState>(introContext, listen: false);
    final profileId = state.currentProfileId;
    final completed = await IntroTourService.hasCompletedTour(profileId);
    debugPrint('[MainShell] _checkFirstLaunch: profileId=$profileId, completed=$completed, shouldAutoStart=${state.shouldAutoStartIntro}');

    if ((!completed || state.shouldAutoStartIntro) && mounted) {
      // Delay to ensure all 9 IntroStepBuilder widgets are completely mounted and laid out
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && introContext.mounted) {
        state.markIntroStarted();
        IntroTourService.startTour(introContext);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final screens = const [
      AdventureMapScreen(),
      ReadingArenaScreen(),
      MathEquationLabScreen(),
      TrophyRoomScreen(),
      GuardianDashboardScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch(context);
    });

    return Directionality(
      textDirection: state.textDirection,
      child: Scaffold(
        appBar: const TopHeaderBar(),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: state.currentTabIndex,
            children: screens,
          ),
        ),
        bottomNavigationBar: const AppNavBar(),
      ),
    );
  }
}
