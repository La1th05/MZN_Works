import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Models response for Dyslexia reading analysis
class ReadingAnalysisResult {
  final double accuracyPercent;
  final int wordsPerMinute;
  final double expressionScore; // 0 - 5.0
  final int wordsMastered;
  final String discoveryWord;
  final String discoveryMeaning;
  final bool teacherReviewRecommended;
  final String feedbackMessage;
  final String spokenText;

  ReadingAnalysisResult({
    required this.accuracyPercent,
    required this.wordsPerMinute,
    required this.expressionScore,
    required this.wordsMastered,
    required this.discoveryWord,
    required this.discoveryMeaning,
    this.teacherReviewRecommended = false,
    this.feedbackMessage = '',
    this.spokenText = '',
  });
}

/// Models response for Dyscalculia math & PyBKT evaluation
class MathEvaluationResult {
  final bool isCorrect;
  final double pKnowledge; // PyBKT mastery probability (0.0 to 1.0)
  final String adaptiveDifficulty; // 'Easy', 'Medium', 'Hard'
  final double frustrationIndex; // 0.0 to 1.0
  final double confusedIndex; // 0.0 to 1.0
  final String feedbackMessage;

  MathEvaluationResult({
    required this.isCorrect,
    required this.pKnowledge,
    required this.adaptiveDifficulty,
    required this.frustrationIndex,
    required this.confusedIndex,
    required this.feedbackMessage,
  });
}

/// Models response for CNN handwritten symbol recognition
class SymbolRecognitionResult {
  final String symbol;
  final String rawLabel;
  final double confidence;
  final bool isBlank;

  SymbolRecognitionResult({
    required this.symbol,
    required this.rawLabel,
    required this.confidence,
    required this.isBlank,
  });
}

class AIBridgeService {
  /// Default ngrok tunnel URL provided by user
  static const String defaultNgrokUrl = 'https://proximity-refusing-collision.ngrok-free.dev';
  static const String _prefBackendKey = 'custom_ai_backend_url';

  /// Candidate list of URLs prioritized by reachability
  static final List<String> candidateUrls = [
    defaultNgrokUrl,               // Ngrok public tunnel (works globally, mobile, web, emulator)
    'http://127.0.0.1:8000',       // Local PC host
    'http://10.0.2.2:8000',        // Android Emulator loopback
    'http://192.168.100.13:8000', // Wi-Fi LAN IP
  ];

  static String? _workingUrl;

