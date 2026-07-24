import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'app_settings.freezed.dart';

/// The app's display language (`../../../../technical/data-models.md`).
enum AppLocale {
  /// English.
  en,

  /// Bangla.
  bn,
}

/// The app's theme preference — a domain-owned equivalent of Flutter's
/// `ThemeMode`, kept separate so nothing in `domain/` imports Flutter
/// (`../../../../technical/architecture.md`'s dependency rule). The
/// presentation layer maps to/from `ThemeMode` at its own boundary.
enum AppThemeMode {
  /// Follow the device's theme setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Display unit for water amounts (D-01) — the canonical stored unit is
/// always ml regardless of this setting.
enum WaterUnit {
  /// Milliliters.
  ml,

  /// Fluid ounces.
  flOz,
}

/// The app's singleton settings row, domain-shaped
/// (`../../../../technical/data-models.md`).
@freezed
sealed class AppSettings with _$AppSettings {
  /// Creates an [AppSettings] value.
  const factory AppSettings({
    required AppLocale locale,
    required AppThemeMode themeMode,
    required WaterUnit waterUnit,
    required bool pinEnabled,
    required int pinLockTimeoutSeconds,
    required bool biometricEnabled,
    required bool screenPrivacyEnabled,
    required bool soundEnabled,
    DateTime? onboardingCompletedAt,
    String? lastSeenAppVersion,
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
    String? displayName,
  }) = _AppSettings;
}
