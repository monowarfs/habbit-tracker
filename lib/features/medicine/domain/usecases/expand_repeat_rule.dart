import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// Expands [rule] into concrete UTC dose instants across
/// `[rangeStart, rangeEnd]` (inclusive local calendar days). Pure — takes
/// [anchor] (the schedule's `startDate`) and the range as plain data, no
/// `clock.now()` — every caller (materialization, the 7-day schedule
/// preview) supplies its own range.
///
/// Times-of-day are resolved against the device's current ambient
/// timezone (D-14) — same approach as
/// `core/utils/local_day.dart`'s `localDayRangeUtc`.
List<DateTime> expandRepeatRule({
  required RepeatRule rule,
  required LocalDate anchor,
  required LocalDate rangeStart,
  required LocalDate rangeEnd,
}) {
  if (rangeEnd.compareTo(rangeStart) < 0) return [];
  final instants = <DateTime>[];
  var day = rangeStart;
  while (day.compareTo(rangeEnd) <= 0) {
    if (_ruleAppliesOnDay(rule, anchor: anchor, day: day)) {
      for (final time in _timesOfDay(rule)) {
        instants.add(_resolveLocalInstant(day, time));
      }
    }
    day = day.addDays(1);
  }
  return instants;
}

List<LocalTime> _timesOfDay(RepeatRule rule) => switch (rule) {
  FixedDailyRule(:final timesOfDay) => timesOfDay,
  EveryNDaysRule(:final timesOfDay) => timesOfDay,
  WeekdaySetRule(:final timesOfDay) => timesOfDay,
  PrnRule() => const [],
};

bool _ruleAppliesOnDay(
  RepeatRule rule, {
  required LocalDate anchor,
  required LocalDate day,
}) {
  if (day.compareTo(anchor) < 0) return false;
  return switch (rule) {
    FixedDailyRule() => true,
    EveryNDaysRule(:final intervalDays) =>
      _daysBetween(anchor, day) % intervalDays == 0,
    WeekdaySetRule(:final weekdaysMask) => _matchesWeekday(day, weekdaysMask),
    PrnRule() => false,
  };
}

/// Pure calendar-day count between two [LocalDate]s — computed via each
/// date's own UTC-midnight representation, which carries no wall-clock/
/// timezone information (D-14), so this is DST-immune by construction:
/// there is no ambient timezone conversion anywhere in this calculation.
int _daysBetween(LocalDate from, LocalDate to) =>
    to.toDateTimeUtc().difference(from.toDateTimeUtc()).inDays;

bool _matchesWeekday(LocalDate day, int mask) {
  final weekday = day.toDateTimeUtc().weekday; // Monday=1..Sunday=7
  return (mask & (1 << (weekday - 1))) != 0;
}

DateTime _resolveLocalInstant(LocalDate day, LocalTime time) {
  final local = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  return local.toUtc();
}
