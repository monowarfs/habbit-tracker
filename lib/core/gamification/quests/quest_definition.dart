import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';

/// One weekly quest a module contributes to the shared engine
/// (`quest_engine.dart`). [progressEvaluator] closes over the module's own
/// data for one specific week — catalogs are rebuilt fresh on every
/// evaluation (`quest_engine.dart`'s `_catalog`), never cached across weeks,
/// so a stale week never leaks into a closure.
class QuestDefinition {
  /// Creates a quest definition.
  const QuestDefinition({
    required this.questKey,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.progressEvaluator,
  });

  /// Stable key (e.g. `'water_goal_5_of_7'`) — the `weekly_quests.quest_key`
  /// column and this quest's identity across weeks.
  final String questKey;

  /// Which module this quest belongs to.
  final String moduleId;

  /// `AppLocalizations` key naming this quest's title.
  final String titleKey;

  /// `AppLocalizations` key naming this quest's description.
  final String descriptionKey;

  /// Progress needed to complete the quest.
  final int target;

  /// Computes current progress toward [target] from live data.
  final Future<int> Function() progressEvaluator;
}

/// Counts days in [weekRange] whose [module] day-status kind [matches] —
/// the shared building block behind every "N of 7 days" weekly quest.
Future<int> countDaysWithKind(
  HabitModule module,
  DateRange weekRange,
  bool Function(ModuleDayStatusKind kind) matches,
) async {
  final statuses = await module.dayStatus(weekRange);
  return statuses.values.where((status) => matches(status.kind)).length;
}
