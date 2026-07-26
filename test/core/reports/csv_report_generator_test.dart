import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/csv_report_generator.dart';
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
  test('writes one row per day with data, skipping "none" days', () async {
    final module = _FakeModule('water', {
      const LocalDate(2026, 6, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 2000,
      ),
      const LocalDate(2026, 6, 2): const ModuleDayStatus(
        kind: ModuleDayStatusKind.none,
        value: 0,
      ),
      const LocalDate(2026, 6, 3): const ModuleDayStatus(
        kind: ModuleDayStatusKind.missed,
        value: 0,
      ),
    });

    final csv = await const CsvReportGenerator().generate(
      modules: [module],
      range: const DateRange(
        start: LocalDate(2026, 6, 1),
        end: LocalDate(2026, 6, 3),
      ),
    );

    final lines = csv.trim().split('\n');
    expect(lines[0], 'Module,Date,Value,Status');
    expect(lines, hasLength(3));
    expect(lines[1], 'water,2026-06-01,2000,complete');
    expect(lines[2], 'water,2026-06-03,0,missed');
  });

  test('quotes a display name containing a comma', () async {
    final module = _FakeModule('Water, Daily', {
      const LocalDate(2026, 1, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      ),
    });

    final csv = await const CsvReportGenerator().generate(
      modules: [module],
      range: const DateRange(
        start: LocalDate(2026, 1, 1),
        end: LocalDate(2026, 1, 1),
      ),
    );

    expect(csv, contains('"Water, Daily",2026-01-01,1,complete'));
  });

  test('produces just the header for a module with no data', () async {
    final module = _FakeModule('water', {});

    final csv = await const CsvReportGenerator().generate(
      modules: [module],
      range: const DateRange(
        start: LocalDate(2026, 1, 1),
        end: LocalDate(2026, 1, 1),
      ),
    );

    expect(csv.trim(), 'Module,Date,Value,Status');
  });
}
