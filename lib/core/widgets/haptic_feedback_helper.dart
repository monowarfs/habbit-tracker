import 'package:flutter/services.dart';

/// Plays a light haptic feedback pulse on successful actions.
///
/// Respects the OS-level haptic setting — no-op on devices without
/// a vibration motor or when the user has disabled system haptics.
class HapticFeedbackHelper {
  /// Plays a light impact haptic feedback.
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } on Exception {
      // Silently ignore — some devices don't support haptics.
    }
  }
}
