import 'package:drift/drift.dart';

/// Backs `core/analytics/personal_record_repository.dart` — the all-time
/// record (e.g. longest streak) per module (D-17-adjacent,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-design.md`). Persisting the record avoids
/// re-scanning full history on every stats screen load.
@DataClassName('PersonalRecord')
class PersonalRecordsTable extends Table {
  @override
  String get tableName => 'personal_records';

  /// Row id.
  TextColumn get id => text()();

  /// Which module this record belongs to (`'water'` / `'medicine'` /
  /// `'prayer'`).
  TextColumn get moduleId => text()();

  /// `'longest_streak'` is the only record type this run persists;
  /// `'best_adherence'` is reserved by the design doc's schema table for
  /// a future extension.
  TextColumn get recordType => text()();

  /// The record number itself (e.g. days, for `longest_streak`).
  IntColumn get recordValue => integer()();

  /// UTC epoch millis when this record was set.
  IntColumn get achievedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
