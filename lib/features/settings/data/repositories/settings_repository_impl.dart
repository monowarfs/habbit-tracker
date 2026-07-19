import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';

const _singletonId = 'singleton';

/// Drift-backed [SettingsRepository].
class SettingsRepositoryImpl implements SettingsRepository {
  /// Creates a repository backed by [_db]. [defaultLocale] resolves the
  /// locale a first-ever launch seeds the singleton row with — defaults to
  /// the device's locale, overridable for tests.
  SettingsRepositoryImpl(this._db, {AppLocale Function()? defaultLocale})
    : _defaultLocale = defaultLocale ?? _systemDefaultLocale;

  final AppDatabase _db;
  final AppLocale Function() _defaultLocale;

  static AppLocale _systemDefaultLocale() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code == 'bn' ? AppLocale.bn : AppLocale.en;
  }

  @override
  Stream<AppSettings> watchSettings() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      final query = _db.select(_db.appSettingsTable)
        ..where((t) => t.id.equals(_singletonId));
      return query.watchSingle().map(_toDomain);
    });
  }

  Future<void> _ensureSeeded() async {
    final existing = await (_db.select(
      _db.appSettingsTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing != null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            id: _singletonId,
            locale: _defaultLocale().toDb(),
            themeMode: AppThemeMode.system.toDb(),
            waterUnit: WaterUnit.ml.toDb(),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<Result<void>> updateLocale(AppLocale locale) =>
      _update(AppSettingsTableCompanion(locale: Value(locale.toDb())));

  @override
  Future<Result<void>> updateThemeMode(AppThemeMode mode) =>
      _update(AppSettingsTableCompanion(themeMode: Value(mode.toDb())));

  @override
  Future<Result<void>> updateWaterUnit(WaterUnit unit) =>
      _update(AppSettingsTableCompanion(waterUnit: Value(unit.toDb())));

  @override
  Future<Result<void>> updatePinEnabled({required bool enabled}) =>
      _update(AppSettingsTableCompanion(pinEnabled: Value(enabled)));

  @override
  Future<Result<void>> updatePinLockTimeoutSeconds(int seconds) => _update(
    AppSettingsTableCompanion(pinLockTimeoutSeconds: Value(seconds)),
  );

  Future<Result<void>> _update(AppSettingsTableCompanion patch) async {
    try {
      await _ensureSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.appSettingsTable,
      )..where((t) => t.id.equals(_singletonId))).write(
        patch.copyWith(updatedAt: Value(now)),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_settings', e));
    }
  }

  AppSettings _toDomain(AppSettingsRow row) => AppSettings(
    locale: AppLocaleDb.fromDb(row.locale),
    themeMode: AppThemeModeDb.fromDb(row.themeMode),
    waterUnit: WaterUnitDb.fromDb(row.waterUnit),
    pinEnabled: row.pinEnabled,
    pinLockTimeoutSeconds: row.pinLockTimeoutSeconds,
    onboardingCompletedAt: row.onboardingCompletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.onboardingCompletedAt!,
            isUtc: true,
          ),
  );
}

/// `AppLocale` <-> DB string mapping, by explicit literal
/// (`../../../../technical/data-models.md`'s type-mapping convention) —
/// never `EnumName.values.byName`, so a stored value never silently breaks
/// if the enum is reordered.
extension AppLocaleDb on AppLocale {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    AppLocale.en => 'en',
    AppLocale.bn => 'bn',
  };

  /// Parses a stored DB string back to [AppLocale].
  static AppLocale fromDb(String value) => switch (value) {
    'bn' => AppLocale.bn,
    _ => AppLocale.en,
  };
}

/// `AppThemeMode` <-> DB string mapping, same convention as [AppLocaleDb].
extension AppThemeModeDb on AppThemeMode {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };

  /// Parses a stored DB string back to [AppThemeMode].
  static AppThemeMode fromDb(String value) => switch (value) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };
}

/// `WaterUnit` <-> DB string mapping, same convention as [AppLocaleDb].
extension WaterUnitDb on WaterUnit {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    WaterUnit.ml => 'ml',
    WaterUnit.flOz => 'fl_oz',
  };

  /// Parses a stored DB string back to [WaterUnit].
  static WaterUnit fromDb(String value) => switch (value) {
    'fl_oz' => WaterUnit.flOz,
    _ => WaterUnit.ml,
  };
}
