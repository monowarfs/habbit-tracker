import 'package:screen_protector/screen_protector.dart';

/// Thin wrap over `screen_protector` — `FLAG_SECURE` on Android
/// (blocks screenshots/recording, blanks the recent-apps thumbnail),
/// an app-switcher blur overlay on iOS (`strategies/security.md`).
/// Offered from Settings only once PIN lock is enabled.
class ScreenPrivacyService {
  /// Enables screen privacy protection.
  Future<void> enable() async {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageOn();
  }

  /// Disables screen privacy protection.
  Future<void> disable() async {
    await ScreenProtector.preventScreenshotOff();
    await ScreenProtector.protectDataLeakageOff();
  }
}
