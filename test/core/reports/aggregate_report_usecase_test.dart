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
}
