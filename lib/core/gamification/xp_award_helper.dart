import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

/// Awards per-action XP for [moduleId], then checks whether today just
/// became fully complete for that module and, if so and not already
/// awarded, awards day-complete XP too. Called from Water/Medicine/
/// Prayer's controllers after a successful write (the plan's Task 5
/// "module write-path integration") — factored into one shared function
/// rather than tripled across the three controllers.
Future<void> awardActionXp(Ref ref, {required String moduleId}) async {
  final xpRepository = ref.read(xpRepositoryProvider);
  final now = clock.now();
  await xpRepository.awardXp(
    moduleId: moduleId,
    eventType: 'action',
    amount: XpValues.forEvent(moduleId, 'action'),
    now: now,
  );

  HabitModule? module;
  for (final m in ref.read(habitModulesProvider)) {
    if (m.id == moduleId) {
      module = m;
      break;
    }
  }
  if (module == null) return;

  final today = localDayKey(now);
  final statuses = await module.dayStatus(
    DateRange(start: today, end: today),
  );
  if (statuses[today]?.kind != ModuleDayStatusKind.complete) return;

  final sourceId = today.toIso();
  final alreadyAwarded = await xpRepository.hasAwarded(
    moduleId: moduleId,
    eventType: 'day_complete',
    sourceId: sourceId,
  );
  if (alreadyAwarded) return;
  await xpRepository.awardXp(
    moduleId: moduleId,
    eventType: 'day_complete',
    amount: XpValues.forEvent(moduleId, 'day_complete'),
    now: now,
    sourceId: sourceId,
  );
}
