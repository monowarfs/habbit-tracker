import 'package:drift/drift.dart';

/// Sleep log records — one row per night's sleep entry.
@DataClassName('SleepLogRow')
@TableIndex(name: 'idx_sleep_logs_wake_time', columns: {#wakeTime})
class SleepLogsTable extends Table {
  @override
  String get tableName => 'sleep_logs';

  /// Row id.
  TextColumn get id => text()();

  /// UTC epoch millis when the user went to bed.
  IntColumn get bedTime => integer()();

  /// UTC epoch millis when the user woke up.
  IntColumn get wakeTime => integer()();

  /// Computed `wakeTime - bedTime`, in minutes.
  IntColumn get durationMinutes => integer()();

  /// Self-rated sleep quality, 1-5, or null if not rated.
  IntColumn get quality => integer().nullable()();

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
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
