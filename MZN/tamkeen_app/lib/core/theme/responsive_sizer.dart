import 'package:flutter/foundation.dart';
import 'package:sizer/sizer.dart';
export 'package:sizer/sizer.dart';

/// Controller to dynamically manage scale factor with boundaries and ChangeNotifier support.
class SizeScaleController extends ChangeNotifier {
  double _scaleFactor;
  final double minScale;
  final double maxScale;

  SizeScaleController({
    double initialScale = 1.0,
    this.minScale = 0.5,
    this.maxScale = 3.0,
  }) : _scaleFactor = initialScale;

  /// Current scale factor
  double get scaleFactor => _scaleFactor;

  /// Increase scale by [step] (default 0.05 or 5%)
  void increase([double step = 0.05]) {
    _scaleFactor = (_scaleFactor + step).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// Decrease scale by [step] (default 0.05 or 5%)
  void decrease([double step = 0.05]) {
    _scaleFactor = (_scaleFactor - step).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// Set exact scale factor
  void setScale(double factor) {
    _scaleFactor = factor.clamp(minScale, maxScale);
    notifyListeners();
  }

  /// Reset scale factor back to 1.0
  void reset() {
    _scaleFactor = 1.0;
    notifyListeners();
  }

  /// Scale a specific value by this controller's scale factor
  double scale(num value) => (value * _scaleFactor).toDouble();
}

/// Global scaling manager for the entire application.
class AppSizeScaler {
  static final SizeScaleController globalController = SizeScaleController();

  /// Current global scale factor
  static double get globalScaleFactor => globalController.scaleFactor;

  /// Increases global size scale by [step]
  static void increase([double step = 0.05]) => globalController.increase(step);

  /// Decreases global size scale by [step]
  static void decrease([double step = 0.05]) => globalController.decrease(step);

  /// Sets global scale factor to a specific value
  static void setScale(double factor) => globalController.setScale(factor);

  /// Resets global scale factor back to 1.0
  static void reset() => globalController.reset();

  /// Scale any dimension by the global scale factor (or optional custom factor)
  static double scale(num value, {double? factor}) =>
      (value * (factor ?? globalScaleFactor)).toDouble();
}

/// Standalone helper function to scale any dimension
double scaleSize(num value, [double? factor]) =>
    AppSizeScaler.scale(value, factor: factor);

/// Extension providing safe Sizer calculations with fallback protection
/// and scaling utilities for headless test environments or responsive canvas.
extension ResponsiveSafeExt on num {
  /// Safe width percentage with fallback (1w ~ 3.75px on standard 375w canvas)
  double get safeW {
    try {
      return w;
    } catch (_) {
      return toDouble() * 3.75;
    }
  }

  /// Safe height percentage with fallback (1h ~ 8.12px on standard 812h canvas)
  double get safeH {
    try {
      return h;
    } catch (_) {
      return toDouble() * 8.12;
    }
  }

  /// Safe scalable pixels for typography / icons
  double get safeSp {
    try {
      return sp;
    } catch (_) {
      return toDouble();
    }
  }

  /// Scale this numeric dimension by global scale or an optional custom factor
  double scale([double? factor]) => AppSizeScaler.scale(this, factor: factor);

  /// Convenient getter for value scaled by the global scale factor
  double get scaled => AppSizeScaler.scale(this);
}
