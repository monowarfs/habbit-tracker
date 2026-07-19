import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

ModuleDayStatus _s(ModuleDayStatusKind kind) =>
    ModuleDayStatus(kind: kind, value: 0);

void main() {
  group('longestStreak', () {
    test('finds the longest run of complete days, ignoring gaps', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.missed),
        const LocalDate(2026, 6, 4): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 5): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 6): _s(ModuleDayStatusKind.complete),
      };
      expect(longestStreak(map), 3);
    });

    test('empty map has zero longest streak', () {
      expect(longestStreak(const {}), 0);
    });
  });

  group('currentStreak', () {
    test('counts consecutive complete days ending at today', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.missed),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.complete),
      };
      expect(currentStreak(map, const LocalDate(2026, 6, 3)), 2);
    });

    test('a missed today breaks the current streak to zero', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.missed),
      };
      expect(currentStreak(map, const LocalDate(2026, 6, 2)), 0);
    });
  });
}
