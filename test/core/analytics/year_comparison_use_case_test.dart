import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/year_comparison_use_case.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this._dayStatusFor);

  final Map<LocalDate, ModuleDayStatus> Function(DateRange range) _dayStatusFor;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => _dayStatusFor(range);
}

Map<LocalDate, ModuleDayStatus> _everyDay(DateRange range, num value) {
  final map = <LocalDate, ModuleDayStatus>{};
  var day = range.start;
  while (day.compareTo(range.end) <= 0) {
    map[day] = ModuleDayStatus(
      kind: ModuleDayStatusKind.complete,
      value: value,
    );
    day = day.addDays(1);
  }
  return map;
}

void main() {
  const useCase = YearComparisonUseCase();

  group('fetch', () {
    test('fetches a week period aligned index-for-index', () async {
      final module = _FakeModule((range) => _everyDay(range, 1));
      final result = await useCase.fetch(
        module: module,
        periodAnchor: const LocalDate(2026, 6, 15),
        period: ReportPeriod.week,
      );

      expect(result.currentPoints.length, 7);
      expect(result.lastYearPoints.length, 7);
      // A year prior, computed via the same rangeForPeriod resolution
      // rather than a raw day-count shift.
      expect(
        result.lastYearRange.start.year,
        result.currentRange.start.year - 1,
      );
    });

    test(
      'clips both series to the shorter length on a leap-year mismatch',
      () async {
        final module = _FakeModule((range) => _everyDay(range, 1));
        // Feb 2024 is a leap year (29 days); Feb 2023 is not (28 days).
        final result = await useCase.fetch(
          module: module,
          periodAnchor: const LocalDate(2024, 2, 15),
          period: ReportPeriod.month,
        );

        expect(result.currentRange.end.day, 29);
        expect(result.lastYearRange.end.day, 28);
        expect(result.currentPoints.length, 28);
        expect(result.lastYearPoints.length, 28);
      },
    );

    test(
      'anchoring on the leap day itself does not crash - Feb 29 has no '
      'literal same-day-last-year (a raw LocalDate(year-1, 2, 29) would '
      'be an invalid calendar date)',
      () async {
        final module = _FakeModule((range) => _everyDay(range, 1));
        final result = await useCase.fetch(
          module: module,
          periodAnchor: const LocalDate(2024, 2, 29),
          period: ReportPeriod.week,
        );

        // Both weeks still resolve to exactly 7 days - the invalid
        // Feb 29 2023 anchor normalizes (via DateTime.utc's own
        // overflow rounding, same mechanism LocalDate.addMonths relies
        // on) rather than throwing.
        expect(result.currentPoints.length, 7);
        expect(result.lastYearPoints.length, 7);
      },
    );

    test('a year period has no length mismatch to clip', () async {
      final module = _FakeModule((range) => _everyDay(range, 1));
      final result = await useCase.fetch(
        module: module,
        periodAnchor: const LocalDate(2024, 6, 1),
        period: ReportPeriod.year,
      );

      expect(result.currentPoints.length, 12);
      expect(result.lastYearPoints.length, 12);
    });

    test(
      'partial overlap: days missing from dayStatus bucket as zero rather '
      'than shrinking the series',
      () async {
        final module = _FakeModule((range) {
          // Only the first day of the range has data - simulates a user
          // whose history for that period is sparse/partial.
          return {
            range.start: const ModuleDayStatus(
              kind: ModuleDayStatusKind.complete,
              value: 5,
            ),
          };
        });
        final result = await useCase.fetch(
          module: module,
          periodAnchor: const LocalDate(2026, 6, 15),
          period: ReportPeriod.week,
        );

        expect(result.currentPoints.length, 7);
        expect(result.currentPoints.first.value, 5);
        expect(result.currentPoints.skip(1).every((p) => p.value == 0), isTrue);
      },
    );
  });

  group('isEligible', () {
    test('false when there is no recorded install date', () {
      expect(
        YearComparisonUseCase.isEligible(
          installDate: null,
          now: DateTime.utc(2026),
        ),
        isFalse,
      );
    });

    test('false when fewer than 365 days have passed', () {
      expect(
        YearComparisonUseCase.isEligible(
          installDate: DateTime.utc(2025),
          now: DateTime.utc(2025, 12, 31),
        ),
        isFalse,
      );
    });

    test('true at exactly 365 days', () {
      expect(
        YearComparisonUseCase.isEligible(
          installDate: DateTime.utc(2025),
          now: DateTime.utc(2026),
        ),
        isTrue,
      );
    });
  });
}
