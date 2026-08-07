import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';

/// Builds a day-status map over [range] from [logs] — `complete` for any
/// day with a logged reading, `none` otherwise. Shared by
/// `BloodPressureModule.dayStatus()` and the stats screen's streak
/// provider so there's exactly one place that defines "a day counts"
/// (same shape as Sleep's `calculateSleepDayStatus` — no goal concept
/// here either).
Map<LocalDate, ModuleDayStatus> calculateBpDayStatus({
  required List<BpLog> logs,
  required DateRange range,
}) {
  final loggedDays = logs.map((l) => localDayKey(l.loggedAt)).toSet();
  final result = <LocalDate, ModuleDayStatus>{};
  var day = range.start;
  while (day.compareTo(range.end) <= 0) {
    result[day] = ModuleDayStatus(
      kind: loggedDays.contains(day)
          ? ModuleDayStatusKind.complete
          : ModuleDayStatusKind.none,
      value: 0,
    );
    day = day.addDays(1);
  }
  return result;
}

/// The current consecutive-days-logged streak, ending at [today].
Future<int> currentBpStreak(
  BpRepository repository,
  LocalDate today, {
  required String profileId,
}) async {
  final logs = await repository.allLogs(profileId: profileId);
  if (logs.isEmpty) return 0;
  final earliest = logs
      .map((l) => localDayKey(l.loggedAt))
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final status = calculateBpDayStatus(
    logs: logs,
    range: DateRange(start: earliest, end: today),
  );
  return currentStreak(status, today);
}
