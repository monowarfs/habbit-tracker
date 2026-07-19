import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reports_providers.g.dart';

/// The requested period + anchor day, used as a family provider parameter.
typedef ReportRequest = ({ReportPeriod period, LocalDate anchor});

/// Every enabled module's [ModuleReport] for [request].
@riverpod
Future<List<ModuleReport>> moduleReports(Ref ref, ReportRequest request) {
  final modules = ref.watch(habitModulesProvider);
  return const AggregateReportUseCase().execute(
    modules: modules,
    period: request.period,
    periodAnchor: request.anchor,
  );
}
