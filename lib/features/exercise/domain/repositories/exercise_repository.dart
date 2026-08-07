import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';

/// Reads and mutates the Exercise module's data.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md` Task 4) — callers pass whatever
/// `activeProfileProvider` currently resolves to.
abstract class ExerciseRepository {
  /// Streams every (non-deleted) workout logged on [day].
  Stream<List<ExerciseLog>> watchLogsForDay(
    LocalDate day, {
    required String profileId,
  });

  /// Streams every (non-deleted) workout with `loggedAt` between [start]
  /// and [end] (inclusive), for stats/history/streak use cases.
  Stream<List<ExerciseLog>> watchLogsInRange(
    LocalDate start,
    LocalDate end, {
    required String profileId,
  });

  /// Looks up a single workout by id, or `null` if it doesn't exist /
  /// was deleted.
  Future<ExerciseLog?> logById(String id, {required String profileId});

  /// Every (non-deleted) workout ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<ExerciseLog>> allLogs({required String profileId});

  /// Records a new workout.
  Future<Result<ExerciseLog>> addLog({
    required String exerciseType,
    required int durationMinutes,
    required DateTime loggedAt,
    required String profileId,
    int? calories,
    String? notes,
  });

  /// Deletes (soft-deletes) a workout.
  Future<Result<void>> deleteLog(String id, {required String profileId});

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll({required String profileId});
}
