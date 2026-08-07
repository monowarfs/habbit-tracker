import 'package:drift/drift.dart';

/// Exercise log records — one row per logged workout.
@DataClassName('ExerciseLogRow')
@TableIndex(name: 'idx_exercise_logs_logged_at', columns: {#loggedAt})
class ExerciseLogsTable extends Table {
  @override
  String get tableName => 'exercise_logs';

  /// Row id.
  TextColumn get id => text()();

  /// Free-text workout type (e.g. "Running", "Yoga").
  TextColumn get exerciseType => text()();

  /// Workout duration, minutes.
  IntColumn get durationMinutes => integer()();

  /// UTC epoch millis when this workout was logged.
  IntColumn get loggedAt => integer()();

  /// Calories burned, or null if not recorded.
  IntColumn get calories => integer().nullable()();

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
