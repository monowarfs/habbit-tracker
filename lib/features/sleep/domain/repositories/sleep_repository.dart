import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';

/// Reads and mutates the Sleep module's data.
abstract class SleepRepository {
  /// Streams every (non-deleted) log whose `wakeTime` falls in [day].
  Stream<List<SleepLog>> watchLogsForDay(LocalDate day);

  /// Streams every (non-deleted) log with `wakeTime` between [start] and
  /// [end] (inclusive), for stats/history/streak use cases.
  Stream<List<SleepLog>> watchLogsInRange(LocalDate start, LocalDate end);

  /// Looks up a single log by id (for the edit-entry screen), or `null`
  /// if it doesn't exist / was deleted.
  Future<SleepLog?> logById(String id);

  /// Every (non-deleted) log ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<SleepLog>> allLogs();

  /// Records a new log.
  Future<Result<SleepLog>> addLog({
    required DateTime bedTime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  });

  /// Deletes (soft-deletes) a log.
  Future<Result<void>> deleteLog(String id);

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
