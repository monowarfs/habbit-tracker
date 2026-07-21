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
}
