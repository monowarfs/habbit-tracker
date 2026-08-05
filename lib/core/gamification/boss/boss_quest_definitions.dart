import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';

/// Boss quest catalog — one higher-threshold, bigger-presentation variant
/// per module, rotated weekly by `boss_rotation.dart`'s
/// `bossModuleForWeek`.
///
/// Reuses [QuestDefinition] rather than a separate `BossQuestDefinition`
/// class: `QuestEngine.evaluateModule` already walks a per-module list of
/// [QuestDefinition]s and calls `QuestRepository.updateProgress` generically
/// off `questKey`/`weekKey` — folding the week's boss definition into that
/// same list (`quest_engine.dart`'s `_catalog`) is what actually gets its
/// progress evaluated on every write; a separate type would need its own
/// parallel evaluation call site the plan's own pseudocode never specifies.
/// No `xpReward` field: the boss celebration shows no XP amount, same as
/// the regular weekly quests (spec 02's XP system was never built).
QuestDefinition? bossDefinitionFor(
  String moduleId,
  HabitModule module,
  DateRange weekRange,
) {
  return switch (moduleId) {
    'water' => QuestDefinition(
      questKey: 'boss_water_6_of_7',
      moduleId: 'water',
      titleKey: 'bossQuestWater6of7',
      descriptionKey: 'bossQuestWater6of7Desc',
      target: 6,
      progressEvaluator: () => countDaysWithKind(
        module,
        weekRange,
        (kind) => kind == ModuleDayStatusKind.complete,
      ),
    ),
    'medicine' => QuestDefinition(
      questKey: 'boss_medicine_perfect_week',
      moduleId: 'medicine',
      titleKey: 'bossQuestMedicinePerfect',
      descriptionKey: 'bossQuestMedicinePerfectDesc',
      target: 7,
      progressEvaluator: () => countDaysWithKind(
        module,
        weekRange,
        (kind) => kind == ModuleDayStatusKind.complete,
      ),
    ),
    'prayer' => QuestDefinition(
      questKey: 'boss_prayer_5of5_5days',
      moduleId: 'prayer',
      titleKey: 'bossQuestPrayer5of5',
      descriptionKey: 'bossQuestPrayer5of5Desc',
      target: 5,
      progressEvaluator: () => countDaysWithKind(
        module,
        weekRange,
        (kind) => kind == ModuleDayStatusKind.complete,
      ),
    ),
    _ => null,
  };
}
