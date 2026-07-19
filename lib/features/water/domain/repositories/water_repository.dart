import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';

/// Reads and mutates the Water module's data.
abstract class WaterRepository {
  /// Streams every (non-deleted) entry logged on [day].
  Stream<List<WaterEntry>> watchEntriesForDay(LocalDate day);

  /// Streams every (non-deleted) entry with `loggedAt` between [start] and
  /// [end] (inclusive), for stats/history/streak use cases.
  Stream<List<WaterEntry>> watchEntriesInRange(LocalDate start, LocalDate end);

  /// Looks up a single entry by id (for the edit-entry screen), or `null`
  /// if it doesn't exist / was deleted.
  Future<WaterEntry?> entryById(String id);

  /// Streams the current (latest) goal.
  Stream<WaterGoal> watchCurrentGoal();

  /// All goal-history rows, oldest first — the raw material
  /// `ResolveGoalForDateUseCase`/`CalculateWaterStreakUseCase` resolve
  /// per-day goals from.
  Future<List<WaterGoal>> allGoals();

  /// Every (non-deleted) entry ever logged, oldest first — export
  /// groundwork (`strategies/backup-import-export.md`).
  Future<List<WaterEntry>> allEntries();

  /// Logs a new entry.
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
  });

  /// Updates an existing entry's amount and/or timestamp (FR-W-09).
  Future<Result<void>> updateEntry(
    String id, {
    int? amountMl,
    DateTime? loggedAt,
  });

  /// Deletes (soft-deletes) an entry (FR-W-09).
  Future<Result<void>> deleteEntry(String id);

  /// Records a new goal, effective from [effectiveFrom] (append-only,
  /// FR-W-04).
  Future<Result<void>> setGoal(int goalMl, {required DateTime effectiveFrom});

  /// Streams the module's own settings, seeding defaults on first read.
  Stream<WaterSettings> watchSettings();

  /// Updates the quick-add preset amounts.
  Future<Result<void>> updateQuickAddAmounts(List<int> amountsMl);

  /// Updates reminder preferences (data only — no OS scheduling yet).
  Future<Result<void>> updateReminderSettings({
    required bool enabled,
    required int intervalMinutes,
    required LocalTime windowStart,
    required LocalTime windowEnd,
  });

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
