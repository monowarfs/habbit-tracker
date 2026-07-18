import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';

part 'calculate_water_streak.freezed.dart';

/// Current and longest water streaks (FR-W-07/08).
@freezed
sealed class WaterStreakResult with _$WaterStreakResult {
  /// Creates a streak result.
  const factory WaterStreakResult({
    required int current,
    required int longest,
  }) = _WaterStreakResult;
}

/// Streak = consecutive calendar days (local timezone) where total logged
/// >= that day's goal (FR-W-07). A day with zero/insufficient entries
/// breaks the streak at day rollover — this walks forward from stored
/// daily totals, it never rewrites history.
class CalculateWaterStreakUseCase {
  /// Creates the use case.
  const CalculateWaterStreakUseCase({
    this.resolveGoalForDate = const ResolveGoalForDateUseCase(),
  });

  /// Injected so a fake/alternate resolution strategy can be swapped in
  /// tests without touching this class.
  final ResolveGoalForDateUseCase resolveGoalForDate;

  /// Computes the current streak (consecutive days ending at [today]) and
  /// the longest streak found between [earliestDay] and [today] inclusive.
  ///
  /// [dailyTotalsMl] maps a day to its logged total; a day absent from the
  /// map is treated as 0 (no entries that day).
  WaterStreakResult execute({
    required Map<LocalDate, int> dailyTotalsMl,
    required List<WaterGoal> goals,
    required LocalDate earliestDay,
    required LocalDate today,
  }) {
    if (earliestDay.compareTo(today) > 0) {
      return const WaterStreakResult(current: 0, longest: 0);
    }

    var longest = 0;
    var running = 0;
    var current = 0;

    var day = earliestDay;
    while (day.compareTo(today) <= 0) {
      final total = dailyTotalsMl[day] ?? 0;
      final goal = resolveGoalForDate.execute(goals, day);
      final metGoal = goal.goalMl > 0 && total >= goal.goalMl;

      if (metGoal) {
        running += 1;
        current = running;
      } else {
        longest = running > longest ? running : longest;
        running = 0;
        current = 0;
      }
      day = day.addDays(1);
    }
    longest = running > longest ? running : longest;

    return WaterStreakResult(current: current, longest: longest);
  }
}
