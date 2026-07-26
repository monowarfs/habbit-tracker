import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:habit_tracker/core/backup/backup_target.dart';
import 'package:habit_tracker/core/backup/drive_auth_service.dart';

/// A [BackupTarget] that stores the backup in the user's Google Drive
/// `appDataFolder` — a per-app hidden space invisible in the user's own
/// Drive UI, requiring only the narrow `drive.appdata` scope
/// (`docs/superpowers/specs/04-premium/01-google-drive-backup-restore-
/// design.md`). This is the "pure addition implementing [BackupTarget]"
/// that interface's own docstring anticipated — [upload]/[download]
/// slot into the same target-agnostic export/import pipeline
/// `LocalFileBackupTarget` already uses, no changes there.
class GoogleDriveBackupTarget implements BackupTarget {
  /// Creates a target backed by [authService] (a real [DriveAuthService]
  /// by default, overridable for tests).
  GoogleDriveBackupTarget({DriveAuthService? authService})
    : _authService = authService ?? DriveAuthService();

  final DriveAuthService _authService;

  static const _fileName = 'habit_tracker_backup.json';

  @override
  String get id => 'google_drive';

  @override
  Future<void> upload(File exportFile) => _withApi((api) async {
    final bytes = await exportFile.readAsBytes();
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final existingId = await _existingBackupFileId(api);
    if (existingId != null) {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File(name: _fileName, parents: ['appDataFolder']),
        uploadMedia: media,
      );
    }
  });

  @override
  Future<File?> download() => _withApi((api) async {
    final fileId = await _existingBackupFileId(api);
    if (fileId == null) return null;
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final bytes = <int>[];
    await media.stream.forEach(bytes.addAll);
    final dir = await Directory.systemTemp.createTemp('drive_backup_');
    final file = File('${dir.path}/$_fileName');
    await file.writeAsBytes(bytes);
    return file;
  });

  /// The Drive-reported modification time of the current backup file, or
  /// `null` if none exists yet — a fallback "last backup" source
  /// independent of the local `drive_backups` table (survives a
  /// reinstall/new device, unlike that local history).
  Future<DateTime?> getLastBackupTime() => _withApi((api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id, modifiedTime)',
    );
    return files.files?.firstOrNull?.modifiedTime;
  });

  /// Runs [action] against a freshly authorized [drive.DriveApi], always
  /// closing the underlying HTTP client afterward — `DriveAuthService
  /// .authorizedHttpClient` hands back a new client per call, so nothing
  /// else owns its lifecycle.
  Future<T> _withApi<T>(Future<T> Function(drive.DriveApi api) action) async {
    final client = await _authService.authorizedHttpClient();
    try {
      return await action(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }

  Future<String?> _existingBackupFileId(drive.DriveApi api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id)',
    );
    return files.files?.firstOrNull?.id;
  }
}
