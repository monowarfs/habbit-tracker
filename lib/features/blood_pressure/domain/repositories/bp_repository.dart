import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';

/// Reads and mutates the Blood Pressure module's data.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md` Task 4) — callers pass whatever
/// `activeProfileProvider` currently resolves to.
abstract class BpRepository {
  /// Streams every (non-deleted) reading logged on [day].
  Stream<List<BpLog>> watchLogsForDay(
    LocalDate day, {
    required String profileId,
  });

  /// Streams every (non-deleted) reading with `loggedAt` between [start]
  /// and [end] (inclusive), for stats/history/streak/trend use cases.
  Stream<List<BpLog>> watchLogsInRange(
    LocalDate start,
    LocalDate end, {
    required String profileId,
  });

  /// Looks up a single reading by id, or `null` if it doesn't exist / was
  /// deleted.
  Future<BpLog?> logById(String id, {required String profileId});

  /// Every (non-deleted) reading ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<BpLog>> allLogs({required String profileId});

  /// Records a new reading.
  Future<Result<BpLog>> addLog({
    required int systolic,
    required int diastolic,
    required DateTime loggedAt,
    required String profileId,
    int? pulse,
    String? notes,
  });

  /// Deletes (soft-deletes) a reading.
  Future<Result<void>> deleteLog(String id, {required String profileId});

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll({required String profileId});
}
