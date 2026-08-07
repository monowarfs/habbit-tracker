import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/repositories/exercise_repository.dart';

/// Drift-backed [ExerciseRepository].
class ExerciseRepositoryImpl implements ExerciseRepository {
  /// Creates a repository backed by [_db].
  ExerciseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ExerciseLog>> watchLogsForDay(
    LocalDate day, {
    required String profileId,
  }) {
    final range = localDayRangeUtc(day);
    return _watchLogsBetween(range.startUtc, range.endUtc, profileId);
  }

  @override
  Stream<List<ExerciseLog>> watchLogsInRange(
    LocalDate start,
    LocalDate end, {
    required String profileId,
  }) {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    return _watchLogsBetween(startUtc, endUtc, profileId);
  }

  Stream<List<ExerciseLog>> _watchLogsBetween(
    DateTime startUtc,
    DateTime endUtc,
    String profileId,
  ) {
    final query = _db.select(_db.exerciseLogsTable)
      ..where(
        (t) =>
            t.profileId.equals(profileId) &
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
  Future<ExerciseLog?> logById(String id, {required String profileId}) async {
    final row =
        await (_db.select(_db.exerciseLogsTable)..where(
              (t) =>
                  t.id.equals(id) &
                  t.profileId.equals(profileId) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _logFromRow(row);
  }

  @override
  Future<List<ExerciseLog>> allLogs({required String profileId}) async {
    final query = _db.select(_db.exerciseLogsTable)
      ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    final rows = await query.get();
    return rows.map(_logFromRow).toList(growable: false);
  }

  @override
  Future<Result<ExerciseLog>> addLog({
    required String exerciseType,
    required int durationMinutes,
    required DateTime loggedAt,
    required String profileId,
    int? calories,
    String? notes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.exerciseLogsTable)
          .insert(
            ExerciseLogsTableCompanion.insert(
              id: id,
              exerciseType: exerciseType,
              durationMinutes: durationMinutes,
              loggedAt: loggedAt.toUtc().millisecondsSinceEpoch,
              calories: Value(calories),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
              profileId: Value(profileId),
            ),
          );
      return Result.success(
        ExerciseLog(
          id: id,
          exerciseType: exerciseType,
          durationMinutes: durationMinutes,
          loggedAt: loggedAt,
          calories: calories,
          notes: notes,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('add_exercise_log', e));
    }
  }

  @override
  Future<Result<void>> deleteLog(
    String id, {
    required String profileId,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(_db.exerciseLogsTable)..where(
                (t) =>
                    t.id.equals(id) &
                    t.profileId.equals(profileId) &
                    t.deletedAt.isNull(),
              ))
              .write(
                ExerciseLogsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('ExerciseLog', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('delete_exercise_log', e));
    }
  }

  @override
  Future<void> wipeAll({required String profileId}) async {
    await (_db.delete(
      _db.exerciseLogsTable,
    )..where((t) => t.profileId.equals(profileId))).go();
  }

  ExerciseLog _logFromRow(ExerciseLogRow row) => ExerciseLog(
    id: row.id,
    exerciseType: row.exerciseType,
    durationMinutes: row.durationMinutes,
    loggedAt: DateTime.fromMillisecondsSinceEpoch(row.loggedAt, isUtc: true),
    calories: row.calories,
    notes: row.notes,
  );
}
