import 'dart:io';

/// A destination/source for a backup export file
/// (`strategies/backup-import-export.md`'s seam) — the export/import
/// pipeline itself (envelope shape, validation, migration chain) is
/// entirely target-agnostic, producing/consuming a single [File]. A
/// future `GoogleDriveBackupTarget` is a pure addition implementing
/// this same interface, no change to anything else.
abstract class BackupTarget {
  /// Stable target id (`'local_file'` this run; `'google_drive'` future).
  String get id;

  /// Sends [exportFile] to this target.
  Future<void> upload(File exportFile);

  /// Retrieves a file from this target, or `null` if the user cancelled.
  Future<File?> download();
}
