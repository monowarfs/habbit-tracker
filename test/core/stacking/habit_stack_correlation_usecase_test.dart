import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  test(
    'finds a real pattern: 7/7 days qualify at a consistent 20-minute gap',
    () {
      final sourceByDay = <LocalDate, DateTime>{
        for (var i = 0; i < 7; i++)
          LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8, 15),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        for (var i = 0; i < 7; i++)
          LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 35)],
      };

      final result = findStackCorrelation(
        sourceByDay: sourceByDay,
        targetByDay: targetByDay,
      );

      expect(result, isNotNull);
      expect(result!.qualifyingDays, 7);
      expect(result.totalDaysWithSource, 7);
      expect(result.medianGapMinutes, 20);
      expect(result.typicalSourceTime, const LocalTime(8, 15));
    },
  );

  test(
    'below minQualifyingDays returns null even at a 100% qualifying rate',
    () {
      final sourceByDay = <LocalDate, DateTime>{
        const LocalDate(2026, 6, 1): DateTime(2026, 6, 1, 8, 15),
        const LocalDate(2026, 6, 2): DateTime(2026, 6, 2, 8, 15),
        const LocalDate(2026, 6, 3): DateTime(2026, 6, 3, 8, 15),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        const LocalDate(2026, 6, 1): [DateTime(2026, 6, 1, 8, 30)],
        const LocalDate(2026, 6, 2): [DateTime(2026, 6, 2, 8, 30)],
        const LocalDate(2026, 6, 3): [DateTime(2026, 6, 3, 8, 30)],
      };

      expect(
        findStackCorrelation(
          sourceByDay: sourceByDay,
          targetByDay: targetByDay,
        ),
        isNull,
      );
    },
  );

  test(
    'below the 70% qualifying-day rate returns null even with enough '
    'qualifying days',
    () {
      // 10 days with a source action, only 5 (50%) have a same-day water
      // log within the gap window — 5 clears minQualifyingDays but fails
      // the 70% rate check.
      final sourceByDay = <LocalDate, DateTime>{
        for (var i = 0; i < 10; i++)
          LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        for (var i = 0; i < 5; i++)
          LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 30)],
      };

      expect(
        findStackCorrelation(
          sourceByDay: sourceByDay,
          targetByDay: targetByDay,
        ),
        isNull,
      );
    },
  );

  test('a target logged before the source action never qualifies that day', () {
    final sourceByDay = <LocalDate, DateTime>{
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8, 15),
    };
    final targetByDay = <LocalDate, List<DateTime>>{
      // Every water log is 10 minutes BEFORE the source action.
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 5)],
    };

    expect(
      findStackCorrelation(sourceByDay: sourceByDay, targetByDay: targetByDay),
      isNull,
    );
  });

  test('a gap beyond maxGap never qualifies that day', () {
    final sourceByDay = <LocalDate, DateTime>{
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8),
    };
    final targetByDay = <LocalDate, List<DateTime>>{
      // 2 hours after the source action -> beyond the default 90-minute cap.
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 10)],
    };

    expect(
      findStackCorrelation(sourceByDay: sourceByDay, targetByDay: targetByDay),
      isNull,
    );
  });

  test(
    'only the trailing windowDays days count — older source days outside '
    'the window are excluded from totalDaysWithSource',
    () {
      // 20 days of source data; only the trailing 14 (relative to the
      // latest day present) should be considered.
      const baseDay = LocalDate(2026, 5, 20);
      final days = [for (var i = 0; i < 20; i++) baseDay.addDays(i)];
      final sourceByDay = {
        for (final day in days) day: DateTime(day.year, day.month, day.day, 8),
      };
      final targetByDay = {
        for (final day in days)
          day: [DateTime(day.year, day.month, day.day, 8, 30)],
      };

      final result = findStackCorrelation(
        sourceByDay: sourceByDay,
        targetByDay: targetByDay,
      );

      expect(result, isNotNull);
      expect(result!.totalDaysWithSource, 14);
      expect(result.qualifyingDays, 14);
    },
  );
}
