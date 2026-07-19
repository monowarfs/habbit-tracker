import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:habit_tracker/core/backup/backup_target.dart';
import 'package:share_plus/share_plus.dart';

/// The only [BackupTarget] this run ships — `upload` opens the OS share
/// sheet (which already includes "save to Files"/"save to device" on
/// both platforms, so this covers both "share" and "save" without two
/// code paths); `download` opens a single-file JSON picker.
class LocalFileBackupTarget implements BackupTarget {
  @override
  String get id => 'local_file';

  @override
  Future<void> upload(File exportFile) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(exportFile.path)]),
    );
  }

  @override
  Future<File?> download() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }
}
