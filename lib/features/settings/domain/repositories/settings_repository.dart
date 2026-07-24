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

  /// Restores locale/theme/water-unit/PIN-enabled/PIN-timeout wholesale
  /// — import's replace step (`core/backup/import_orchestrator.dart`).
  /// PIN hash/salt are never part of this — those live outside the DB
  /// entirely (D-15) and are restored, if at all, by the user re-
  /// entering a PIN after import, same as a fresh install.
  Future<Result<void>> restoreSettings(AppSettings settings);
}
