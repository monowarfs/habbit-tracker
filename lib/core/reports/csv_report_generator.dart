import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';

/// Builds a CSV export of every module's raw day-by-day status over a
/// date range — `Module,Date,Value,Status` rows, one per day that has
/// data (`docs/superpowers/specs/04-premium/05-exportable-pdf-csv-
/// reports-IMPLEMENTATION-PLAN.md`). Deliberately reads each module's
/// own `dayStatus()` rather than `AggregateReportUseCase`'s bucketed
/// `ModuleReport.points` — a CSV is for raw per-day analysis, the chart
/// bucketing (monthly/quarterly bars) that `ModuleReport` produces would
/// throw away exactly the daily granularity a spreadsheet export needs.
class CsvReportGenerator {
  /// Creates the generator.
  const CsvReportGenerator();

  /// Builds the CSV text for [modules] over [range].
  Future<String> generate({
    required List<HabitModule> modules,
    required DateRange range,
  }) async {
    final buffer = StringBuffer('Module,Date,Value,Status\n');
    for (final module in modules) {
      final dayStatus = await module.dayStatus(range);
      var day = range.start;
      while (day.compareTo(range.end) <= 0) {
        final status = dayStatus[day];
        if (status != null && status.kind != ModuleDayStatusKind.none) {
          buffer.writeln(
            '${_csvField(module.metadata.displayName)},'
            '${day.toIso()},'
            '${status.value},'
            '${status.kind.name}',
          );
        }
        day = day.addDays(1);
      }
    }
    return buffer.toString();
  }

  /// Quotes a field if it contains a comma, quote, or newline — the
  /// only values in this CSV that come from free-form user data (a
  /// module's display name is fixed per build, but this keeps the
  /// generator correct if that ever changes).
  String _csvField(String value) {
    if (!value.contains(RegExp('[",\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
