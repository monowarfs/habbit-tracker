import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('mondayOfWeek', () {
    test('a Wednesday snaps back to its Monday', () {
      // 2026-08-05 is a Wednesday.
      expect(
        mondayOfWeek(const LocalDate(2026, 8, 5)),
        const LocalDate(2026, 8, 3),
      );
    });

    test('a Monday stays the same day', () {
      expect(
        mondayOfWeek(const LocalDate(2026, 8, 3)),
        const LocalDate(2026, 8, 3),
      );
    });

    test('a Sunday snaps back to the Monday that started its week', () {
      expect(
        mondayOfWeek(const LocalDate(2026, 8, 9)),
        const LocalDate(2026, 8, 3),
      );
    });
  });

  group('weekKeyForDate', () {
    test('mid-year date produces the expected ISO week', () {
      // 2026-08-05 falls in ISO week 32 of 2026 (verified against a
      // reference ISO 8601 week calendar).
      expect(weekKeyForDate(const LocalDate(2026, 8, 5)), '2026-W32');
    });

    test('every day of the same week shares one week key', () {
      final monday = weekKeyForDate(const LocalDate(2026, 8, 3));
      final sunday = weekKeyForDate(const LocalDate(2026, 8, 9));
      expect(monday, sunday);
    });

    test(
      "a Jan date near year boundary uses its week's Thursday's ISO year",
      () {
        // 2027-01-01 is a Friday; its week's Thursday (2026-12-31) is in
        // 2026, so this date belongs to ISO year 2026's last week, not 2027.
        expect(weekKeyForDate(const LocalDate(2027, 1, 1)), '2026-W53');
      },
    );

    test('the first Monday of an ISO year is week 01', () {
      // 2027-01-04 is a Monday, and Jan 4th always falls in week 1.
      expect(weekKeyForDate(const LocalDate(2027, 1, 4)), '2027-W01');
    });
  });

  group('isInWeek', () {
    test('a date within the week key matches', () {
      expect(isInWeek(const LocalDate(2026, 8, 6), '2026-W32'), isTrue);
    });

    test('a date outside the week key does not match', () {
      expect(isInWeek(const LocalDate(2026, 8, 10), '2026-W32'), isFalse);
    });
  });
}
