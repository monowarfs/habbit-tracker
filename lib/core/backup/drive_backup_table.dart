import 'package:drift/drift.dart';

/// Metadata about each Google Drive backup attempt (`docs/superpowers/
/// specs/04-premium/01-google-drive-backup-restore-design.md`) — the
/// backup content itself lives on Drive, this table only tracks the
/// history/status of upload attempts for the "last backup" display.
@DataClassName('DriveBackup')
class DriveBackupsTable extends Table {
  @override
  String get tableName => 'drive_backups';

  /// Row id.
  TextColumn get id => text()();

  /// The uploaded file's name on Drive.
  TextColumn get backupFileName => text()();

  /// UTC epoch millis when this backup was attempted.
  IntColumn get backedUpAt => integer()();

  /// The `BackupEnvelope.schemaVersion` this backup was created at.
  IntColumn get schemaVersion => integer()();

  /// Uploaded file size in bytes, `0` until the upload succeeds.
  IntColumn get fileSizeBytes => integer()();

  /// `'success'` | `'failed'` | `'in_progress'`.
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}
