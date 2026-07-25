import 'package:screen_protector/screen_protector.dart';

/// Thin wrap over `screen_protector` — `FLAG_SECURE` on Android
/// (blocks screenshots/recording, blanks the recent-apps thumbnail),
/// an app-switcher blur overlay on iOS (`strategies/security.md`).
/// Offered from Settings only once PIN lock is enabled.
class ScreenPrivacyService {
  /// Creates a service with injectable platform calls for testing.
  /// Defaults to the real `ScreenProtector` static methods.
  ScreenPrivacyService({
    Future<void> Function()? preventScreenshotOn,
    Future<void> Function()? protectDataLeakageOn,
    Future<void> Function()? preventScreenshotOff,
    Future<void> Function()? protectDataLeakageOff,
  }) : _preventScreenshotOn =
           preventScreenshotOn ?? ScreenProtector.preventScreenshotOn,
       _protectDataLeakageOn =
           protectDataLeakageOn ?? ScreenProtector.protectDataLeakageOn,
       _preventScreenshotOff =
           preventScreenshotOff ?? ScreenProtector.preventScreenshotOff,
       _protectDataLeakageOff =
           protectDataLeakageOff ?? ScreenProtector.protectDataLeakageOff;

  final Future<void> Function() _preventScreenshotOn;
  final Future<void> Function() _protectDataLeakageOn;
  final Future<void> Function() _preventScreenshotOff;
  final Future<void> Function() _protectDataLeakageOff;

  /// Enables screen privacy protection.
  Future<void> enable() async {
    await _preventScreenshotOn();
    await _protectDataLeakageOn();
  }

  /// Disables screen privacy protection.
  Future<void> disable() async {
    await _preventScreenshotOff();
    await _protectDataLeakageOff();
  }
}
