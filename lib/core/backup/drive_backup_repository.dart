import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// Drift-backed CRUD over the `drive_backups` table — history of Google
/// Drive backup attempts, used for the "last backup" display
/// (`docs/superpowers/specs/04-premium/01-google-drive-backup-restore-
/// design.md`).
class DriveBackupRepository {
  /// Creates a repository backed by [_db].
  DriveBackupRepository(this._db);

  final AppDatabase _db;

  /// Inserts or updates a backup record by its `id`.
  Future<void> upsertBackup(DriveBackupsTableCompanion companion) {
    return _db.into(_db.driveBackupsTable).insertOnConflictUpdate(companion);
  }

  /// The most recent successful backup, or `null` if none exists — the
  /// "last backup time" display's source.
  Future<DriveBackup?> latestBackup() {
    return (_db.select(_db.driveBackupsTable)
          ..where((t) => t.status.equals('success'))
          ..orderBy([(t) => OrderingTerm.desc(t.backedUpAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Records a new backup attempt as started, returning its id.
  Future<String> markInProgress({
    required String backupFileName,
    required int schemaVersion,
    required DateTime backedUpAt,
  }) async {
    final id = generateId();
    await upsertBackup(
      DriveBackupsTableCompanion.insert(
        id: id,
        backupFileName: backupFileName,
        backedUpAt: backedUpAt.millisecondsSinceEpoch,
        schemaVersion: schemaVersion,
        fileSizeBytes: 0,
        status: 'in_progress',
      ),
    );
    return id;
  }

  /// Marks [backupId] as successfully uploaded.
  Future<void> markComplete(String backupId, int fileSizeBytes) {
    return (_db.update(_db.driveBackupsTable)
          ..where((t) => t.id.equals(backupId)))
        .write(
      DriveBackupsTableCompanion(
        status: const Value('success'),
        fileSizeBytes: Value(fileSizeBytes),
      ),
    );
  }

  /// Marks [backupId] as failed.
  Future<void> markFailed(String backupId) {
    return (_db.update(_db.driveBackupsTable)
          ..where((t) => t.id.equals(backupId)))
        .write(const DriveBackupsTableCompanion(status: Value('failed')));
  }
}
