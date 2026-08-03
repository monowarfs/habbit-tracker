import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

/// Builds a day-status map over [range] from [logs] — `complete` for any
/// day with a logged entry, `none` otherwise.
///
/// For modules with no goal/threshold concept (a day either has an entry
/// or it doesn't) — Sleep and Blood Pressure each hand-rolled this exact
/// shape before this existed (`sleep_day_status.dart`/`bp_day_status.dart`,
/// left as-is rather than retrofitted, since they're already shipped and
/// working); this is the generic version for every module built after
/// the pattern showed up a 3rd time.
Map<LocalDate, ModuleDayStatus> calculateLoggedDayStatus<T>({
  required List<T> logs,
  required DateRange range,
  required DateTime Function(T log) dateOf,
}) {
  final loggedDays = logs.map((l) => localDayKey(dateOf(l))).toSet();
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

/// The current consecutive-days-logged streak, ending at [today], given
/// every non-deleted log ever recorded ([allLogs]) and how to read a
/// log's timestamp ([dateOf]).
Future<int> currentLoggedStreak<T>({
  required Future<List<T>> Function() allLogs,
  required DateTime Function(T log) dateOf,
  required LocalDate today,
}) async {
  final logs = await allLogs();
  if (logs.isEmpty) return 0;
  final earliest = logs
      .map((l) => localDayKey(dateOf(l)))
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final status = calculateLoggedDayStatus(
    logs: logs,
    range: DateRange(start: earliest, end: today),
    dateOf: dateOf,
  );
  return currentStreak(status, today);
}
