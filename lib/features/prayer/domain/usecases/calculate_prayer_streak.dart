import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

part 'calculate_prayer_streak.freezed.dart';

/// Current and longest prayer streaks (FR-P-09/10).
@freezed
sealed class PrayerStreakResult with _$PrayerStreakResult {
  /// Creates a streak result.
  const factory PrayerStreakResult({
    required int current,
    required int longest,
  }) = _PrayerStreakResult;
}

/// Streak = consecutive calendar days where every required prayer is
/// `prayed` before its cutoff (FR-P-09). The required count is always 5
/// — Jumu'ah relabels an existing required prayer (Dhuhr) on Fridays, it
/// never adds a sixth (this plan's refinements section, #1), so unlike
/// `CalculateWaterStreakUseCase` this use case needs no goal/settings
/// input at all, just the records themselves.
class CalculatePrayerStreakUseCase {
  /// Creates the use case.
  const CalculatePrayerStreakUseCase();

  /// Computes the current streak (consecutive days ending at [today]) and
  /// the longest streak found between [earliestDay] and [today]
  /// inclusive. [recordsByDay] maps a day to that day's records; a day
  /// with fewer than 5 records (not yet materialized) or any record still
  /// `upcoming` (not yet resolved, including "today" still in progress)
  /// is skipped — it neither counts nor breaks the running streak, since
  /// it hasn't failed yet. A day with 5 resolved records where at least
  /// one is `missed` breaks the streak.
  PrayerStreakResult execute({
    required Map<LocalDate, List<PrayerRecord>> recordsByDay,
    required LocalDate earliestDay,
    required LocalDate today,
  }) {
    if (earliestDay.compareTo(today) > 0) {
      return const PrayerStreakResult(current: 0, longest: 0);
    }

    var longest = 0;
    var running = 0;
    var current = 0;

    var day = earliestDay;
    while (day.compareTo(today) <= 0) {
      final records = recordsByDay[day] ?? const [];
      if (records.length < 5 ||
          records.any((r) => r.storedStatus == PrayerStatus.upcoming)) {
        day = day.addDays(1);
        continue;
      }
      final allPrayed = records.every(
        (r) => r.storedStatus == PrayerStatus.prayed,
      );
      if (allPrayed) {
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

    return PrayerStreakResult(current: current, longest: longest);
  }
}
