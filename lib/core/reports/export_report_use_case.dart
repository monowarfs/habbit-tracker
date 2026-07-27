import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/reports/csv_report_generator.dart';
import 'package:habit_tracker/core/reports/pdf_report_generator.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:path/path.dart' as p;

/// Orchestrates a PDF/CSV report export: aggregates the requested
/// [ReportPeriod] via the existing `AggregateReportUseCase`/`dayStatus()`
/// pipeline, hands the result to the matching generator, and writes it
/// to a temp file for the caller to share
/// (`docs/superpowers/specs/04-premium/05-exportable-pdf-csv-reports-
/// IMPLEMENTATION-PLAN.md`).
class ExportReportUseCase {
  /// Creates the use case.
  const ExportReportUseCase({
    AggregateReportUseCase aggregateReportUseCase =
        const AggregateReportUseCase(),
    PdfReportGenerator pdfReportGenerator = const PdfReportGenerator(),
    CsvReportGenerator csvReportGenerator = const CsvReportGenerator(),
  }) : _aggregate = aggregateReportUseCase,
       _pdf = pdfReportGenerator,
       _csv = csvReportGenerator;

  final AggregateReportUseCase _aggregate;
  final PdfReportGenerator _pdf;
  final CsvReportGenerator _csv;

  /// Builds and saves a PDF export, returning the written file's path.
  /// [chartImages] (`ModuleReport.moduleId` -> PNG bytes) and [logoBytes]
  /// are optional — the caller resolves those (they need a widget tree/
  /// asset bundle respectively) and passes them in already decoded.
  Future<Result<String>> exportPdf({
    required List<HabitModule> modules,
    required ReportPeriod period,
    required LocalDate anchor,
    required String periodLabel,
    String? profileName,
    Uint8List? logoBytes,
    Map<String, Uint8List>? chartImages,
    DateRange? customRange,
  }) async {
    try {
      final reports = await _aggregate.execute(
        modules: modules,
        period: period,
        periodAnchor: anchor,
        customRange: customRange,
      );
      final range = _aggregate.rangeForPeriod(
        period,
        anchor,
        customRange: customRange,
      );
      final bytes = await _pdf.generate(
        reports: reports,
        range: range,
        periodLabel: periodLabel,
        generatedAt: clock.now(),
        profileName: profileName,
        logoBytes: logoBytes,
        chartImages: chartImages,
      );
      final file = File(
        p.join(
          Directory.systemTemp.path,
          'habit_tracker_report_${clock.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(bytes);
      return Result.success(file.path);
    } on Object catch (e) {
      return Result.failure(AppException.storage('export_pdf', e));
    }
  }

  /// Builds and saves a CSV export, returning the written file's path.
  Future<Result<String>> exportCsv({
    required List<HabitModule> modules,
    required ReportPeriod period,
    required LocalDate anchor,
    DateRange? customRange,
  }) async {
    try {
      final range = _aggregate.rangeForPeriod(
        period,
        anchor,
        customRange: customRange,
      );
      final csv = await _csv.generate(modules: modules, range: range);
      final file = File(
        p.join(
          Directory.systemTemp.path,
          'habit_tracker_report_${clock.now().millisecondsSinceEpoch}.csv',
        ),
      );
      await file.writeAsString(csv);
      return Result.success(file.path);
    } on Object catch (e) {
      return Result.failure(AppException.storage('export_csv', e));
    }
  }
}
