import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('LocalDate.addMonths', () {
    test('rolls back across a year boundary from January', () {
      // Regression test: a bare `LocalDate(year, month - 1, 1)` at a
      // call site produces an invalid `month: 0` when stepping back
      // from January, silently breaking every later day-key lookup
      // (caught in PR review on the per-habit heatmap calendar).
      expect(
        const LocalDate(2026, 1, 1).addMonths(-1),
        const LocalDate(2025, 12, 1),
      );
    });

    test('rolls forward across a year boundary from December', () {
      expect(
        const LocalDate(2025, 12, 1).addMonths(1),
        const LocalDate(2026, 1, 1),
      );
    });

    test('a plain mid-year shift stays within the same year', () {
      expect(
        const LocalDate(2026, 6, 15).addMonths(1),
        const LocalDate(2026, 7, 15),
      );
      expect(
        const LocalDate(2026, 6, 15).addMonths(-1),
        const LocalDate(2026, 5, 15),
      );
    });
  });

  group('weekStartFor', () {
    test('a Monday snaps to itself', () {
      // 2026-08-03 is a Monday.
      expect(
        weekStartFor(const LocalDate(2026, 8, 3)),
        const LocalDate(2026, 8, 3),
      );
    });

    test("a mid-week day snaps back to that week's Monday", () {
      // 2026-06-09 is a Tuesday, in the week starting 2026-06-08.
      expect(
        weekStartFor(const LocalDate(2026, 6, 9)),
        const LocalDate(2026, 6, 8),
      );
    });

    test("a Sunday snaps back to the same week's Monday", () {
      // 2026-08-09 is a Sunday, in the week starting 2026-08-03.
      expect(
        weekStartFor(const LocalDate(2026, 8, 9)),
        const LocalDate(2026, 8, 3),
      );
    });
  });
}
