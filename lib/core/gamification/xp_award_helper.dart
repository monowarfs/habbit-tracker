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
///
/// [actionSourceId], when given (medicine's dose id, prayer's record
/// id), dedupes the action award the same way `XpRepository.awardXp`'s
/// `day_complete` award already is — without it, a mark/undo/mark or
/// mark/unmark/mark cycle on the same underlying record re-earns action
/// XP indefinitely (PR #79 review finding). Water has no stable id to
/// dedupe a fresh log entry against (a genuinely new entry each time),
/// so it's called with `actionSourceId: null` — a known, accepted
/// limitation for this size of change (same trade-off precedent as
/// `medicine_home_screen.dart`'s "achievement engine has no revoke
/// path" note): closing it needs real XP reversal on delete, not dedup.
Future<void> awardActionXp(
  Ref ref, {
  required String moduleId,
  String? actionSourceId,
}) async {
  final xpRepository = ref.read(xpRepositoryProvider);
  final now = clock.now();
  final actionAlreadyAwarded =
      actionSourceId != null &&
      await xpRepository.hasAwarded(
        moduleId: moduleId,
        eventType: 'action',
        sourceId: actionSourceId,
      );
  if (!actionAlreadyAwarded) {
    await xpRepository.awardXp(
      moduleId: moduleId,
      eventType: 'action',
      amount: XpValues.forEvent(moduleId, 'action'),
      now: now,
      sourceId: actionSourceId,
    );
  }

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
