import 'package:clock/clock.dart';
import 'package:habit_tracker/core/analytics/consistency_score_calculator.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'consistency_provider.g.dart';

/// Today's 0-100 composite "Consistency Score" across every enabled module
/// (`docs/superpowers/specs/08-analytics/05-consistency-score-IMPLEMENTATION-PLAN.md`
/// Task 2) — recomputed fresh on every watch, nothing persisted.
@riverpod
Future<int> consistencyScore(Ref ref) async {
  final modules = ref.watch(visibleHabitModulesProvider);
  final today = LocalDate.fromDateTime(clock.now());
  final range = DateRange(start: today, end: today);

  final moduleStatuses = <String, ModuleDayStatus>{};
  for (final module in modules) {
    final status = await module.dayStatus(range);
    if (status.containsKey(today)) {
      moduleStatuses[module.id] = status[today]!;
    }
  }

  return ConsistencyScoreCalculator.calculate(moduleStatuses: moduleStatuses);
}