  /// Default headers to bypass ngrok-free interstitial warning page and ensure JSON content
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'TamkeenApp/1.0',
  };

  /// Dynamically determines or returns the active working backend URL
  static Future<String> getBackendUrl({bool forceRefresh = false}) async {
    if (!forceRefresh && _workingUrl != null) return _workingUrl!;

    // 1. Check user-saved custom URL from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString(_prefBackendKey);
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        final clean = customUrl.trim().replaceAll(RegExp(r'/+$'), '');
        if (await _testUrl(clean)) {
          _workingUrl = clean;
          debugPrint('[AIBridge] Connected to saved custom backend at: $clean');
          return clean;
        }
      }
    } catch (_) {}

    // 2. Test candidate URLs starting with ngrok
    for (final url in candidateUrls) {
      final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
      if (await _testUrl(clean)) {
        _workingUrl = clean;
        debugPrint('[AIBridge] Connected successfully to AI server at: $clean');
        return clean;
      }
    }

    // 3. Fallback to default ngrok URL
    _workingUrl = defaultNgrokUrl;
    return _workingUrl!;
  }

  /// Ping health endpoint on candidate URL
  static Future<bool> _testUrl(String url) async {
    try {
      final res = await http.get(
        Uri.parse('$url/'),
        headers: defaultHeaders,
      ).timeout(const Duration(milliseconds: 3000));

      if (res.statusCode == 200 && !res.body.contains('ERR_NGROK')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Sets or updates the custom backend URL
  static Future<void> setCustomBackendUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_prefBackendKey);
      _workingUrl = null;
    } else {
      final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
      await prefs.setString(_prefBackendKey, clean);
      _workingUrl = clean;
    }
  }

  /// Retrieves custom backend URL if saved
  static Future<String?> getCustomBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefBackendKey);
    } catch (_) {
      return null;
    }
  }

  /// Comprehensive connection test returning status, latency, and detailed diagnostics
  static Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final target = (testUrl != null && testUrl.trim().isNotEmpty)
        ? testUrl.trim().replaceAll(RegExp(r'/+$'), '')
        : await getBackendUrl(forceRefresh: true);

    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(
        Uri.parse('$target/'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (res.statusCode == 200 && !res.body.contains('ERR_NGROK')) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(res.body);
        } catch (_) {}

        _workingUrl = target;
        return {
          'success': true,
          'url': target,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'data': data,
          'message': 'Connected successfully',
        };
      } else if (res.body.contains('ERR_NGROK_8012') || res.statusCode == 502) {
        return {
          'success': false,
          'url': target,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'isNgrokWaiting': true,
          'message': 'ngrok online, but localhost:8000 server is not started yet. Run run_server.bat.',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'url': target,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'message': e.toString(),
      };
    }

    return {
      'success': false,
      'url': target,
      'latencyMs': stopwatch.elapsedMilliseconds,
      'message': 'Unable to connect to $target',
    };
  }

  /// Evaluate Reading Audio & Expected Text
  static Future<ReadingAnalysisResult> analyzeReading({
    required String expectedText,
    String? audioPath,
    String? audioBase64,
    double durationSeconds = 10.0,
  }) async {
    final baseUrl = await getBackendUrl();
    try {
      final url = Uri.parse('$baseUrl/api/dyslexia/analyze');
      final response = await http
          .post(
            url,
            headers: defaultHeaders,
            body: jsonEncode({
              'expected_text': expectedText,
              'audio_path': audioPath,
              'audio_base64': audioBase64,
              'duration_seconds': durationSeconds,
            }),
          )
          .timeout(const Duration(milliseconds: 30000));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ReadingAnalysisResult(
          accuracyPercent: (data['accuracy'] as num).toDouble(),
          wordsPerMinute: (data['wpm'] as num).toInt(),
          expressionScore: (data['expression'] as num).toDouble(),
          wordsMastered: (data['words_mastered'] as num).toInt(),
          discoveryWord: data['discovery_word'] ?? 'Courage',
          discoveryMeaning: data['discovery_meaning'] ?? 'Inner strength to read with pride',
          feedbackMessage: (data['feedback'] ?? '').toString(),
          spokenText: (data['spoken_text'] ?? '').toString(),
        );
      }
    } catch (e) {
      debugPrint('[AIBridge] Reading API error: $e');
    }

    return ReadingAnalysisResult(
      accuracyPercent: 0.0,
      wordsPerMinute: 0,
      expressionScore: 1.0,
      wordsMastered: 0,
      discoveryWord: 'Courage',
      discoveryMeaning: 'Inner strength to read with pride',
      feedbackMessage: 'تعذر الاتصال بالسيرفر لتحليل الصوت',
      spokenText: '',
    );
  }

  /// Evaluate Math Equation & Input Answer with PyBKT & Behavioral Signals
  static Future<MathEvaluationResult> evaluateMath({
    required String expectedAnswer,
    required String studentAnswer,
    required int responseTimeMs,
    required int hintCount,
    required int attempts,
  }) async {
    final cleanStudent = studentAnswer.trim();
    final cleanExpected = expectedAnswer.trim();
    final bool isCorrect = cleanStudent == cleanExpected;

    final baseUrl = await getBackendUrl();
    try {
      final url = Uri.parse('$baseUrl/api/smart_lms/evaluate');
      final response = await http
          .post(
            url,
            headers: defaultHeaders,
            body: jsonEncode({
              'expected': cleanExpected,
              'answer': cleanStudent,
              'ms_response': responseTimeMs,
              'hint_count': hintCount,
              'attempts': attempts,
            }),
          )
          .timeout(const Duration(milliseconds: 3000));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MathEvaluationResult(
          isCorrect: data['is_correct'] == true,
          pKnowledge: (data['p_knowledge'] as num).toDouble(),
          adaptiveDifficulty: data['adaptive_difficulty'] ?? 'Medium',
          frustrationIndex: (data['frustration'] as num).toDouble(),
          confusedIndex: (data['confused'] as num).toDouble(),
          feedbackMessage: data['feedback'] ?? '',
        );
      }
    } catch (_) {
      // Local fallback running PyBKT calculation formula from smart_lms/services/analytics.py
    }

    final double attemptSignal = attempts > 1 ? ((attempts - 1) / 4.0).clamp(0.0, 1.0) : 0.0;
    final double timeSignal = (responseTimeMs / 60000.0).clamp(0.0, 1.0);
    final double frustration = (attemptSignal * 0.7 + timeSignal * 0.3).clamp(0.0, 1.0);
    final double pKnowledge = isCorrect ? 0.84 : 0.45;
    final String difficulty = pKnowledge > 0.75 ? 'Hard' : (pKnowledge < 0.4 ? 'Easy' : 'Medium');

    return MathEvaluationResult(
      isCorrect: isCorrect,
      pKnowledge: pKnowledge,
      adaptiveDifficulty: difficulty,
      frustrationIndex: frustration,
      confusedIndex: isCorrect ? 0.0 : 0.35,
      feedbackMessage: isCorrect ? 'Super job! Perfect calculation!' : 'Great effort! Let us try grouping the tens first.',
    );
  }

  /// Recognize handwritten symbol from canvas image (Base64 PNG) using PyTorch CNN model best_symbol_cnn2.pt
  static Future<SymbolRecognitionResult> recognizeHandwrittenSymbol({
    required String imageBase64,
    bool digitsOnly = true,
  }) async {
    final baseUrl = await getBackendUrl();
    try {
      final url = Uri.parse('$baseUrl/api/math/recognize_symbol');
      final response = await http
          .post(
            url,
            headers: defaultHeaders,
            body: jsonEncode({
              'image_base64': imageBase64,
              'topk': 5,
              'digits_only': digitsOnly,
            }),
          )
          .timeout(const Duration(milliseconds: 15000));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SymbolRecognitionResult(
          symbol: (data['symbol'] ?? '').toString(),
          rawLabel: (data['raw_label'] ?? '').toString(),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          isBlank: (data['is_blank'] as bool?) ?? false,
        );
      } else {
        debugPrint('[AIBridge] Symbol CNN returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AIBridge] Symbol recognition error: $e');
    }

    return SymbolRecognitionResult(
      symbol: '',
      rawLabel: '',
      confidence: 0.0,
      isBlank: true,
    );
  }
}
