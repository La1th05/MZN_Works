import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';
import '../services/intro_tour_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_typography.dart';

class AppState extends ChangeNotifier {
  AppState() {
    initFromStorage();
  }

  // Authentication & Current User Profile
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String _currentProfileId = '';
  String get currentProfileId => _currentProfileId;

  String _studentName = '';
  String get studentName => _studentName;

  String _userRole = 'Student';
  String get userRole => _userRole;

  // Intro Tour Auto-start triggers
  bool _shouldAutoStartIntro = false;
  bool get shouldAutoStartIntro => _shouldAutoStartIntro;

  bool _isNewAccount = false;
  bool get isNewAccount => _isNewAccount;

  void markIntroStarted() {
    _shouldAutoStartIntro = false;
  }

  // Localization
  String _language = 'ar'; // Default is Arabic ('ar')
  String get language => _language;
  bool get isArabic => _language == 'ar';
  TextDirection get textDirection => isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> toggleLanguage() async {
    _language = _language == 'en' ? 'ar' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _language);
    notifyListeners();
  }

  String tr(String key) => AppStrings.get(key, _language);

  // Session Persistence Helpers
  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_is_authenticated', true);
    await prefs.setString('session_profile_id', _currentProfileId);
    await prefs.setString('session_student_name', _studentName);
    await prefs.setString('session_user_role', _userRole);
    await prefs.setInt('session_stars', _stars);
    await prefs.setInt('session_level', _level);
    await prefs.setInt('session_xp', _currentXp);
    await prefs.setInt('session_streak_days', _streakDays);
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_is_authenticated');
    await prefs.remove('session_profile_id');
    await prefs.remove('session_student_name');
    await prefs.remove('session_user_role');
    await prefs.remove('session_stars');
    await prefs.remove('session_level');
    await prefs.remove('session_xp');
    await prefs.remove('session_streak_days');
  }

  // Authentication Actions
  Future<void> switchProfile({
    required String profileId,
    required String name,
    required int stars,
    required String role,
    int level = 1,
    int xp = 0,
    int streakDays = 1,
  }) async {
    _currentProfileId = profileId;
    _studentName = name;
    _stars = stars;
    _userRole = role;
    _level = level;
    _currentXp = xp;
    _streakDays = streakDays;
    _isAuthenticated = true;

    final tourCompleted = await IntroTourService.hasCompletedTour(profileId);
    if (!tourCompleted) {
      _shouldAutoStartIntro = true;
    }

    await _persistSession();
    await initFromStorage();
    notifyListeners();
  }

  Future<String?> loginWithEmail({required String email, required String password}) async {
    final profile = await SupabaseService.getProfileByEmail(email);
    if (profile == null) {
      return 'user_not_found';
    }
    final dbPass = profile['password']?.toString() ?? '';
    if (dbPass.isNotEmpty && dbPass != password.trim()) {
      return 'wrong_password';
    }

    final profileId = profile['id'] ?? '';
    final tourCompleted = await IntroTourService.hasCompletedTour(profileId);
    if (!tourCompleted) {
      _shouldAutoStartIntro = true;
    }

    await switchProfile(
      profileId: profileId,
      name: profile['student_name'] ?? (isArabic ? 'المتعلم' : 'Learner'),
      stars: profile['stars'] ?? 0,
      role: profile['role'] ?? 'Student',
      level: profile['level'] ?? 1,
      xp: profile['xp'] ?? 0,
      streakDays: profile['streak_days'] ?? 1,
    );
    return null; // success
  }

  Future<void> registerAndLogin({
    required String name,
    required String email,
    required String role,
    required String password,
  }) async {
    final profile = await SupabaseService.registerNewProfile(
      studentName: name,
      email: email,
      role: role,
      password: password,
    );

    _currentProfileId = profile['id'];
    _studentName = name;
    _userRole = role;
    _stars = 0;
    _currentXp = 0;
    _level = 1;
    _streakDays = 1;
    _isAuthenticated = true;
    _isNewAccount = true;
    _shouldAutoStartIntro = true;

    // Reset tour preference so intro starts immediately for this new learner account
    await IntroTourService.resetTourPreferenceForProfile(_currentProfileId);

    await _persistSession();
    await initFromStorage();
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _currentProfileId = '';
    _studentName = '';
    _userRole = 'Student';
    _currentTabIndex = 0;
    _shouldAutoStartIntro = false;
    _isNewAccount = false;
    await _clearPersistedSession();
    notifyListeners();
  }

  // Navigation
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // Gamification & Player Progress (Dynamic from DB / Starts Clean)
  int _stars = 0;
  int get stars => _stars;

  int _gems = 0;
  int get gems => _gems;

  int _streakDays = 1;
  int get streakDays => _streakDays;

  int _currentXp = 0;
  int get currentXp => _currentXp;
  final int _maxXp = 100;
  int get maxXp => _maxXp;

  int _level = 1;
  int get level => _level;

  // Persistent Stage Progression
  Map<int, Map<String, dynamic>> _stages = {
    12: {'status': 'active', 'stars': 0},
    13: {'status': 'locked', 'stars': 0},
    14: {'status': 'locked', 'stars': 0},
    15: {'status': 'locked', 'stars': 0},
    16: {'status': 'locked', 'stars': 0},
    17: {'status': 'locked', 'stars': 0},
    18: {'status': 'locked', 'stars': 0},
  };
  Map<int, Map<String, dynamic>> get stages => _stages;

  int? _selectedReadingStageId;
  int get activeReadingStageId {
    if (_selectedReadingStageId != null &&
        _stages.containsKey(_selectedReadingStageId) &&
        _stages[_selectedReadingStageId]?['status'] != 'locked') {
      return _selectedReadingStageId!;
    }
    for (int id in [12, 13, 14]) {
      if (_stages[id]?['status'] == 'active') return id;
    }
    for (int id in [14, 13, 12]) {
      if (_stages[id]?['status'] == 'completed') return id;
    }
    return 12;
  }

  void setSelectedReadingStageId(int id) {
    if (_stages[id]?['status'] != 'locked') {
      _selectedReadingStageId = id;
      notifyListeners();
    }
  }

  int? _selectedMathStageId;
  int get activeMathStageId {
    if (_selectedMathStageId != null &&
        _stages.containsKey(_selectedMathStageId) &&
        _stages[_selectedMathStageId]?['status'] != 'locked') {
      return _selectedMathStageId!;
    }
    for (int id in [15, 16, 17, 18]) {
      if (_stages[id]?['status'] == 'active') return id;
    }
    for (int id in [18, 17, 16, 15]) {
      if (_stages[id]?['status'] == 'completed') return id;
    }
    return 15;
  }

  void setSelectedMathStageId(int id) {
    if (_stages[id]?['status'] != 'locked') {
      _selectedMathStageId = id;
      notifyListeners();
    }
  }

  // Live Telemetry from Supabase (Pure Database Real-Time)
  bool _hasAnalyticsData = false;
  bool get hasAnalyticsData => _hasAnalyticsData;

  int _frustrationPercent = 0;
  int get frustrationPercent => _frustrationPercent;

  int _focusPercent = 100;
  int get focusPercent => _focusPercent;

  double _pyBktMastery = 0.0;
  double get pyBktMastery => _pyBktMastery;

  double _avgReadingAccuracy = 0.0;
  double get avgReadingAccuracy => _avgReadingAccuracy;

  int _avgWpm = 0;
  int get avgWpm => _avgWpm;

  int _readingSessionsCount = 0;
  int get readingSessionsCount => _readingSessionsCount;

  int _mathSessionsCount = 0;
  int get mathSessionsCount => _mathSessionsCount;

  int _totalSessionsCount = 0;
  int get totalSessionsCount => _totalSessionsCount;

  double _substitutionsPct = 0.0;
  double get substitutionsPct => _substitutionsPct;

  double _hesitationsPct = 0.0;
  double get hesitationsPct => _hesitationsPct;

  double _omissionsPct = 0.0;
  double get omissionsPct => _omissionsPct;

  String _phoneticNotes = '';
  String get phoneticNotes => _phoneticNotes;

  Map<String, Map<String, dynamic>> _mathSkillsBreakdown = {
    'single_addition': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
    'tens_regrouping': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
    'number_line': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
    'multi_step': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
  };
  Map<String, Map<String, dynamic>> get mathSkillsBreakdown => _mathSkillsBreakdown;

  int _selectedDateFilterIndex = 0; // 0: This Week, 1: Last 30 Days, 2: All Time
  int get selectedDateFilterIndex => _selectedDateFilterIndex;

  List<Map<String, dynamic>> _wpmPoints = [];
  List<Map<String, dynamic>> get wpmPoints => _wpmPoints;

  List<Map<String, dynamic>> _skillsMastery = [];
  List<Map<String, dynamic>> get skillsMastery => _skillsMastery;

  List<Map<String, dynamic>> _activityLogs = [];
  List<Map<String, dynamic>> get activityLogs => _activityLogs;

  int get unlockedBadgesCount => badgesList.where((b) => b['is_unlocked'] == true).length;

  List<Map<String, dynamic>> get badgesList {
    return [
      {
        'id': 'first_steps',
        'title': isArabic ? 'الخطوة الأولى' : 'First Steps',
        'desc': isArabic ? 'أكملت أول مرحلة في خريطة المغامرة' : 'Completed your first adventure stage',
        'icon': '🌟',
        'is_unlocked': _stages[12]?['status'] == 'completed' || _level >= 1,
        'category': 'adventure',
      },
      {
        'id': 'voice_explorer',
        'title': isArabic ? 'مستكشف الصوت' : 'Voice Explorer',
        'desc': isArabic ? 'أكملت جلسة قراءة صوتية بالذكاء الاصطناعي' : 'Completed an AI acoustic reading session',
        'icon': '🎙️',
        'is_unlocked': _readingSessionsCount > 0 || _stages[12]?['status'] == 'completed',
        'category': 'reading',
      },
      {
        'id': 'math_prodigy',
        'title': isArabic ? 'عبقري الحساب' : 'Math Prodigy',
        'desc': isArabic ? 'حققت أكثر من 80% في نموذج تتبع المعرفة' : 'Achieved >80% PyBKT latent mastery',
        'icon': '⚡',
        'is_unlocked': _pyBktMastery >= 0.8 || _mathSessionsCount > 0,
        'category': 'math',
      },
      {
        'id': 'sharp_scribe',
        'title': isArabic ? 'الكاتب البارع' : 'Sharp Scribe',
        'desc': isArabic ? 'تجاوزت بنجاح اختبار دقة الرسم والكتابة' : 'Passed handwriting precision challenges',
        'icon': '🎯',
        'is_unlocked': _level >= 2 || _stars >= 100,
        'category': 'precision',
      },
      {
        'id': 'streak_champion',
        'title': isArabic ? 'بطل الاستمرارية' : 'Consistent Champion',
        'desc': isArabic ? 'حافظت على سلسلة تعلم نشطة' : 'Maintained an active daily learning streak',
        'icon': '🔥',
        'is_unlocked': _streakDays >= 1,
        'category': 'streak',
      },
      {
        'id': 'equation_hunter',
        'title': isArabic ? 'صائد المعادلات' : 'Equation Hunter',
        'desc': isArabic ? 'أتقنت حل المعادلات وحساب المقادير' : 'Mastered arithmetic equation solving',
        'icon': '🛡️',
        'is_unlocked': _mathSessionsCount >= 3 || _level >= 3,
        'category': 'math',
      },
      {
        'id': 'wisdom_master',
        'title': isArabic ? 'سيد الحكمة' : 'Wisdom Master',
        'desc': isArabic ? 'وصلت إلى المستوى 4 أو أعلى' : 'Reached Explorer Level 4 or higher',
        'icon': '👑',
        'is_unlocked': _level >= 4,
        'category': 'level',
      },
      {
        'id': 'crystal_collector',
        'title': isArabic ? 'جامع البلورات' : 'Crystal Collector',
        'desc': isArabic ? 'جمعت أكثر من 500 نجمة' : 'Accumulated over 500 stars',
        'icon': '💎',
        'is_unlocked': _stars >= 500,
        'category': 'reward',
      },
      {
        'id': 'pybkt_adept',
        'title': isArabic ? 'خبير تتبع المعرفة' : 'PyBKT Adept',
        'desc': isArabic ? 'تم تتبع المعرفة والتمكن المعرفي بنجاح' : 'PyBKT Knowledge Tracing fully calibrated',
        'icon': '🔮',
        'is_unlocked': _mathSessionsCount >= 5,
        'category': 'ai',
      },
      {
        'id': 'speed_reader',
        'title': isArabic ? 'قارئ سريع' : 'Speed Reader',
        'desc': isArabic ? 'حققت سرعة قراءة أعلى من 75 كلمة/دقيقة' : 'Achieved >75 WPM reading speed',
        'icon': '🚀',
        'is_unlocked': _wpmPoints.any((p) => ((p['wpm'] as num?)?.toInt() ?? 0) >= 75) || _readingSessionsCount >= 2,
        'category': 'reading',
      },
      {
        'id': 'cartographer',
        'title': isArabic ? 'رسم الخرائط' : 'Cartographer',
        'desc': isArabic ? 'فتحت جسر الحبال إلى قلعة الأرقام' : 'Unlocked the Rope Bridge to Citadel of Numbers',
        'icon': '🧭',
        'is_unlocked': _stages[15]?['status'] != 'locked' || _level >= 4,
        'category': 'adventure',
      },
      {
        'id': 'word_master',
        'title': isArabic ? 'سيد الكلمات' : 'Word Master',
        'desc': isArabic ? 'أتقنت نطق ومفردات عالم الكلمات' : 'Mastered vocabulary and phonetic glades',
        'icon': '📖',
        'is_unlocked': _stages[14]?['status'] == 'completed' || _readingSessionsCount >= 4,
        'category': 'reading',
      },
      {
        'id': 'tamkeen_grandmaster',
        'title': isArabic ? 'بطل تمكين الأكبر' : 'Tamkeen Grandmaster',
        'desc': isArabic ? 'أتممت جميع المراحل من 12 إلى 18' : 'Complete all adventure stages from 12 to 18',
        'icon': '🏆',
        'is_unlocked': _stages.values.every((s) => s['status'] == 'completed'),
        'category': 'mastery',
      },
      {
        'id': 'geometry_quest',
        'title': isArabic ? 'مستكشف الهندسة' : 'Geometry Quest',
        'desc': isArabic ? 'يفتح عند الوصول للمستوى 8' : 'Unlocks upon reaching Level 8',
        'icon': '📐',
        'is_unlocked': _level >= 8,
        'category': 'math',
      },
    ];
  }

  Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language');
    if (savedLang != null && (savedLang == 'ar' || savedLang == 'en')) {
      _language = savedLang;
    }
    final savedFontDelta = prefs.getDouble('app_font_size_delta');
    if (savedFontDelta != null) {
      _fontSizeDelta = savedFontDelta;
      AppTypography.setFontDelta(_fontSizeDelta);
    }

    // Restore saved authenticated session
    final isSavedAuth = prefs.getBool('session_is_authenticated') ?? false;
    final savedProfileId = prefs.getString('session_profile_id');
    if (isSavedAuth && savedProfileId != null && savedProfileId.isNotEmpty) {
      _isAuthenticated = true;
      _currentProfileId = savedProfileId;
      _studentName = prefs.getString('session_student_name') ?? _studentName;
      _userRole = prefs.getString('session_user_role') ?? _userRole;
      _stars = prefs.getInt('session_stars') ?? _stars;
      _level = prefs.getInt('session_level') ?? _level;
      _currentXp = prefs.getInt('session_xp') ?? _currentXp;
      _streakDays = prefs.getInt('session_streak_days') ?? _streakDays;

      final tourCompleted = await IntroTourService.hasCompletedTour(_currentProfileId);
      if (!tourCompleted) {
        _shouldAutoStartIntro = true;
      }
    }

    if (_currentProfileId.isNotEmpty) {
      final savedLevel = prefs.getInt('${_currentProfileId}_level');
      if (savedLevel != null && savedLevel > 0) _level = savedLevel;
      final savedXp = prefs.getInt('${_currentProfileId}_xp');
      if (savedXp != null && savedXp >= 0) _currentXp = savedXp;
      final savedStars = prefs.getInt('${_currentProfileId}_stars');
      if (savedStars != null && savedStars >= 0) _stars = savedStars;

      final loadedStages = await SupabaseService.loadStagesProgress(profileId: _currentProfileId);
      if (loadedStages.isNotEmpty) {
        _stages = loadedStages;
      }
      await refreshAnalytics();
      _skillsMastery = await SupabaseService.fetchSkillMastery(profileId: _currentProfileId);
      _activityLogs = await SupabaseService.fetchRecentActivityLogs(profileId: _currentProfileId);
    }
    notifyListeners();
  }

  Future<void> setDateFilter(int index) async {
    _selectedDateFilterIndex = index;
    notifyListeners();
    await refreshAnalytics();
  }

  Future<void> refreshAnalytics() async {
    if (_currentProfileId.isEmpty) return;
    int daysWindow = 0;
    if (_selectedDateFilterIndex == 0) {
      daysWindow = 7; // This Week
    } else if (_selectedDateFilterIndex == 1) {
      daysWindow = 30; // Last 30 Days
    } else {
      daysWindow = 0; // All Time
    }

    final analytics = await SupabaseService.fetchLiveAnalytics(
      profileId: _currentProfileId,
      daysWindow: daysWindow,
    );

    _hasAnalyticsData = analytics['has_data'] == true;
    _frustrationPercent = analytics['frustration_percent'] ?? 0;
    _focusPercent = analytics['focus_percent'] ?? 100;
    _pyBktMastery = (analytics['pybkt_mastery'] as num?)?.toDouble() ?? 0.0;
    _avgReadingAccuracy = (analytics['avg_accuracy'] as num?)?.toDouble() ?? 0.0;
    _avgWpm = analytics['avg_wpm'] ?? 0;
    _readingSessionsCount = analytics['reading_count'] ?? 0;
    _mathSessionsCount = analytics['math_count'] ?? 0;
    _totalSessionsCount = analytics['total_sessions'] ?? 0;

    _substitutionsPct = (analytics['substitutions_pct'] as num?)?.toDouble() ?? 0.0;
    _hesitationsPct = (analytics['hesitations_pct'] as num?)?.toDouble() ?? 0.0;
    _omissionsPct = (analytics['omissions_pct'] as num?)?.toDouble() ?? 0.0;
    _phoneticNotes = (analytics['phonetic_notes'] ?? '').toString();

    if (analytics['wpm_points'] != null) {
      _wpmPoints = List<Map<String, dynamic>>.from(analytics['wpm_points']);
    } else {
      _wpmPoints = [];
    }

    if (analytics['math_skills_breakdown'] != null) {
      _mathSkillsBreakdown = Map<String, Map<String, dynamic>>.from(analytics['math_skills_breakdown']);
    }

    notifyListeners();
  }

  void addReward({int starsToAdd = 50, int xpToAdd = 100}) {
    _stars = (_stars + starsToAdd).clamp(0, 999999);
    _currentXp += xpToAdd;
    while (_currentXp >= _maxXp) {
      _level += 1;
      _currentXp -= _maxXp;
    }
    if (_currentXp < 0) _currentXp = 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>> completeStage(int stageId, {int starsEarned = 3, int nextStageId = 15}) async {
    final prevStatus = _stages[stageId]?['status'];
    final prevStars = (_stages[stageId]?['stars'] as num?)?.toInt() ?? 0;
    final isFirstCompletion = prevStatus != 'completed';

    // Set new stars rating for this stage:
    _stages[stageId] = {'status': 'completed', 'stars': starsEarned};

    // Unlock next stage ONLY if it was locked:
    if (_stages.containsKey(nextStageId) && _stages[nextStageId]?['status'] == 'locked') {
      _stages[nextStageId] = {'status': 'active', 'stars': 0};
    }

    int starsDelta = 0;
    int xpDelta = 0;

    if (isFirstCompletion) {
      // First completion: Full reward awarded once + Level advancement
      starsDelta = 50 + (starsEarned * 10);
      xpDelta = 100; // Advancing a stage grants 100 XP -> raises level!
      addReward(starsToAdd: starsDelta, xpToAdd: xpDelta);
    } else {
      // Replaying an already completed stage:
      // Points are recalculated! The student CANNOT take points more than once from the same exercise.
      final starDiff = starsEarned - prevStars;
      if (starDiff > 0) {
        // Improved performance: award delta points and bonus XP
        starsDelta = starDiff * 10;
        xpDelta = starDiff * 25;
        addReward(starsToAdd: starsDelta, xpToAdd: xpDelta);
      } else if (starDiff < 0) {
        // Lower evaluation: readjust points according to the new evaluation
        starsDelta = starDiff * 10;
        _stars = (_stars + starsDelta).clamp(0, 999999);
        notifyListeners();
      } else {
        // Same evaluation: 0 additional points! (No repeated points farming)
        starsDelta = 0;
        xpDelta = 0;
      }
    }

    notifyListeners();

    // Persist to Supabase & SharedPreferences for this specific student profile
    await SupabaseService.saveStageProgress(
      profileId: _currentProfileId,
      stageId: stageId,
      starsEarned: starsEarned,
      starsDelta: starsDelta,
      xpDelta: xpDelta,
      currentLevel: _level,
      currentXp: _currentXp,
      currentStars: _stars,
      nextActiveStageId: nextStageId,
    );

    return {
      'is_first_completion': isFirstCompletion,
      'stars_earned': starsEarned,
      'prev_stars': prevStars,
      'stars_added': starsDelta,
      'level': _level,
      'xp': _currentXp,
    };
  }

  // Dyslexia Reader Accessibility
  double _fontSizeDelta = 0.0;
  double get fontSizeDelta => _fontSizeDelta;

  bool _is18xSpacing = true;
  bool get is18xSpacing => _is18xSpacing;

  bool _isDyslexicFont = false;
  bool get isDyslexicFont => _isDyslexicFont;

  bool _isFocusRulerActive = false;
  bool get isFocusRulerActive => _isFocusRulerActive;

  double _audioSpeed = 1.0;
  double get audioSpeed => _audioSpeed;

  void increaseFontSize([double delta = 1.0]) {
    if (_fontSizeDelta < 8.0) {
      _fontSizeDelta = (_fontSizeDelta + delta).clamp(-4.0, 8.0);
      AppTypography.setFontDelta(_fontSizeDelta);
      _persistFontSize();
      notifyListeners();
    }
  }

  void decreaseFontSize([double delta = 1.0]) {
    if (_fontSizeDelta > -4.0) {
      _fontSizeDelta = (_fontSizeDelta - delta).clamp(-4.0, 8.0);
      AppTypography.setFontDelta(_fontSizeDelta);
      _persistFontSize();
      notifyListeners();
    }
  }

  void setFontSizeDelta(double delta) {
    _fontSizeDelta = delta.clamp(-4.0, 8.0);
    AppTypography.setFontDelta(_fontSizeDelta);
    _persistFontSize();
    notifyListeners();
  }

  void resetFontSize() {
    _fontSizeDelta = 0.0;
    AppTypography.setFontDelta(0.0);
    _persistFontSize();
    notifyListeners();
  }

  Future<void> _persistFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_font_size_delta', _fontSizeDelta);
  }

  void toggleSpacing() {
    _is18xSpacing = !_is18xSpacing;
    notifyListeners();
  }

  void toggleDyslexicFont() {
    _isDyslexicFont = !_isDyslexicFont;
    notifyListeners();
    SupabaseService.updateProfileAccommodations(
      profileId: _currentProfileId,
      isDyslexicFont: _isDyslexicFont,
    );
  }

  void toggleFocusRuler() {
    _isFocusRulerActive = !_isFocusRulerActive;
    notifyListeners();
  }

  void cycleAudioSpeed() {
    if (_audioSpeed == 1.0) {
      _audioSpeed = 0.75;
    } else if (_audioSpeed == 0.75) {
      _audioSpeed = 1.25;
    } else {
      _audioSpeed = 1.0;
    }
    notifyListeners();
  }

  // Dyscalculia Math Lab Options
  bool _isZenMode = true;
  bool get isZenMode => _isZenMode;

  bool _showVisualBlocks = true;
  bool get showVisualBlocks => _showVisualBlocks;

  bool _isBigKeypadActive = false;
  bool get isBigKeypadActive => _isBigKeypadActive;

  String _mathInputResult = '';
  String get mathInputResult => _mathInputResult;

  void toggleZenMode() {
    _isZenMode = !_isZenMode;
    notifyListeners();
    SupabaseService.updateProfileAccommodations(
      profileId: _currentProfileId,
      isZenMode: _isZenMode,
    );
  }

  void toggleVisualBlocks() {
    _showVisualBlocks = !_showVisualBlocks;
    notifyListeners();
  }

  void setInputMethod({required bool isBigKeypad}) {
    _isBigKeypadActive = isBigKeypad;
    notifyListeners();
  }

  void updateMathInputResult(String val) {
    _mathInputResult = val;
    notifyListeners();
  }
}
