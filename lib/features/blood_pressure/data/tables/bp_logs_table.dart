import 'package:drift/drift.dart';

/// Blood-pressure reading records — one row per logged reading.
@DataClassName('BpLogRow')
@TableIndex(name: 'idx_bp_logs_logged_at', columns: {#loggedAt})
class BpLogsTable extends Table {
  @override
  String get tableName => 'bp_logs';

  /// Row id.
  TextColumn get id => text()();

  /// Systolic pressure, mmHg.
  IntColumn get systolic => integer()();

  /// Diastolic pressure, mmHg.
  IntColumn get diastolic => integer()();

  /// UTC epoch millis when this reading was taken.
  IntColumn get loggedAt => integer()();

  /// AHA classification, computed at write time (see
  /// `ClassifyBpUseCase`) — stored, not recomputed on read, matching
  /// `sleep_logs.durationMinutes`'s precedent.
  TextColumn get classification => text()();

  /// Pulse, bpm, or null if not recorded.
  IntColumn get pulse => integer().nullable()();

  /// Free-text notes, or null.
  TextColumn get notes => text().nullable()();

  /// UTC epoch millis when this row was created.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis when this row was last updated.
  IntColumn get updatedAt => integer()();

  /// UTC epoch millis when this row was soft-deleted, or null if active.
  IntColumn get deletedAt => integer().nullable()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
