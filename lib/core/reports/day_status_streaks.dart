import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// The longest run of consecutive `complete` days in [dayStatus], sorted
/// by date — the shared building block behind every module's
/// longest-streak record in Reports (D-17).
int longestStreak(Map<LocalDate, ModuleDayStatus> dayStatus) {
  final days = dayStatus.keys.toList()..sort();
  var longest = 0;
  var running = 0;
  for (final day in days) {
    if (dayStatus[day]!.kind == ModuleDayStatusKind.complete) {
      running += 1;
      longest = running > longest ? running : longest;
    } else {
      running = 0;
    }
  }
  return longest;
}

/// The run of consecutive `complete` days ending at (and including)
/// [today] in [dayStatus] — used by achievement definitions that need
/// "how close am I right now," not the all-time record.
int currentStreak(Map<LocalDate, ModuleDayStatus> dayStatus, LocalDate today) {
  var running = 0;
  var day = today;
  while (dayStatus[day]?.kind == ModuleDayStatusKind.complete) {
    running += 1;
    day = day.addDays(-1);
  }
  return running;
}
