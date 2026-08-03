import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reports_providers.g.dart';

/// The requested period + anchor day, used as a family provider parameter.
/// `customRange` is only read for `ReportPeriod.custom`/
/// `ReportPeriod.allTime`.
typedef ReportRequest = ({
  ReportPeriod period,
  LocalDate anchor,
  DateRange? customRange,
});

/// Every enabled module's [ModuleReport] for [request].
@riverpod
Future<List<ModuleReport>> moduleReports(Ref ref, ReportRequest request) {
  // Premium-filtered: Reports is a browsing surface like the dashboard,
  // not a data-integrity path — a gated module shouldn't show up here
  // for a user who can't access it.
  final modules = ref.watch(visibleHabitModulesProvider);
  return const AggregateReportUseCase().execute(
    modules: modules,
    period: request.period,
    periodAnchor: request.anchor,
    customRange: request.customRange,
  );
}
