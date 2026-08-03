import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';

/// Reads and mutates the Blood Pressure module's data.
abstract class BpRepository {
  /// Streams every (non-deleted) reading logged on [day].
  Stream<List<BpLog>> watchLogsForDay(LocalDate day);

  /// Streams every (non-deleted) reading with `loggedAt` between [start]
  /// and [end] (inclusive), for stats/history/streak/trend use cases.
  Stream<List<BpLog>> watchLogsInRange(LocalDate start, LocalDate end);

  /// Looks up a single reading by id, or `null` if it doesn't exist / was
  /// deleted.
  Future<BpLog?> logById(String id);

  /// Every (non-deleted) reading ever recorded, oldest first — export
  /// groundwork and streak/achievement calculations.
  Future<List<BpLog>> allLogs();

  /// Records a new reading.
  Future<Result<BpLog>> addLog({
    required int systolic,
    required int diastolic,
    required DateTime loggedAt,
    int? pulse,
    String? notes,
  });

  /// Deletes (soft-deletes) a reading.
  Future<Result<void>> deleteLog(String id);

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
