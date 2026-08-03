import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/repositories/mood_repository.dart';

/// Drift-backed [MoodRepository].
class MoodRepositoryImpl implements MoodRepository {
  /// Creates a repository backed by [_db].
  MoodRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<MoodLog>> watchLogsForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    return _watchLogsBetween(range.startUtc, range.endUtc);
  }

  @override
  Stream<List<MoodLog>> watchLogsInRange(LocalDate start, LocalDate end) {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    return _watchLogsBetween(startUtc, endUtc);
  }

  Stream<List<MoodLog>> _watchLogsBetween(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    final query = _db.select(_db.moodLogsTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.loggedAt.isBiggerOrEqualValue(startUtc.millisecondsSinceEpoch) &
            t.loggedAt.isSmallerThanValue(endUtc.millisecondsSinceEpoch),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    return query.watch().map(
      (rows) => rows.map(_logFromRow).toList(growable: false),
    );
  }

  @override
  Future<MoodLog?> logById(String id) async {
    final row = await (_db.select(
      _db.moodLogsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _logFromRow(row);
  }

  @override
  Future<List<MoodLog>> allLogs() async {
    final query = _db.select(_db.moodLogsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    final rows = await query.get();
    return rows.map(_logFromRow).toList(growable: false);
  }

  @override
  Future<Result<MoodLog>> addLog({
    required int moodValue,
    required DateTime loggedAt,
    String? notes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.moodLogsTable)
          .insert(
            MoodLogsTableCompanion.insert(
              id: id,
              moodValue: moodValue,
              loggedAt: loggedAt.toUtc().millisecondsSinceEpoch,
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        MoodLog(
          id: id,
          moodValue: moodValue,
          loggedAt: loggedAt,
          notes: notes,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('add_mood_log', e));
    }
  }

  @override
  Future<Result<void>> deleteLog(String id) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(_db.moodLogsTable)..where(
                (t) => t.id.equals(id) & t.deletedAt.isNull(),
              ))
              .write(
                MoodLogsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('MoodLog', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('delete_mood_log', e));
    }
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.moodLogsTable).go();
  }

  MoodLog _logFromRow(MoodLogRow row) => MoodLog(
    id: row.id,
    moodValue: row.moodValue,
    loggedAt: DateTime.fromMillisecondsSinceEpoch(row.loggedAt, isUtc: true),
    notes: row.notes,
  );
}
