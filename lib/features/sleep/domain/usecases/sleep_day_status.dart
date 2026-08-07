import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';

/// Builds a day-status map over [range] from [logs] — `complete` for any
/// day with a logged wake time, `none` otherwise. Shared by
/// `SleepModule.dayStatus()` and the stats screen's streak provider so
/// there's exactly one place that defines "a night counts."
Map<LocalDate, ModuleDayStatus> calculateSleepDayStatus({
  required List<SleepLog> logs,
  required DateRange range,
}) {
  final loggedDays = logs.map((l) => localDayKey(l.wakeTime)).toSet();
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

/// The current consecutive-nights-logged streak, ending at [today].
Future<int> currentSleepStreak(
  SleepRepository repository,
  LocalDate today, {
  required String profileId,
}) async {
  final logs = await repository.allLogs(profileId: profileId);
  if (logs.isEmpty) return 0;
  final earliest = logs
      .map((l) => localDayKey(l.wakeTime))
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final status = calculateSleepDayStatus(
    logs: logs,
    range: DateRange(start: earliest, end: today),
  );
  return currentStreak(status, today);
}
