import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/domain/usecases/aggregate_water_series.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'water_providers.g.dart';

/// A day's logged total against its applicable goal, plus the raw entries
/// that make it up (used by the home screen's progress ring/log list).
typedef WaterDayProgress = ({
  int totalMl,
  int goalMl,
  List<WaterEntry> entries,
});

/// An inclusive local-day range, used as a family provider parameter.
typedef WaterDateRange = ({LocalDate start, LocalDate end});

/// The Water module's [WaterRepository].
@Riverpod(keepAlive: true)
WaterRepository waterRepository(Ref ref) {
  return WaterRepositoryImpl(ref.watch(databaseProvider));
}

/// Today's local calendar day. Not reactive to the clock ticking past
/// midnight mid-session — acceptable for v1 (the same limitation any
/// "today" concept has without a dedicated midnight-rollover timer).
LocalDate _today() => localDayKey(clock.now());

/// Every (non-deleted) entry logged on [day].
@riverpod
Stream<List<WaterEntry>> waterEntriesForDay(Ref ref, LocalDate day) {
  return ref.watch(waterRepositoryProvider).watchEntriesForDay(day);
}

/// A single entry by id, for the edit-entry screen.
@riverpod
Future<WaterEntry?> waterEntryById(Ref ref, String id) {
  return ref.watch(waterRepositoryProvider).entryById(id);
}

/// Every (non-deleted) entry logged within [range], inclusive.
@riverpod
Stream<List<WaterEntry>> waterEntriesInRange(Ref ref, WaterDateRange range) {
  return ref
      .watch(waterRepositoryProvider)
      .watchEntriesInRange(range.start, range.end);
}

/// The current (latest) goal.
@riverpod
Stream<WaterGoal> currentWaterGoal(Ref ref) {
  return ref.watch(waterRepositoryProvider).watchCurrentGoal();
}

/// The full goal history, oldest first.
@riverpod
Future<List<WaterGoal>> allWaterGoals(Ref ref) {
  return ref.watch(waterRepositoryProvider).allGoals();
}

/// The module's own settings (quick-add presets, reminder prefs).
@riverpod
Stream<WaterSettings> waterSettings(Ref ref) {
  return ref.watch(waterRepositoryProvider).watchSettings();
}

/// Today's total vs. goal, or `null` while the underlying streams are
/// still loading their first value.
@riverpod
WaterDayProgress? todaysWaterProgress(Ref ref) {
  final today = _today();
  final entries = ref.watch(waterEntriesForDayProvider(today)).value;
  final goal = ref.watch(currentWaterGoalProvider).value;
  if (entries == null || goal == null) return null;
  final total = entries.fold(0, (sum, e) => sum + e.amountMl);
  return (totalMl: total, goalMl: goal.goalMl, entries: entries);
}

Map<LocalDate, int> _dailyTotals(List<WaterEntry> entries) {
  final totals = <LocalDate, int>{};
  for (final entry in entries) {
    final day = localDayKey(entry.loggedAt);
    totals[day] = (totals[day] ?? 0) + entry.amountMl;
  }
  return totals;
}

/// Current/longest streak (FR-W-07/08), or `null` while loading.
@riverpod
WaterStreakResult? waterStreak(Ref ref) {
  final goals = ref.watch(allWaterGoalsProvider).value;
  if (goals == null || goals.isEmpty) return null;
  final today = _today();
  final earliest = goals
      .map((g) => localDayKey(g.effectiveFrom))
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final entries = ref
      .watch(waterEntriesInRangeProvider((start: earliest, end: today)))
      .value;
  if (entries == null) return null;
  return const CalculateWaterStreakUseCase().execute(
    dailyTotalsMl: _dailyTotals(entries),
    goals: goals,
    earliestDay: earliest,
    today: today,
  );
}

/// Aggregated series for the stats charts (FR-W-08), or `null` while
/// loading.
@riverpod
List<WaterSeriesPoint>? waterSeries(
  Ref ref, {
  required LocalDate start,
  required LocalDate end,
  required WaterAggregationPeriod period,
}) {
  final entries = ref
      .watch(waterEntriesInRangeProvider((start: start, end: end)))
      .value;
  if (entries == null) return null;
  return AggregateWaterSeriesUseCase().execute(
    dailyTotalsMl: _dailyTotals(entries),
    start: start,
    end: end,
    period: period,
  );
}
