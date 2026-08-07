import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/reports/export_report_use_case.dart';
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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => _byDay;
}

void main() {
  final module = _FakeModule('water', {
    const LocalDate(2026, 6, 1): const ModuleDayStatus(
      kind: ModuleDayStatusKind.complete,
      value: 2000,
    ),
  });

  test('exportPdf writes a PDF file and returns its path', () async {
    final result = await const ExportReportUseCase().exportPdf(
      modules: [module],
      period: ReportPeriod.week,
      anchor: const LocalDate(2026, 6, 1),
      periodLabel: 'Week',
    );

    expect(result, isA<Success<String>>());
    final path = (result as Success<String>).value;
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(await file.readAsBytes(), isNotEmpty);
    addTearDown(file.delete);
  });

  test('exportCsv writes a CSV file and returns its path', () async {
    final result = await const ExportReportUseCase().exportCsv(
      modules: [module],
      period: ReportPeriod.week,
      anchor: const LocalDate(2026, 6, 1),
    );

    expect(result, isA<Success<String>>());
    final path = (result as Success<String>).value;
    final file = File(path);
    expect(file.existsSync(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('Module,Date,Value,Status'));
    expect(content, contains('water,2026-06-01,2000,complete'));
    addTearDown(file.delete);
  });
}
