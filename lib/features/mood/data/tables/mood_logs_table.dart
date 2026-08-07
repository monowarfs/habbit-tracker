import 'package:drift/drift.dart';

/// Mood check-in records — one row per logged check-in.
@DataClassName('MoodLogRow')
@TableIndex(name: 'idx_mood_logs_logged_at', columns: {#loggedAt})
class MoodLogsTable extends Table {
  @override
  String get tableName => 'mood_logs';

  /// Row id.
  TextColumn get id => text()();

  /// Self-rated mood, 1-5.
  IntColumn get moodValue => integer()();

  /// UTC epoch millis when this check-in was logged.
  IntColumn get loggedAt => integer()();

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
