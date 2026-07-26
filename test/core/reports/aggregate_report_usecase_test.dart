import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this._byDay);
  @override
  final String id;
  final Map<LocalDate, ModuleDayStatus> _byDay;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id,
    icon: Icons.circle,
    accentColor: Colors.blue,
  );

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async =>
      _byDay;
}

void main() {
  test(
    'a module with only "none" days is excluded (empty-state case)',
    () async {
      final module = _FakeModule('water', {
        const LocalDate(2026, 6, 1): const ModuleDayStatus(
          kind: ModuleDayStatusKind.none,
          value: 0,
        ),
      });
      final reports = await const AggregateReportUseCase().execute(
        modules: [module],
        period: ReportPeriod.week,
        periodAnchor: const LocalDate(2026, 6, 1),
      );
      expect(reports, isEmpty);
    },
  );

  test(
    'week period buckets one bar per day and computes the longest streak',
    () async {
      final module = _FakeModule('water', {
        for (var d = 1; d <= 7; d++)
          LocalDate(2026, 6, d): ModuleDayStatus(
            kind: d <= 3
                ? ModuleDayStatusKind.complete
                : ModuleDayStatusKind.missed,
            value: d * 100,
          ),
      });
      final reports = await const AggregateReportUseCase().execute(
        modules: [module],
        period: ReportPeriod.week,
        periodAnchor: const LocalDate(2026, 6, 3),
      );
      expect(reports, hasLength(1));
      expect(reports.first.longestStreak, 3);
      expect(reports.first.points, isNotEmpty);
    },
  );

  test('year period buckets one bar per month', () async {
    final module = _FakeModule('water', {
      const LocalDate(2026, 1, 15): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 500,
      ),
      const LocalDate(2026, 2, 15): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 700,
      ),
    });
    final reports = await const AggregateReportUseCase().execute(
      modules: [module],
      period: ReportPeriod.year,
      periodAnchor: const LocalDate(2026, 3, 1),
    );
    expect(reports.first.points, hasLength(12));
  });

  test('custom period throws without a customRange', () async {
    final module = _FakeModule('water', {
      const LocalDate(2026, 1, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      ),
    });
    expect(
      () => const AggregateReportUseCase().execute(
        modules: [module],
        period: ReportPeriod.custom,
        periodAnchor: const LocalDate(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });

  test(
    'a custom range under a year buckets one bar per month',
    () async {
      final module = _FakeModule('water', {
        const LocalDate(2025, 6, 15): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 100,
        ),
        const LocalDate(2025, 8, 15): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 200,
        ),
      });
      final reports = await const AggregateReportUseCase().execute(
        modules: [module],
        period: ReportPeriod.custom,
        periodAnchor: const LocalDate(2025, 6, 1),
        customRange: const DateRange(
          start: LocalDate(2025, 6, 1),
          end: LocalDate(2025, 8, 31),
        ),
      );
      // June, July, August.
      expect(reports.first.points, hasLength(3));
      expect(reports.first.points[0].value, 100);
      expect(reports.first.points[2].value, 200);
    },
  );

  test(
    'a 2-5 year custom range buckets one bar per quarter',
    () async {
      final module = _FakeModule('water', {
        const LocalDate(2023, 1, 15): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 10,
        ),
        const LocalDate(2024, 12, 15): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 20,
        ),
      });
      final reports = await const AggregateReportUseCase().execute(
        modules: [module],
        period: ReportPeriod.allTime,
        periodAnchor: const LocalDate(2023, 1, 1),
        customRange: const DateRange(
          start: LocalDate(2023, 1, 1),
          end: LocalDate(2024, 12, 31),
        ),
      );
      // 2 years * 4 quarters.
      expect(reports.first.points, hasLength(8));
      expect(reports.first.points.first.value, 10);
      expect(reports.first.points.last.value, 20);
    },
  );

  test('a range beyond 5 years buckets one bar per year', () async {
    final module = _FakeModule('water', {
      const LocalDate(2018, 1, 15): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 5,
      ),
      const LocalDate(2026, 1, 15): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 9,
      ),
    });
    final reports = await const AggregateReportUseCase().execute(
      modules: [module],
      period: ReportPeriod.allTime,
      periodAnchor: const LocalDate(2018, 1, 1),
      customRange: const DateRange(
        start: LocalDate(2018, 1, 1),
        end: LocalDate(2026, 12, 31),
      ),
    );
    expect(reports.first.points, hasLength(9));
    expect(reports.first.points.first.value, 5);
    expect(reports.first.points.last.value, 9);
  });
}
