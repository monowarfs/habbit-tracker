import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';

/// Drift-backed [SleepRepository].
class SleepRepositoryImpl implements SleepRepository {
  /// Creates a repository backed by [_db].
  SleepRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<SleepLog>> watchLogsForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    return _watchLogsBetween(range.startUtc, range.endUtc);
  }

  @override
  Stream<List<SleepLog>> watchLogsInRange(LocalDate start, LocalDate end) {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    return _watchLogsBetween(startUtc, endUtc);
  }

  Stream<List<SleepLog>> _watchLogsBetween(DateTime startUtc, DateTime endUtc) {
    final query = _db.select(_db.sleepLogsTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.wakeTime.isBiggerOrEqualValue(startUtc.millisecondsSinceEpoch) &
            t.wakeTime.isSmallerThanValue(endUtc.millisecondsSinceEpoch),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.wakeTime)]);
    return query.watch().map(
      (rows) => rows.map(_logFromRow).toList(growable: false),
    );
  }

  @override
  Future<SleepLog?> logById(String id) async {
    final row = await (_db.select(
      _db.sleepLogsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _logFromRow(row);
  }

  @override
  Future<List<SleepLog>> allLogs() async {
    final query = _db.select(_db.sleepLogsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.wakeTime)]);
    final rows = await query.get();
    return rows.map(_logFromRow).toList(growable: false);
  }

  @override
  Future<Result<SleepLog>> addLog({
    required DateTime bedTime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      final durationMinutes = wakeTime.difference(bedTime).inMinutes;
      await _db
          .into(_db.sleepLogsTable)
          .insert(
            SleepLogsTableCompanion.insert(
              id: id,
              bedTime: bedTime.toUtc().millisecondsSinceEpoch,
              wakeTime: wakeTime.toUtc().millisecondsSinceEpoch,
              durationMinutes: durationMinutes,
              quality: Value(quality),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        SleepLog(
          id: id,
          bedTime: bedTime,
          wakeTime: wakeTime,
          durationMinutes: durationMinutes,
          quality: quality,
          notes: notes,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('add_sleep_log', e));
    }
  }

  @override
  Future<Result<void>> deleteLog(String id) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(_db.sleepLogsTable)..where(
                (t) => t.id.equals(id) & t.deletedAt.isNull(),
              ))
              .write(
                SleepLogsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('SleepLog', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('delete_sleep_log', e));
    }
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.sleepLogsTable).go();
  }

  SleepLog _logFromRow(SleepLogRow row) => SleepLog(
    id: row.id,
    bedTime: DateTime.fromMillisecondsSinceEpoch(row.bedTime, isUtc: true),
    wakeTime: DateTime.fromMillisecondsSinceEpoch(row.wakeTime, isUtc: true),
    durationMinutes: row.durationMinutes,
    quality: row.quality,
    notes: row.notes,
  );
}
