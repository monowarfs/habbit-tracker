import 'package:meta/meta.dart';

/// The JSON export/import envelope (`strategies/backup-import-export.md`).
/// A plain class, not Freezed — this is a serialization boundary type,
/// not a domain entity.
@immutable
class BackupEnvelope {
  /// Creates a backup envelope.
  const BackupEnvelope({
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.modules,
    required this.common,
  });

  /// The schema version this run of the app produces/expects.
  static const currentSchemaVersion = 1;

  /// The envelope's own schema version (distinct from
  /// `AppDatabase.schemaVersion` — this versions the JSON wire format,
  /// not the local DB schema).
  final int schemaVersion;

  /// When this export was built.
  final DateTime exportedAt;

  /// The app version string that produced this export.
  final String appVersion;

  /// `moduleId -> that module's `ModuleExport.payload``.
  final Map<String, Map<String, dynamic>> modules;

  /// Non-module shared data: `appSettings`, `achievements`.
  final Map<String, dynamic> common;

  /// The JSON-encodable representation.
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'appVersion': appVersion,
    'modules': modules,
    'common': common,
  };
}
