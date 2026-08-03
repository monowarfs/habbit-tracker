import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';

/// Reads and mutates the Mood module's data.
abstract class MoodRepository {
  /// Streams every (non-deleted) check-in logged on [day].
  Stream<List<MoodLog>> watchLogsForDay(LocalDate day);

  /// Streams every (non-deleted) check-in with `loggedAt` between [start]
  /// and [end] (inclusive), for stats/history/streak use cases.
  Stream<List<MoodLog>> watchLogsInRange(LocalDate start, LocalDate end);

  /// Looks up a single check-in by id, or `null` if it doesn't exist /
  /// was deleted.
  Future<MoodLog?> logById(String id);

  /// Every (non-deleted) check-in ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<MoodLog>> allLogs();

  /// Records a new check-in.
  Future<Result<MoodLog>> addLog({
    required int moodValue,
    required DateTime loggedAt,
    String? notes,
  });

  /// Deletes (soft-deletes) a check-in.
  Future<Result<void>> deleteLog(String id);

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
