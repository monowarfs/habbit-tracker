import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/backup_envelope.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';

/// Builds a [BackupEnvelope] by iterating [modules] (the same "one
/// shared list, zero per-module branching" pattern the dashboard/router
/// already use) plus the shared `common` block. Never includes the PIN
/// hash/salt — those live outside the DB entirely (D-15) and are never
/// exported.
Future<BackupEnvelope> buildExport({
  required List<HabitModule> modules,
  required SettingsRepository settingsRepository,
  required AchievementRepository achievementRepository,
  required String appVersion,
}) async {
  final moduleExports = <String, Map<String, dynamic>>{};
  for (final module in modules) {
    final export = await module.exportData();
    moduleExports[module.id] = export.payload;
  }
  final settings = await settingsRepository.watchSettings().first;
  final achievements = await achievementRepository.watchAll().first;
  return BackupEnvelope(
    schemaVersion: BackupEnvelope.currentSchemaVersion,
    exportedAt: clock.now(),
    appVersion: appVersion,
    modules: moduleExports,
    common: {
      'appSettings': _appSettingsToJson(settings),
      'achievements': achievements.map(_achievementToJson).toList(),
    },
  );
}

Map<String, Object?> _appSettingsToJson(AppSettings settings) => {
  'locale': settings.locale.name,
  'themeMode': settings.themeMode.name,
  'waterUnit': settings.waterUnit.name,
  'pinEnabled': settings.pinEnabled,
  'pinLockTimeoutSeconds': settings.pinLockTimeoutSeconds,
  'biometricEnabled': settings.biometricEnabled,
  'screenPrivacyEnabled': settings.screenPrivacyEnabled,
  'quietHoursEnabled': settings.quietHoursEnabled,
  'quietHoursStart': settings.quietHoursStart.format(),
  'quietHoursEnd': settings.quietHoursEnd.format(),
  'seasonalAccentsEnabled': settings.seasonalAccentsEnabled,
};

Map<String, Object?> _achievementToJson(AchievementRow row) => {
  'moduleId': row.moduleId,
  'key': row.key,
  'progressCurrent': row.progressCurrent,
  'progressTarget': row.progressTarget,
  'unlockedAt': row.unlockedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          row.unlockedAt!,
          isUtc: true,
        ).toIso8601String(),
};
