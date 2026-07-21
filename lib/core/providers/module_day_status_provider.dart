import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'module_day_status_provider.g.dart';

/// A single module's `dayStatus()` over [range] — shared by every
/// per-habit heatmap calendar screen (`docs/superpowers/specs/
/// 2026-07-21-01-per-habit-calendar-heatmap-design.md`) instead of each
/// screen hand-rolling its own fetch/loading/error state.
@riverpod
Future<Map<LocalDate, ModuleDayStatus>> moduleDayStatus(
  Ref ref,
  String moduleId,
  DateRange range,
) {
  final modules = ref.watch(habitModulesProvider);
  final module = modules.firstWhere((m) => m.id == moduleId);
  return module.dayStatus(range);
}
