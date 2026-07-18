import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'repeat_rule.freezed.dart';

/// A medicine schedule's recurrence pattern (FR-M-03, D-03). Exactly the
/// four patterns the committed schema's `frequency_type` enum supports —
/// monthly/specific-dates patterns are out of scope this run (no schema
/// storage, no decision doc covering their edge cases).
@freezed
sealed class RepeatRule with _$RepeatRule {
  /// Fixed times every day.
  const factory RepeatRule.fixedDaily({required List<LocalTime> timesOfDay}) =
      FixedDailyRule;

  /// Every [intervalDays] days, anchored to the schedule's `startDate`
  /// (D-03) — `intervalDays: 2` is "every other day."
  const factory RepeatRule.everyNDays({
    required int intervalDays,
    required List<LocalTime> timesOfDay,
  }) = EveryNDaysRule;

  /// Specific weekdays, e.g. Mon/Wed/Fri.
  const factory RepeatRule.weekdaySet({
    required int weekdaysMask,
    required List<LocalTime> timesOfDay,
  }) = WeekdaySetRule;

  /// As-needed — no scheduled instances (FR-M-03).
  const factory RepeatRule.prn() = PrnRule;
}
