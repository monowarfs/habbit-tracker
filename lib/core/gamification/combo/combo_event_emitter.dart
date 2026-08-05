import 'package:habit_tracker/core/gamification/combo/combo_detector.dart';
import 'package:habit_tracker/core/gamification/combo/combo_event.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

/// Checks today's combo status and awards [XpValues.comboBonus] the
/// first time a combo is detected for a given day. The XP ledger's
/// `hasAwarded` dedup check doubles as the "once per day" gate the plan
/// calls for (Task 5) — no separate "already emitted today" tracking
/// needed, same pattern as `xp_award_helper.dart`'s day-complete award.
class ComboEventEmitter {
  /// Creates an emitter over [comboDetector] and [modules], awarding
  /// through [xpRepository].
  ComboEventEmitter({
    required this.comboDetector,
    required this.modules,
    required this.xpRepository,
  });

  /// Detects whether today is a combo day.
  final ComboDetector comboDetector;

  /// Every active module — the same list the dashboard's day-completion
  /// indicator already uses.
  final List<HabitModule> modules;

  /// Where the combo bonus XP lands.
  final XpRepository xpRepository;

  /// Checks today's combo status and, if it's a fresh combo day (not
  /// already awarded), records the XP and returns the event. Returns
  /// `null` if today isn't a combo day, or already was awarded.
  Future<ComboEvent?> checkAndEmit({required DateTime now}) async {
    final today = localDayKey(now);
    final isCombo = await comboDetector.isComboDay(
      date: today,
      modules: modules,
    );
    if (!isCombo) return null;

    final sourceId = 'combo_${today.toIso()}';
    final alreadyAwarded = await xpRepository.hasAwarded(
      moduleId: 'core',
      eventType: 'combo_bonus',
      sourceId: sourceId,
    );
    if (alreadyAwarded) return null;

    await xpRepository.awardXp(
      moduleId: 'core',
      eventType: 'combo_bonus',
      amount: XpValues.comboBonus,
      now: now,
      sourceId: sourceId,
    );

    return ComboEvent(
      date: today,
      modulesCompleted: modules.length,
      totalActiveModules: modules.length,
    );
  }
}
