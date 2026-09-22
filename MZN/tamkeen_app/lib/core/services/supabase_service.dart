import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://kzpvlduevnnwddytskxu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6cHZsZHVldm5ud2RkeXRza3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4MzQ2MDUsImV4cCI6MjEwNTQxMDYwNX0.WNDCFgCCRVHtRH1gNfNO3sSznMKTdvTlBHrZLwFDoTc';

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('[Supabase] Initialized successfully');
    } catch (e) {
      debugPrint('[Supabase] Init error (running in offline-cached mode): $e');
    }
  }

  static SupabaseClient? get client => _isInitialized ? Supabase.instance.client : null;

  // ====================================================
  // 0. AUTHENTICATION & DYNAMIC PROFILE FETCHING
  // ====================================================

  static Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    if (client != null) {
      try {
        final data = await client!
            .from('profiles')
            .select('id, student_name, email, role, level, xp, stars, streak_days')
            .order('created_at', ascending: false)
            .timeout(const Duration(milliseconds: 3000));
        return List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('[Supabase] fetchAllProfiles error: $e');
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    if (client != null) {
      try {
        final data = await client!
            .from('profiles')
            .select()
            .eq('email', email.trim().toLowerCase())
            .maybeSingle()
            .timeout(const Duration(milliseconds: 3000));
        return data;
      } catch (e) {
        debugPrint('[Supabase] getProfileByEmail error: $e');
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> registerNewProfile({
    required String studentName,
    required String email,
    required String role,
    String password = '123',
  }) async {
    // Generate UUID for the new user
    final String newId = '20000000-0000-0000-0000-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}';
    
    final newProfile = {
      'id': newId,
      'student_name': studentName,
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
      'role': role.toLowerCase(),
      'level': 1,
      'xp': 0,
      'max_xp': 1000,
      'stars': 0,
      'streak_days': 1,
      'is_dyslexic_font': false,
      'is_zen_mode': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 1. Insert into Supabase Cloud
    if (client != null) {
      try {
        await client!.from('profiles').insert(newProfile);

        // Initialize stage progress for this new student (Start fresh with 0 stars, stage 12 active)
        for (int id in [12, 13, 14, 15, 16, 17, 18]) {
          await client!.from('student_stage_progress').insert({
            'profile_id': newId,
            'stage_id': id,
            'status': id == 12 ? 'active' : 'locked',
            'stars_earned': 0,
          });
        }

        // Initialize zeroed skills in Supabase for this fresh learner profile
        final initialSkills = _getDefaultSkillsTemplate(newId);
        for (final skill in initialSkills) {
          try {
            await client!.from('student_skill_mastery').insert(skill);
          } catch (_) {}
        }
        debugPrint('[Supabase] Registered new profile: $studentName ($newId) with clean 0 telemetry');
      } catch (e) {
        debugPrint('[Supabase] Profile registration sync error: $e');
      }
    }

    // 2. Local Cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${newId}_name', studentName);
    await prefs.setString('${newId}_role', role);
    for (int id in [12, 13, 14, 15, 16, 17, 18]) {
      await prefs.setInt('${newId}_stage_${id}_stars', 0);
      await prefs.setString(
        '${newId}_stage_${id}_status',
        id == 12 ? 'active' : 'locked',
      );
    }

    return newProfile;
  }

  // ====================================================
  // 1. STAGE PROGRESSION & PERSISTENCE (Relational Foreign Keys)
  // ====================================================

  static Future<void> saveStageProgress({
    required String profileId,
    required int stageId,
    required int starsEarned,
    int starsDelta = 0,
    int xpDelta = 0,
    int currentLevel = 1,
    int currentXp = 0,
    int currentStars = 0,
    required int nextActiveStageId,
  }) async {
    // 1. Local Cache in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${profileId}_stage_${stageId}_stars', starsEarned);
    await prefs.setString('${profileId}_stage_${stageId}_status', 'completed');
    await prefs.setString('${profileId}_stage_${nextActiveStageId}_status', 'active');
    await prefs.setInt('${profileId}_level', currentLevel);
    await prefs.setInt('${profileId}_xp', currentXp);
    await prefs.setInt('${profileId}_stars', currentStars);

    // 2. Sync with Supabase Cloud Relational Table
    if (client != null) {
      try {
        // Upsert current completed stage for this student profile
        await client!.from('student_stage_progress').upsert(
          {
            'profile_id': profileId,
            'stage_id': stageId,
            'status': 'completed',
            'stars_earned': starsEarned,
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'profile_id, stage_id',
        );

        // Unlock next stage for this student profile
        await client!.from('student_stage_progress').upsert(
          {
            'profile_id': profileId,
            'stage_id': nextActiveStageId,
            'status': 'active',
            'stars_earned': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'profile_id, stage_id',
        );

        // Update profile level, xp, and stars in Supabase
        await client!.from('profiles').update({
          'stars': currentStars,
          'level': currentLevel,
          'xp': currentXp,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', profileId);

        debugPrint('[Supabase] Saved stage $stageId progress (stars: $starsEarned, delta: $starsDelta, level: $currentLevel, xp: $currentXp) for profile $profileId');
      } catch (e) {
        debugPrint('[Supabase] Stage sync error: $e');
      }
    }
  }

  static Future<Map<int, Map<String, dynamic>>> loadStagesProgress({
    String profileId = '00000000-0000-0000-0000-000000000001',
  }) async {
    final Map<int, Map<String, dynamic>> stagesMap = {};

    // First try Supabase Cloud with relational query (protected by 2.5s timeout)
    if (client != null) {
      try {
        final data = await client!
            .from('student_stage_progress')
            .select('stage_id, status, stars_earned')
            .eq('profile_id', profileId)
            .timeout(const Duration(milliseconds: 2500));

        if (data.isNotEmpty) {
          for (var row in data) {
            final id = row['stage_id'] as int;
            stagesMap[id] = {
              'status': row['status'] ?? 'locked',
              'stars': row['stars_earned'] ?? 0,
            };
          }
          return stagesMap;
        }
      } catch (e) {
        debugPrint('[Supabase] Load student stage progress error or timeout: $e');
      }
    }

    // Fallback to local cache
    final prefs = await SharedPreferences.getInstance();
    for (int id in [12, 13, 14, 15, 16, 17, 18]) {
      final stars = prefs.getInt('${profileId}_stage_${id}_stars') ?? 0;
      final status = prefs.getString('${profileId}_stage_${id}_status') ??
          (id == 12 ? 'active' : 'locked');
      stagesMap[id] = {'status': status, 'stars': stars};
    }
    return stagesMap;
  }

  // ====================================================
  // 2. DYSLEXIA SESSION RECORDING (Relational)
  // ====================================================

  static Future<void> recordDyslexiaSession({
    String profileId = '00000000-0000-0000-0000-000000000001',
    int stageId = 12,
    required String passageTitle,
    required double accuracy,
    required int wpm,
    required double expression,
    required int wordsMastered,
    required String discoveryWord,
    required String discoveryMeaning,
    double substitutionsPct = 0.0,
    double hesitationsPct = 0.0,
    double omissionsPct = 0.0,
    String phoneticNotes = '',
    String studentName = 'Learner',
  }) async {
    final sessionData = {
      'profile_id': profileId,
      'stage_id': stageId,
      'student_name': studentName,
      'passage_title': passageTitle,
      'accuracy': accuracy,
      'wpm': wpm,
      'expression': expression,
      'words_mastered': wordsMastered,
      'discovery_word': discoveryWord,
      'discovery_meaning': discoveryMeaning,
      'substitutions_pct': substitutionsPct,
      'hesitations_pct': hesitationsPct,
      'omissions_pct': omissionsPct,
      'phonetic_notes': phoneticNotes,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Local Cache
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('dyslexia_history') ?? [];
    history.add(jsonEncode(sessionData));
    await prefs.setStringList('dyslexia_history', history);

    // 2. Supabase Cloud Sync
    if (client != null && profileId.isNotEmpty) {
      try {
        await client!
            .from('dyslexia_sessions')
            .insert(sessionData)
            .timeout(const Duration(milliseconds: 3000));
        debugPrint('[Supabase] Dyslexia session saved for profile $profileId, stage $stageId');

        // Update Reading Skills in student_skill_mastery in Supabase
        final fluencyScore = (wpm / 120.0).clamp(0.0, 1.0);
        final phonicsScore = (accuracy / 100.0).clamp(0.0, 1.0);
        final wordScore = (wordsMastered / 15.0).clamp(0.0, 1.0);

        await _upsertStudentSkill(
          profileId: profileId,
          skillCode: 'fluency_scout',
          score: fluencyScore,
          status: fluencyScore >= 0.8 ? 'Mastered' : (fluencyScore >= 0.4 ? 'In Progress' : 'Emerging Support'),
        );
        await _upsertStudentSkill(
          profileId: profileId,
          skillCode: 'phonics_hero',
          score: phonicsScore,
          status: phonicsScore >= 0.85 ? 'Mastered' : (phonicsScore >= 0.5 ? 'In Progress' : 'Emerging Support'),
        );
        await _upsertStudentSkill(
          profileId: profileId,
          skillCode: 'word_master',
          score: wordScore,
          status: wordScore >= 0.8 ? 'Mastered' : 'In Progress',
        );
      } catch (e) {
        debugPrint('[Supabase] Dyslexia session insert error: $e');
      }
    }
  }

  // ====================================================
  // 3. MATH SESSION RECORDING (Relational PyBKT Telemetry)
  // ====================================================

  static Future<void> recordMathSession({
    String profileId = '00000000-0000-0000-0000-000000000001',
    int stageId = 15,
    required String equation,
    required String studentAnswer,
    required bool isCorrect,
    required int responseTimeMs,
    required int hintCount,
    required int attempts,
    required double pKnowledge,
    required String adaptiveDifficulty,
    required double frustrationIndex,
    required double confusedIndex,
    String studentName = 'Learner',
  }) async {
    final sessionData = {
      'profile_id': profileId,
      'stage_id': stageId,
      'student_name': studentName,
      'equation': equation,
      'student_answer': studentAnswer,
      'is_correct': isCorrect,
      'response_time_ms': responseTimeMs,
      'hint_count': hintCount,
      'attempts': attempts,
      'p_knowledge': pKnowledge,
      'adaptive_difficulty': adaptiveDifficulty,
      'frustration_index': frustrationIndex,
      'confused_index': confusedIndex,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Local Cache
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('math_history') ?? [];
    history.add(jsonEncode(sessionData));
    await prefs.setStringList('math_history', history);

    // 2. Supabase Cloud Sync
    if (client != null && profileId.isNotEmpty) {
      try {
        await client!
            .from('math_sessions')
            .insert(sessionData)
            .timeout(const Duration(milliseconds: 3000));
        debugPrint('[Supabase] Math session saved for profile $profileId, stage $stageId');

        // Map stage to corresponding PyBKT skill code
        String skillCode = 'single_addition';
        if (stageId == 16) skillCode = 'tens_regrouping';
        if (stageId == 17) skillCode = 'number_line';
        if (stageId == 18) skillCode = 'multi_step';

        final status = pKnowledge >= 0.85
            ? 'Mastered'
            : (pKnowledge >= 0.5 ? 'In Progress' : 'Emerging Support');

        await _upsertStudentSkill(
          profileId: profileId,
          skillCode: skillCode,
          score: pKnowledge,
          status: status,
        );
      } catch (e) {
        debugPrint('[Supabase] Math session insert error: $e');
      }
    }
  }

  // ====================================================
  // 4. LIVE ANALYTICS AGGREGATION (Pure Database Real-Time)
  // ====================================================

  static Future<Map<String, dynamic>> fetchLiveAnalytics({
    required String profileId,
    int daysWindow = 0,
  }) async {
    if (client != null && profileId.isNotEmpty) {
      try {
        DateTime? filterDate;
        if (daysWindow > 0) {
          filterDate = DateTime.now().subtract(Duration(days: daysWindow));
        }

        var mathQuery = client!
            .from('math_sessions')
            .select()
            .eq('profile_id', profileId);
        if (filterDate != null) {
          mathQuery = mathQuery.gte('created_at', filterDate.toIso8601String());
        }
        final mathRows = await mathQuery
            .order('created_at', ascending: true)
            .timeout(const Duration(milliseconds: 3500));

        var dyslexiaQuery = client!
            .from('dyslexia_sessions')
            .select()
            .eq('profile_id', profileId);
        if (filterDate != null) {
          dyslexiaQuery = dyslexiaQuery.gte('created_at', filterDate.toIso8601String());
        }
        final dyslexiaRows = await dyslexiaQuery
            .order('created_at', ascending: true)
            .timeout(const Duration(milliseconds: 3500));

        final bool hasData = mathRows.isNotEmpty || dyslexiaRows.isNotEmpty;

        if (!hasData) {
          return {
            'has_data': false,
            'reading_count': 0,
            'math_count': 0,
            'total_sessions': 0,
            'frustration_percent': 0,
            'focus_percent': 100,
            'wpm_points': <Map<String, dynamic>>[],
            'avg_wpm': 0,
            'avg_accuracy': 0.0,
            'substitutions_pct': 0.0,
            'hesitations_pct': 0.0,
            'omissions_pct': 0.0,
            'phonetic_notes': '',
            'pybkt_mastery': 0.0,
            'math_skills_breakdown': {
              'single_addition': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
              'tens_regrouping': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
              'number_line': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
              'multi_step': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
            },
          };
        }

        // Calculate average frustration and PyBKT from real math sessions
        double avgFrustration = 0.0;
        double latestPyBkt = 0.0;
        if (mathRows.isNotEmpty) {
          final sum = mathRows.fold<double>(
            0.0,
            (prev, r) => prev + ((r['frustration_index'] as num?)?.toDouble() ?? 0.0),
          );
          avgFrustration = sum / mathRows.length;
          latestPyBkt = (mathRows.last['p_knowledge'] as num?)?.toDouble() ?? 0.0;
        }

        // Calculate real WPM progression, accuracy & error profile from reading sessions
        final List<Map<String, dynamic>> wpmPoints = [];
        double sumAccuracy = 0.0;
        double sumWpm = 0.0;
        double sumSubs = 0.0;
        double sumHesi = 0.0;
        double sumOmis = 0.0;
        String latestPhonetic = '';

        if (dyslexiaRows.isNotEmpty) {
          for (int i = 0; i < dyslexiaRows.length; i++) {
            final row = dyslexiaRows[i];
            final wpm = (row['wpm'] as num?)?.toInt() ?? 0;
            final acc = (row['accuracy'] as num?)?.toDouble() ?? 0.0;
            sumAccuracy += acc;
            sumWpm += wpm;

            final subs = (row['substitutions_pct'] as num?)?.toDouble() ?? 0.0;
            final hesi = (row['hesitations_pct'] as num?)?.toDouble() ?? 0.0;
            final omis = (row['omissions_pct'] as num?)?.toDouble() ?? 0.0;

            final errorResidual = (100.0 - acc).clamp(0.0, 100.0);
            sumSubs += subs > 0 ? subs : (errorResidual * 0.45);
            sumHesi += hesi > 0 ? hesi : (errorResidual * 0.35);
            sumOmis += omis > 0 ? omis : (errorResidual * 0.20);

            if ((row['phonetic_notes']?.toString() ?? '').isNotEmpty) {
              latestPhonetic = row['phonetic_notes'].toString();
            }

            wpmPoints.add({
              'label': 'S${i + 1}',
              'wpm': wpm,
              'accuracy': acc,
              'date': row['created_at'],
            });
          }
        }

        final double avgAccuracy = dyslexiaRows.isNotEmpty ? (sumAccuracy / dyslexiaRows.length) : 0.0;
        final int avgWpm = dyslexiaRows.isNotEmpty ? (sumWpm / dyslexiaRows.length).round() : 0;
        final double avgSubs = dyslexiaRows.isNotEmpty ? (sumSubs / dyslexiaRows.length) : 0.0;
        final double avgHesi = dyslexiaRows.isNotEmpty ? (sumHesi / dyslexiaRows.length) : 0.0;
        final double avgOmis = dyslexiaRows.isNotEmpty ? (sumOmis / dyslexiaRows.length) : 0.0;

        // Calculate skill-by-stage breakdown for math
        final mathBreakdown = <String, Map<String, dynamic>>{
          'single_addition': _computeStageSkillMetrics(mathRows, 15),
          'tens_regrouping': _computeStageSkillMetrics(mathRows, 16),
          'number_line': _computeStageSkillMetrics(mathRows, 17),
          'multi_step': _computeStageSkillMetrics(mathRows, 18),
        };

        return {
          'has_data': true,
          'reading_count': dyslexiaRows.length,
          'math_count': mathRows.length,
          'total_sessions': dyslexiaRows.length + mathRows.length,
          'frustration_percent': (avgFrustration * 100).toInt(),
          'focus_percent': (100 - (avgFrustration * 100)).toInt().clamp(0, 100),
          'wpm_points': wpmPoints,
          'avg_wpm': avgWpm,
          'avg_accuracy': avgAccuracy,
          'substitutions_pct': avgSubs,
          'hesitations_pct': avgHesi,
          'omissions_pct': avgOmis,
          'phonetic_notes': latestPhonetic,
          'pybkt_mastery': latestPyBkt,
          'math_skills_breakdown': mathBreakdown,
        };
      } catch (e) {
        debugPrint('[Supabase] Live analytics error: $e');
      }
    }

    return {
      'has_data': false,
      'reading_count': 0,
      'math_count': 0,
      'total_sessions': 0,
      'frustration_percent': 0,
      'focus_percent': 100,
      'wpm_points': <Map<String, dynamic>>[],
      'avg_wpm': 0,
      'avg_accuracy': 0.0,
      'substitutions_pct': 0.0,
      'hesitations_pct': 0.0,
      'omissions_pct': 0.0,
      'phonetic_notes': '',
      'pybkt_mastery': 0.0,
      'math_skills_breakdown': {
        'single_addition': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
        'tens_regrouping': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
        'number_line': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
        'multi_step': {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'},
      },
    };
  }

  static Map<String, dynamic> _computeStageSkillMetrics(List<dynamic> rows, int stageId) {
    final stageRows = rows.where((r) => (r['stage_id'] as num?)?.toInt() == stageId).toList();
    if (stageRows.isEmpty) {
      return {'mastery': 0.0, 'sessions': 0, 'status': 'Not Started'};
    }
    final latestPL = (stageRows.last['p_knowledge'] as num?)?.toDouble() ?? 0.0;
    final status = latestPL >= 0.85
        ? 'Mastered'
        : (latestPL >= 0.5 ? 'In Progress' : 'Emerging Support');
    return {
      'mastery': latestPL,
      'sessions': stageRows.length,
      'status': status,
    };
  }

  // ====================================================
  // 5. SKILL MASTERY QUERY (Profile-Specific Knowledge)
  // ====================================================

  static Future<List<Map<String, dynamic>>> fetchSkillMastery({required String profileId}) async {
    if (client != null && profileId.isNotEmpty) {
      try {
        final data = await client!
            .from('student_skill_mastery')
            .select()
            .eq('profile_id', profileId)
            .order('skill_code', ascending: true)
            .timeout(const Duration(milliseconds: 3000));
        if (data.isNotEmpty) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          // Initialize for profile if not present yet
          final initialSkills = _getDefaultSkillsTemplate(profileId);
          for (final s in initialSkills) {
            try {
              await client!.from('student_skill_mastery').upsert(s, onConflict: 'profile_id,skill_code');
            } catch (_) {}
          }
          return initialSkills;
        }
      } catch (e) {
        debugPrint('[Supabase] fetchSkillMastery error: $e');
      }
    }

    return _getDefaultSkillsTemplate(profileId);
  }

  static Future<void> _upsertStudentSkill({
    required String profileId,
    required String skillCode,
    required double score,
    required String status,
  }) async {
    if (client == null || profileId.isEmpty) return;
    try {
      await client!.from('student_skill_mastery').upsert(
        {
          'profile_id': profileId,
          'skill_code': skillCode,
          'mastery_score': score,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'profile_id,skill_code',
      );
    } catch (e) {
      debugPrint('[Supabase] _upsertStudentSkill error: $e');
    }
  }

  static List<Map<String, dynamic>> _getDefaultSkillsTemplate(String profileId) {
    return [
      {
        'profile_id': profileId,
        'skill_code': 'single_addition',
        'skill_name_en': 'Single-digit Addition & Subtraction',
        'skill_name_ar': 'الجمع والطرح البسيط',
        'category': 'math',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'tens_regrouping',
        'skill_name_en': 'Tens Regrouping (Base-10 Spatial)',
        'skill_name_ar': 'إعادة التجميع المكاني بالعشرات',
        'category': 'math',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'number_line',
        'skill_name_en': 'Number Line Spatial Estimation',
        'skill_name_ar': 'التقدير المكاني على خط الأعداد',
        'category': 'math',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'multi_step',
        'skill_name_en': 'Multi-step Story Equations',
        'skill_name_ar': 'المعادلات الرياضية متعددة الخطوات',
        'category': 'math',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'phonics_hero',
        'skill_name_en': 'Phonological Decoding',
        'skill_name_ar': 'الترميز الصوتي والتفكيك',
        'category': 'reading',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'fluency_scout',
        'skill_name_en': 'Fluency & Pacing (WPM)',
        'skill_name_ar': 'الطلاقة وسرعة القراءة',
        'category': 'reading',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
      {
        'profile_id': profileId,
        'skill_code': 'word_master',
        'skill_name_en': 'Vocabulary Recognition',
        'skill_name_ar': 'التعرف البصري على الكلمات',
        'category': 'reading',
        'mastery_score': 0.0,
        'status': 'Not Started',
      },
    ];
  }

  // ====================================================
  // 6. CHRONOLOGICAL ACTIVITY LOGS QUERY (Direct DB Only)
  // ====================================================

  static Future<List<Map<String, dynamic>>> fetchRecentActivityLogs({required String profileId}) async {
    final List<Map<String, dynamic>> logs = [];

    if (client != null && profileId.isNotEmpty) {
      try {
        final mathRows = await client!
            .from('math_sessions')
            .select()
            .eq('profile_id', profileId)
            .order('created_at', ascending: false)
            .limit(20)
            .timeout(const Duration(milliseconds: 3000));

        final readingRows = await client!
            .from('dyslexia_sessions')
            .select()
            .eq('profile_id', profileId)
            .order('created_at', ascending: false)
            .limit(20)
            .timeout(const Duration(milliseconds: 3000));

        for (final row in mathRows) {
          final pK = ((row['p_knowledge'] as num?)?.toDouble() ?? 0.0);
          logs.add({
            'type': 'math',
            'title': row['equation'] != null ? 'Equation: ${row['equation']}' : 'Math Challenge',
            'title_ar': row['equation'] != null ? 'معادلة: ${row['equation']}' : 'تحدي الحساب',
            'subtitle': 'Answer: ${row['student_answer'] ?? ''} • PyBKT Mastery: ${(pK * 100).toInt()}%',
            'subtitle_ar': 'الإجابة: ${row['student_answer'] ?? ''} • تمكن PyBKT: ${(pK * 100).toInt()}%',
            'score': pK >= 0.8 ? 'Mastered' : 'Completed',
            'created_at': row['created_at'],
            'is_correct': row['is_correct'] ?? true,
          });
        }

        for (final row in readingRows) {
          logs.add({
            'type': 'reading',
            'title': row['passage_title'] ?? 'Reading Passage',
            'title_ar': row['passage_title'] ?? 'مقطع القراءة',
            'subtitle': 'WPM: ${row['wpm'] ?? 0} • Accuracy: ${(row['accuracy'] as num?)?.toStringAsFixed(1) ?? '0'}%',
            'subtitle_ar': 'السرعة: ${row['wpm'] ?? 0} ك/د • الدقة: ${(row['accuracy'] as num?)?.toStringAsFixed(1) ?? '0'}%',
            'score': '${row['wpm'] ?? 0} WPM',
            'created_at': row['created_at'],
            'is_correct': true,
          });
        }

        // Sort unified logs by created_at descending
        logs.sort((a, b) {
          final timeA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
          final timeB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
          return timeB.compareTo(timeA);
        });

        return logs;
      } catch (e) {
        debugPrint('[Supabase] fetchRecentActivityLogs error: $e');
      }
    }

    return logs;
  }

  // ====================================================
  // 7. ACCOMMODATIONS PERSISTENCE
  // ====================================================

  static Future<void> updateProfileAccommodations({
    required String profileId,
    bool? isDyslexicFont,
    bool? isZenMode,
  }) async {
    final Map<String, dynamic> updates = {
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (isDyslexicFont != null) updates['is_dyslexic_font'] = isDyslexicFont;
    if (isZenMode != null) updates['is_zen_mode'] = isZenMode;

    if (client != null && profileId.isNotEmpty) {
      try {
        await client!.from('profiles').update(updates).eq('id', profileId);
        debugPrint('[Supabase] Profile accommodations updated for $profileId');
      } catch (e) {
        debugPrint('[Supabase] Update accommodations error: $e');
      }
    }
  }
}
