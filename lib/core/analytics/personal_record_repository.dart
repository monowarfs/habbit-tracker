import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// Drift-backed CRUD over the `personal_records` table (Task 1,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`) — the source of
/// truth for each module's all-time record, so stats screens don't need
/// to re-scan full history on every load.
class PersonalRecordRepository {
  /// Creates a repository backed by [_db].
  PersonalRecordRepository(this._db);

  final AppDatabase _db;

  /// The persisted record for [moduleId]/[recordType], or `null` if none
  /// has been set yet.
  Future<PersonalRecord?> getRecord({
    required String moduleId,
    required String recordType,
  }) {
    return (_db.select(_db.personalRecordsTable)..where(
          (t) =>
              t.moduleId.equals(moduleId) & t.recordType.equals(recordType),
        ))
        .getSingleOrNull();
  }

  /// Creates or overwrites the record for [moduleId]/[recordType] with
  /// [value], stamped with the current time.
  Future<void> setRecord({
    required String moduleId,
    required String recordType,
    required int value,
  }) async {
    final now = clock.now().millisecondsSinceEpoch;
    final existing = await getRecord(
      moduleId: moduleId,
      recordType: recordType,
    );
    if (existing == null) {
      await _db
          .into(_db.personalRecordsTable)
          .insert(
            PersonalRecordsTableCompanion.insert(
              id: generateId(),
              moduleId: moduleId,
              recordType: recordType,
              recordValue: value,
              achievedAt: now,
            ),
          );
      return;
    }
    await (_db.update(
      _db.personalRecordsTable,
    )..where((t) => t.id.equals(existing.id))).write(
      PersonalRecordsTableCompanion(
        recordValue: Value(value),
        achievedAt: Value(now),
      ),
    );
  }

  /// Checks if [newValue] exceeds the current record for
  /// [moduleId]/[recordType]. If so, persists it via [setRecord] and
  /// returns `true` — `false` if [newValue] doesn't beat (or only ties)
  /// the existing record.
  Future<bool> checkAndUpdate({
    required String moduleId,
    required String recordType,
    required int newValue,
  }) async {
    final existing = await getRecord(
      moduleId: moduleId,
      recordType: recordType,
    );
    if (existing != null && newValue <= existing.recordValue) return false;
    await setRecord(
      moduleId: moduleId,
      recordType: recordType,
      value: newValue,
    );
    return true;
  }
}
