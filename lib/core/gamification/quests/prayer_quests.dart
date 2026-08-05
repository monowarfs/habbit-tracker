import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';

/// Prayer's weekly quest catalog for [weekRange], evaluated against
/// [module]'s own `dayStatus`.
List<QuestDefinition> prayerQuestDefinitions(
  HabitModule module,
  DateRange weekRange,
) => [
  QuestDefinition(
    questKey: 'prayer_5_of_7',
    moduleId: 'prayer',
    titleKey: 'questPrayer5of7',
    descriptionKey: 'questPrayer5of7',
    target: 5,
    progressEvaluator: () => countDaysWithKind(
      module,
      weekRange,
      (kind) => kind == ModuleDayStatusKind.complete,
    ),
  ),
  QuestDefinition(
    questKey: 'prayer_no_skip_week',
    moduleId: 'prayer',
    titleKey: 'questPrayerNoSkip',
    descriptionKey: 'questPrayerNoSkip',
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
