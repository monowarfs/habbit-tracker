import 'package:clock/clock.dart';
import 'package:habit_tracker/core/gamification/companion/companion_mood.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'companion_provider.g.dart';

/// The virtual companion's current mood, derived from the last 7 days of
/// `dayStatus()` across every registered module — no new tracking concept.
@riverpod
Future<CompanionMood> companionMood(Ref ref) async {
  final modules = ref.watch(habitModulesProvider);
  final today = localDayKey(clock.now());
  final sevenDaysAgo = today.addDays(-6);
  final range = DateRange(start: sevenDaysAgo, end: today);

  final allStatuses = <ModuleDayStatus>[];
  for (final module in modules) {
    final status = await module.dayStatus(range);
    allStatuses.addAll(status.values);
  }

  return deriveCompanionMood(allStatuses);
}
