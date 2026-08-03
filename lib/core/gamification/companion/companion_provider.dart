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
///
/// A calendar day counts as complete only if every module that has data for
/// that day reports `complete` — matching the "N of the last 7 days" wording
/// in [CompanionMood]'s docs regardless of how many modules are enabled.
/// Days with no data from any module are excluded, not counted as missed.
@riverpod
Future<CompanionMood> companionMood(Ref ref) async {
  final modules = ref.watch(habitModulesProvider);
  if (modules.isEmpty) return CompanionMood.neutral;

  final today = localDayKey(clock.now());
  final sevenDaysAgo = today.addDays(-6);
  final range = DateRange(start: sevenDaysAgo, end: today);

  final perModuleStatus = await Future.wait(
    modules.map((module) => module.dayStatus(range)),
  );

  final recentDays = <ModuleDayStatus>[];
  for (var i = 0; i < 7; i++) {
    final day = sevenDaysAgo.addDays(i);
    final dayStatuses = perModuleStatus
        .map((statusByDay) => statusByDay[day])
        .whereType<ModuleDayStatus>()
        .where((status) => status.kind != ModuleDayStatusKind.none)
        .toList();
    if (dayStatuses.isEmpty) continue;

    final dayComplete = dayStatuses.every(
      (status) => status.kind == ModuleDayStatusKind.complete,
    );
    recentDays.add(
      ModuleDayStatus(
        kind: dayComplete
            ? ModuleDayStatusKind.complete
            : ModuleDayStatusKind.missed,
        value: 0,
      ),
    );
  }

  return deriveCompanionMood(recentDays);
}
