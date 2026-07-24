import 'dart:convert';

import 'package:habit_tracker/core/backup/backup_envelope.dart';
import 'package:habit_tracker/core/backup/wipe_all_data.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:meta/meta.dart';

/// Migration chain seam — no steps exist yet since only schema version 1
/// has ever shipped; a future v2 adds `1: migrateV1ToV2` (a pure
/// `Map<String, dynamic> Function(Map<String, dynamic>)`) here, one
/// version-step function per bump, the same "one small step at a time"
/// shape as a DB schema migration (`strategies/backup-import-export.md`).
const Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
_migrations = {};

/// A validated, not-yet-applied import: the parsed envelope plus a
/// per-module row count for the confirmation screen.
@immutable
class ImportPreview {
  /// Creates an import preview.
  const ImportPreview(this.envelope, this.countsByModule);

  /// The validated (and, if needed, migrated-forward) envelope.
  final BackupEnvelope envelope;

  /// `moduleId -> total row count across that module's export keys`.
  final Map<String, int> countsByModule;
}

/// Parses and validates [rawJson] into an [ImportPreview], per
/// `strategies/backup-import-export.md`'s ordered validation: JSON
/// shape, schema version (reject newer; migrate forward if older), then
/// the envelope's required top-level fields. No database write happens
/// here — [applyImport] is a separate, explicit step.
Future<Result<ImportPreview>> validateImport(String rawJson) async {
  final Map<String, dynamic> json;
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const Result.failure(
        AppException.validation(
          'envelope',
          'File is not a valid backup envelope',
        ),
      );
    }
    json = decoded;
  } on FormatException {
    return const Result.failure(
      AppException.validation('json', 'File is not valid JSON'),
    );
  }

  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    return const Result.failure(
      AppException.validation(
        'schemaVersion',
        'Missing or invalid schema version',
      ),
    );
  }
  if (schemaVersion > BackupEnvelope.currentSchemaVersion) {
    return const Result.failure(
      AppException.validation(
        'schemaVersion',
        'This backup was made with a newer version of the app — update '
            'the app first',
      ),
    );
  }

  var working = json;
  var version = schemaVersion;
  while (version < BackupEnvelope.currentSchemaVersion) {
    final migrate = _migrations[version];
    if (migrate == null) {
      return const Result.failure(
        AppException.validation(
          'schemaVersion',
          'Unsupported backup schema version',
        ),
      );
    }
    working = migrate(working);
    version += 1;
  }

  try {
    final modules = working['modules'];
    final common = working['common'];
    final exportedAt = working['exportedAt'];
    final appVersion = working['appVersion'];
    if (modules is! Map<String, dynamic> ||
        common is! Map<String, dynamic> ||
        exportedAt is! String ||
        appVersion is! String) {
      return const Result.failure(
        AppException.validation(
          'envelope',
          'Backup file is missing required fields',
        ),
      );
    }
    final envelope = BackupEnvelope(
      schemaVersion: version,
      exportedAt: DateTime.parse(exportedAt),
      appVersion: appVersion,
      modules: modules.map(
        (key, value) => MapEntry(key, value as Map<String, dynamic>),
      ),
      common: common,
    );
    final counts = {
      for (final entry in envelope.modules.entries)
        entry.key: _countRows(entry.value),
    };
    return Result.success(ImportPreview(envelope, counts));
  } on Object {
    return const Result.failure(
      AppException.validation('envelope', 'Backup file is malformed'),
    );
  }
}

int _countRows(Map<String, dynamic> payload) {
  var total = 0;
  for (final value in payload.values) {
    if (value is List) total += value.length;
  }
  return total;
}

/// Applies a validated [envelope]: wipes every module/common table
/// (`wipeAllAppData`) then restores every module plus `common
/// .appSettings`, all inside one transaction — a thrown exception
/// anywhere in this rolls the whole thing back, leaving existing data
/// untouched (`strategies/backup-import-export.md`'s replace semantics).
Future<Result<void>> applyImport({
  required BackupEnvelope envelope,
  required List<HabitModule> modules,
  required AppDatabase db,
  required SettingsRepository settingsRepository,
}) async {
  try {
    await db.transaction(() async {
      await wipeAllAppData(modules, db);
      for (final module in modules) {
        final payload = envelope.modules[module.id];
        if (payload != null) await module.importData(ModuleExport(payload));
      }
      final appSettingsJson =
          envelope.common['appSettings'] as Map<String, dynamic>?;
      if (appSettingsJson != null) {
        await settingsRepository.restoreSettings(
          AppSettings(
            locale: AppLocale.values.byName(
              appSettingsJson['locale'] as String,
            ),
            themeMode: AppThemeMode.values.byName(
              appSettingsJson['themeMode'] as String,
            ),
            waterUnit: WaterUnit.values.byName(
              appSettingsJson['waterUnit'] as String,
            ),
            pinEnabled: appSettingsJson['pinEnabled'] as bool,
            pinLockTimeoutSeconds:
                appSettingsJson['pinLockTimeoutSeconds'] as int,
            // `?? true`/`?? false` fallback: an older export made before
            // these two fields existed must still import cleanly, at the
            // same defaults a fresh install gets.
            biometricEnabled:
                appSettingsJson['biometricEnabled'] as bool? ?? true,
            screenPrivacyEnabled:
                appSettingsJson['screenPrivacyEnabled'] as bool? ?? false,
            soundEnabled: appSettingsJson['soundEnabled'] as bool? ?? false,
            quietHoursEnabled:
                appSettingsJson['quietHoursEnabled'] as bool? ?? false,
            quietHoursStart: LocalTime.parse(
              appSettingsJson['quietHoursStart'] as String? ?? '22:00',
            ),
            quietHoursEnd: LocalTime.parse(
              appSettingsJson['quietHoursEnd'] as String? ?? '07:00',
            ),
          ),
        );
      }
    });
    return const Result.success(null);
  } on Object catch (e) {
    return Result.failure(AppException.storage('apply_import', e));
  }
}
