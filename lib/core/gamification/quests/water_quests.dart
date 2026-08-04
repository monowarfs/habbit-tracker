import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';

/// Water's weekly quest catalog for [weekRange], evaluated against [module]'s
/// own `dayStatus`.
List<QuestDefinition> waterQuestDefinitions(
  HabitModule module,
  DateRange weekRange,
) => [
  QuestDefinition(
    questKey: 'water_goal_5_of_7',
    moduleId: 'water',
    titleKey: 'questWater5of7',
    descriptionKey: 'questWater5of7',
    target: 5,
    progressEvaluator: () => countDaysWithKind(
      module,
      weekRange,
      (kind) => kind == ModuleDayStatusKind.complete,
    ),
  ),
  QuestDefinition(
    questKey: 'water_no_skip_week',
    moduleId: 'water',
    titleKey: 'questWaterNoSkip',
    descriptionKey: 'questWaterNoSkip',
    target: 7,
    progressEvaluator: () => countDaysWithKind(
      module,
      weekRange,
      (kind) =>
          kind == ModuleDayStatusKind.complete ||
          kind == ModuleDayStatusKind.partial,
    ),
  ),
];
