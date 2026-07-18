import 'package:habit_tracker/core/error/result.dart';
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
}
