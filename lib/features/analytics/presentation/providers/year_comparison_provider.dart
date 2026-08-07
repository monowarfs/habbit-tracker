import 'package:clock/clock.dart';
import 'package:habit_tracker/core/analytics/year_comparison_use_case.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'year_comparison_provider.g.dart';

/// Whether the user has a full year of app history — the hard
/// prerequisite for the "vs. Last Year" comparison screen to mean
/// anything (`docs/superpowers/specs/08-analytics/
/// 06-comparison-to-past-self-design.md`).
@riverpod
bool yearComparisonEligible(Ref ref) {
  final installDate = ref.watch(appSettingsProvider).value?.installDate;
  return YearComparisonUseCase.isEligible(
    installDate: installDate,
    now: clock.now(),
  );
}

/// One module's current-vs-last-year series for [period] anchored at
/// [anchor] — shared by every module's card on the comparison screen,
/// same precedent as `moduleDayStatusProvider`.
@riverpod
Future<YearComparison> yearComparison(
  Ref ref,
  String moduleId,
  ReportPeriod period,
  LocalDate anchor,
) {
  final modules = ref.watch(habitModulesProvider);
  final module = modules.firstWhere((m) => m.id == moduleId);
  return const YearComparisonUseCase().fetch(
    module: module,
    periodAnchor: anchor,
    period: period,
  );
}
