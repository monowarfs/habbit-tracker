import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's single [Logger] instance
/// (`strategies/error-handling-logging.md`).
///
/// Release builds cap the minimum level at [Level.warning] — verbose/debug
/// output never ships — as a build-time configuration, not a per-call-site
/// decision.
final Logger logger = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: SimplePrinter(),
  output: MultiOutput([ConsoleOutput(), _RotatingFileOutput()]),
);

/// Builds a log-safe reference for an entity — type + stable id only,
/// never its content. Log calls must never pass a domain object directly
/// (its generated `toString()` would include every field); build an
/// explicit string via this helper instead
/// (`strategies/error-handling-logging.md`'s unconditional redaction rule).
String entityRef(String type, String id) => '$type#$id';

/// Logs an [AppException] at the severity its variant maps to
/// ([severityOf]), including cause/stack trace where the taxonomy calls
/// for it.
void logException(AppException exception) {
  switch (exception) {
    case ValidationException(:final field, :final message):
      logger.w('validation failed: field=$field message=$message');
    case NotFoundException(:final entity, :final id):
      logger.w('not found: ${entityRef(entity, id)}');
    case StorageException(:final operation, :final cause):
      logger.e('storage error: operation=$operation', error: cause);
    case PermissionException(:final permission):
      logger.i('permission denied: $permission');
    case UnexpectedException(:final cause, :final trace):
      logger.e('unexpected error', error: cause, stackTrace: trace);
  }
}

/// The on-disk log files, oldest first, for the future "share diagnostic
/// logs" action (UI arrives in Run 12).
Future<List<File>> logFilesForSharing() async {
  final dir = await getApplicationSupportDirectory();
  final old = File(p.join(dir.path, _RotatingFileOutput._fileNameOld));
  final current = File(p.join(dir.path, _RotatingFileOutput._fileName));
  return [if (old.existsSync()) old, if (current.existsSync()) current];
}

/// Caps on-disk logs at ~1MB via a single-backup rotation
/// (`strategies/error-handling-logging.md`'s ring-buffer requirement) — a
/// two-file rotation approximates a ring buffer without the complexity of
/// a true circular byte buffer, which this app's log volume doesn't need.
class _RotatingFileOutput extends LogOutput {
  static const int _maxBytes = 1024 * 1024;
  static const _fileName = 'app_logs.log';
  static const _fileNameOld = 'app_logs.log.old';

  File? _file;
  Future<void>? _initFuture;

  Future<void> _ensureInit() {
    return _initFuture ??= () async {
      final dir = await getApplicationSupportDirectory();
      _file = File(p.join(dir.path, _fileName));
    }();
  }

  @override
  void output(OutputEvent event) {
    unawaited(_write(event));
  }

  Future<void> _write(OutputEvent event) async {
    await _ensureInit();
    final file = _file;
    if (file == null) return;
    await file.writeAsString(
      '${event.lines.join('\n')}\n',
      mode: FileMode.append,
    );
    if (await file.length() <= _maxBytes) return;
    final old = File(p.join(file.parent.path, _fileNameOld));
    if (old.existsSync()) old.deleteSync();
    file.renameSync(old.path);
    _file = File(file.path);
  }
}
