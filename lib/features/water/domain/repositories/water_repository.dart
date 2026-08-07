import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';

/// Default for [WaterRepository.updateEntry]'s `notes` param, distinguishing
/// "leave untouched" (the caller omitted the argument) from "clear"
/// (the caller explicitly passed `null`) — a plain `String?` default can't
/// tell those two apart since both read as `null`.
const Object unsetWaterNotes = Object();

/// Reads and mutates the Water module's data.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md` Task 4) — callers pass whatever
/// `activeProfileProvider` currently resolves to.
abstract class WaterRepository {
  /// Streams every (non-deleted) entry logged on [day].
  Stream<List<WaterEntry>> watchEntriesForDay(
    LocalDate day, {
    required String profileId,
  });

  /// Streams every (non-deleted) entry with `loggedAt` between [start] and
  /// [end] (inclusive), for stats/history/streak use cases.
  Stream<List<WaterEntry>> watchEntriesInRange(
    LocalDate start,
    LocalDate end, {
    required String profileId,
  });

  /// Looks up a single entry by id (for the edit-entry screen), or `null`
  /// if it doesn't exist / was deleted.
  Future<WaterEntry?> entryById(String id, {required String profileId});

  /// Streams the current (latest) goal.
  Stream<WaterGoal?> watchCurrentGoal({required String profileId});

  /// All goal-history rows, oldest first — the raw material
  /// `ResolveGoalForDateUseCase`/`CalculateWaterStreakUseCase` resolve
  /// per-day goals from.
  Future<List<WaterGoal>> allGoals({required String profileId});

  /// Every (non-deleted) entry ever logged, oldest first — export
  /// groundwork (`strategies/backup-import-export.md`).
  Future<List<WaterEntry>> allEntries({required String profileId});

  /// Logs a new entry.
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
    required String profileId,
    String? notes,
  });

  /// Updates an existing entry's amount, timestamp, and/or notes
  /// (FR-W-09). Only non-null [amountMl]/[loggedAt] change; omitting
  /// [notes] entirely never clobbers an existing one, but passing
  /// `notes: null` explicitly clears it (see [unsetWaterNotes]).
  Future<Result<void>> updateEntry(
    String id, {
    required String profileId,
    int? amountMl,
    DateTime? loggedAt,
    Object? notes = unsetWaterNotes,
  });

  /// Deletes (soft-deletes) an entry (FR-W-09).
  Future<Result<void>> deleteEntry(String id, {required String profileId});

  /// Records a new goal, effective from [effectiveFrom] (append-only,
  /// FR-W-04).
  Future<Result<void>> setGoal(
    int goalMl, {
    required DateTime effectiveFrom,
    required String profileId,
  });

  /// Streams the module's own settings, seeding defaults on first read.
  Stream<WaterSettings> watchSettings({required String profileId});

  /// Updates the quick-add preset amounts.
  Future<Result<void>> updateQuickAddAmounts(
    List<int> amountsMl, {
    required String profileId,
  });

  /// Updates reminder preferences (data only — no OS scheduling yet).
  Future<Result<void>> updateReminderSettings({
    required bool enabled,
    required int intervalMinutes,
    required LocalTime windowStart,
    required LocalTime windowEnd,
    required Map<int, ({LocalTime start, LocalTime end})> windowOverrides,
    required String profileId,
  });

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll({required String profileId});

  /// Enables or disables the weather-derived reminder-copy clause. Default
  /// false — opt-in only, since enabling it implies location + network
  /// access.
  Future<Result<void>> updateWeatherNudgeEnabled({
    required bool enabled,
    required String profileId,
  });

  /// Caches the latest successful weather fetch. Called only by the
  /// WorkManager cache refresher, never from `pendingNotifications()`'s
  /// own hot path.
  Future<Result<void>> updateWeatherCache({
    required double temperatureCelsius,
    required DateTime fetchedAt,
    required String profileId,
  });

  /// Archives a water goal, hiding it from active views.
  Future<Result<void>> archiveGoal(String goalId, {required String profileId});

  /// Revives an archived water goal, making it active again.
  Future<Result<void>> reviveGoal(String goalId, {required String profileId});

  /// Returns all archived water goals.
  Future<List<WaterGoal>> archivedGoals({required String profileId});

  /// Whether the user has ever set any goal (active or archived).
  Future<bool> hasAnyGoals({required String profileId});
}
