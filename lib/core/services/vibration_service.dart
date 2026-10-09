import 'package:flutter/services.dart';

class VibrationService {
  static const MethodChannel _channel = MethodChannel('com.utility.app/vibrator');

  /// Quick tactile light tap (35ms, moderate power)
  static Future<void> lightImpact() async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': 35, 'amplitude': 90});
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium feedback tap (65ms, high power)
  static Future<void> mediumImpact() async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': 65, 'amplitude': 170});
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Solid heavy tactile thump (110ms, maximum power)
  static Future<void> heavyImpact() async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': 110, 'amplitude': 255});
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Crisp selection click (20ms)
  static Future<void> selectionClick() async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': 25, 'amplitude': 80});
    } catch (_) {
      HapticFeedback.selectionClick();
    }
  }

  /// Continuous motor vibration for specified milliseconds
  static Future<void> vibrate({int durationMs = 250}) async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': durationMs, 'amplitude': 255});
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  /// Native waveform vibration pattern
  /// [timings] is in milliseconds: [delay0, vibrate0, pause1, vibrate1, ...]
  static Future<void> vibratePattern({required List<int> timings, int repeat = -1}) async {
    try {
      await _channel.invokeMethod('vibratePattern', {
        'timings': timings,
        'repeat': repeat,
      });
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  /// Stop any active vibration immediately
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }
}
