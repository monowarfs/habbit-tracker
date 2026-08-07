import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';

/// Reads and mutates the Sleep module's data.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md` Task 4) — callers pass whatever
/// `activeProfileProvider` currently resolves to.
abstract class SleepRepository {
  /// Streams every (non-deleted) log whose `wakeTime` falls in [day].
  Stream<List<SleepLog>> watchLogsForDay(
    LocalDate day, {
    required String profileId,
  });

  /// Streams every (non-deleted) log with `wakeTime` between [start] and
  /// [end] (inclusive), for stats/history/streak use cases.
  Stream<List<SleepLog>> watchLogsInRange(
    LocalDate start,
    LocalDate end, {
    required String profileId,
  });

  /// Looks up a single log by id (for the edit-entry screen), or `null`
  /// if it doesn't exist / was deleted.
  Future<SleepLog?> logById(String id, {required String profileId});

  /// Every (non-deleted) log ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<SleepLog>> allLogs({required String profileId});

  /// Records a new log.
  Future<Result<SleepLog>> addLog({
    required DateTime bedTime,
    required DateTime wakeTime,
    required String profileId,
    int? quality,
    String? notes,
  });

  /// Deletes (soft-deletes) a log.
  Future<Result<void>> deleteLog(String id, {required String profileId});

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll({required String profileId});
}
