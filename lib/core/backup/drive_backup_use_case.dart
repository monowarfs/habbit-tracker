import 'dart:convert';
import 'dart:io';

import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/backup_envelope.dart';
import 'package:habit_tracker/core/backup/drive_backup_repository.dart';
import 'package:habit_tracker/core/backup/export_orchestrator.dart';
import 'package:habit_tracker/core/backup/google_drive_backup_target.dart';
import 'package:habit_tracker/core/backup/import_orchestrator.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:path/path.dart' as p;

/// Orchestrates a Google Drive backup: builds the same `BackupEnvelope`
/// the local export uses, uploads it via [driveTarget], and records the
/// attempt in `drive_backups` (`docs/superpowers/specs/04-premium/
/// 01-google-drive-backup-restore-design.md`). Reuses
/// `export_orchestrator.dart` rather than a separate archive format —
/// the local and Drive backups are the exact same envelope, just
/// different `BackupTarget`s.
Future<Result<void>> performBackup({
  required List<HabitModule> modules,
  required SettingsRepository settingsRepository,
  required AchievementRepository achievementRepository,
  required String appVersion,
  required GoogleDriveBackupTarget driveTarget,
  required DriveBackupRepository backupRepository,
}) async {
  const fileName = 'habit_tracker_backup.json';
  final backupId = await backupRepository.markInProgress(
    backupFileName: fileName,
    schemaVersion: BackupEnvelope.currentSchemaVersion,
    backedUpAt: DateTime.now(),
  );
  try {
    final envelope = await buildExport(
      modules: modules,
      settingsRepository: settingsRepository,
      achievementRepository: achievementRepository,
      appVersion: appVersion,
    );
    final json = const JsonEncoder.withIndent('  ').convert(envelope.toJson());
    final file = File(p.join(Directory.systemTemp.path, fileName));
    await file.writeAsString(json);
    await driveTarget.upload(file);
    await backupRepository.markComplete(backupId, json.length);
    return const Result.success(null);
  } on Object catch (e) {
    await backupRepository.markFailed(backupId);
    return Result.failure(AppException.storage('drive_backup', e));
  }
}

/// Downloads the current Drive backup and validates it, without applying
/// anything — the confirmation-dialog step (per-module row counts) reuses
/// `import_orchestrator.dart`'s [ImportPreview]/[validateImport], same as
/// the local restore flow.
Future<Result<ImportPreview>> previewDriveRestore({
  required GoogleDriveBackupTarget driveTarget,
}) async {
  final file = await driveTarget.download();
  if (file == null) {
    return const Result.failure(
      AppException.notFound('drive_backup', 'no backup found on Drive'),
    );
  }
  final String rawJson;
  try {
    rawJson = await file.readAsString();
  } on Object catch (e) {
    return Result.failure(AppException.storage('drive_restore_read', e));
  }
  return validateImport(rawJson);
}

/// Applies a [preview] validated by [previewDriveRestore]: writes a local
/// pre-restore safety copy of the *current* data (best-effort — a failure
/// here doesn't block the restore, since Drive already holds the backup
/// being restored), then delegates to `import_orchestrator.dart`'s
/// [applyImport] — the exact same wipe+restore transaction the local
/// import uses.
Future<Result<void>> applyDriveRestore({
  required ImportPreview preview,
  required List<HabitModule> modules,
  required AppDatabase db,
  required SettingsRepository settingsRepository,
  required AchievementRepository achievementRepository,
  required String appVersion,
}) async {
  try {
    final safetyEnvelope = await buildExport(
      modules: modules,
      settingsRepository: settingsRepository,
      achievementRepository: achievementRepository,
      appVersion: appVersion,
    );
    final safetyFile = File(
      p.join(
        Directory.systemTemp.path,
        'pre_restore_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await safetyFile.writeAsString(jsonEncode(safetyEnvelope.toJson()));
  } on Object {
    // Best-effort only — see doc comment above.
  }

  return applyImport(
    envelope: preview.envelope,
    modules: modules,
    db: db,
    settingsRepository: settingsRepository,
  );
}
