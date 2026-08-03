import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/logged_day_status.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  test(
    'calculateLoggedDayStatus is complete only for days with a log',
    () {
      final status = calculateLoggedDayStatus<DateTime>(
        logs: [DateTime.utc(2026, 6, 15, 8)],
        range: const DateRange(
          start: LocalDate(2026, 6, 14),
          end: LocalDate(2026, 6, 15),
        ),
        dateOf: (d) => d,
      );

      expect(
        status[const LocalDate(2026, 6, 14)]!.kind,
        ModuleDayStatusKind.none,
      );
      expect(
        status[const LocalDate(2026, 6, 15)]!.kind,
        ModuleDayStatusKind.complete,
      );
    },
  );

  test('currentLoggedStreak counts consecutive days ending today', () async {
    final logs = [
      DateTime.utc(2026, 6, 13, 8),
      DateTime.utc(2026, 6, 14, 8),
      DateTime.utc(2026, 6, 15, 8),
    ];
    final streak = await currentLoggedStreak<DateTime>(
      allLogs: () async => logs,
      dateOf: (d) => d,
      today: const LocalDate(2026, 6, 15),
    );
    expect(streak, 3);
  });

  test('currentLoggedStreak is 0 with no logs', () async {
    final streak = await currentLoggedStreak<DateTime>(
      allLogs: () async => [],
      dateOf: (d) => d,
      today: const LocalDate(2026, 6, 15),
    );
    expect(streak, 0);
  });
}
