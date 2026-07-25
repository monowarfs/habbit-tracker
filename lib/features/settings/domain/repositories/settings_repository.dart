import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';

/// Reads and mutates the app's singleton settings row.
abstract class SettingsRepository {
  /// Streams the current settings, seeding sensible defaults on first read
  /// if no row exists yet.
  Stream<AppSettings> watchSettings();

  /// Updates the active locale.
  Future<Result<void>> updateLocale(AppLocale locale);

  /// Updates the active theme mode.
  Future<Result<void>> updateThemeMode(AppThemeMode mode);

  /// Updates the preferred water display unit.
  Future<Result<void>> updateWaterUnit(WaterUnit unit);

  /// Enables or disables PIN lock (the PIN hash itself lives outside
  /// this table, D-15 — this only flips the flag `app_settings.pin_
  /// enabled` records).
  Future<Result<void>> updatePinEnabled({required bool enabled});

  /// Updates the resume-lock timeout, in seconds (0 = immediate).
  Future<Result<void>> updatePinLockTimeoutSeconds(int seconds);

  /// Enables or disables offering biometric unlock on `/lock`.
  Future<Result<void>> updateBiometricEnabled({required bool enabled});

  /// Enables or disables screen-privacy protection (`FLAG_SECURE`/
  /// app-switcher blur).
  Future<Result<void>> updateScreenPrivacyEnabled({required bool enabled});

  /// Enables or disables the in-app dose-done completion chime.
  Future<Result<void>> updateSoundEnabled({required bool enabled});

  /// Records the app version the user last saw the changelog for.
  Future<Result<void>> updateLastSeenAppVersion(String version);

  /// Updates the quiet-hours window and enabled state atomically.
  Future<Result<void>> updateQuietHours({
    required bool enabled,
    required LocalTime start,
    required LocalTime end,
  });

  /// Updates the display name shown in the dashboard greeting. `null`/
  /// empty clears it back to the name-less greeting.
  Future<Result<void>> updateDisplayName(String? name);

  /// Enables or disables the seasonal accent-color shift (Pohela
  /// Boishakh today; Eid once a Hijri date source exists).
  Future<Result<void>> updateSeasonalAccentsEnabled({required bool enabled});

  /// Marks the Water hydration-science "why this matters" card as shown
  /// — it never renders again after this.
  Future<Result<void>> markWaterHydrationHintSeen();

  /// Marks the Prayer Qadha-context "why this matters" card as shown —
  /// it never renders again after this.
  Future<Result<void>> markPrayerQadhaHintSeen();

  /// Manual Ramadan-mode override: `true`/`false` pins it, `null` clears
  /// the override back to auto-detection.
  Future<Result<void>> updateRamadanModeManualOverride(bool? override);

  /// Enables or disables Hijri-calendar Ramadan auto-detection.
  Future<Result<void>> updateRamadanAutoDetectEnabled({required bool enabled});

  /// Enables or disables adaptive reminder timing (auto-shifting reminder
  /// times based on historical response offsets).
  Future<Result<void>> updateAdaptiveReminderEnabled({required bool enabled});

  /// Records the app install date. Called once on first launch; subsequent
  /// calls are no-ops (the column is never overwritten after migration 10
  /// seeds it from `created_at` for pre-existing installs).
  Future<Result<void>> updateInstallDate(DateTime date);

  /// Enables or disables the yearly recap feature.
  Future<Result<void>> updateRecapEnabled({required bool enabled});

  /// Updates the last year a recap was generated (implementation detail,
  /// prevents re-triggering).
  Future<Result<void>> updateLastRecapYear(int year);

  /// Updates the user's most recent activity timestamp (any module write).
  Future<Result<void>> updateLastActivityAt(DateTime date);

  /// Records when a re-engagement nudge was last sent.
  Future<Result<void>> updateNudgeSentAfter(DateTime date);

  /// Enables or disables the re-engagement nudge feature.
  Future<Result<void>> updateReengagementNudgeEnabled({required bool enabled});

  /// Restores locale/theme/water-unit/PIN-enabled/PIN-timeout wholesale
  /// — import's replace step (`core/backup/import_orchestrator.dart`).
  /// PIN hash/salt are never part of this — those live outside the DB
  /// entirely (D-15) and are restored, if at all, by the user re-
  /// entering a PIN after import, same as a fresh install.
  Future<Result<void>> restoreSettings(AppSettings settings);
}
