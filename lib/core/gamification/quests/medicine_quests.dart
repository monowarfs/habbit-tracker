import 'package:clock/clock.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';

/// Medicine's weekly quest catalog for [weekRange]. `medicine_perfect_week`
/// is evaluated against [module]'s own `dayStatus`; `medicine_90_percent`
/// needs the raw dose list so it can reuse [calculateAdherence]'s
/// on-time/late split, which `dayStatus`'s per-day kind doesn't expose.
List<QuestDefinition> medicineQuestDefinitions(
  HabitModule module,
  MedicineRepository repository,
  DateRange weekRange, {
  required String profileId,
}) => [
  QuestDefinition(
    questKey: 'medicine_perfect_week',
    moduleId: 'medicine',
    titleKey: 'questMedicinePerfect',
    descriptionKey: 'questMedicinePerfect',
    target: 7,
    progressEvaluator: () => countDaysWithKind(
      module,
      weekRange,
      (kind) => kind == ModuleDayStatusKind.complete,
    ),
  ),
  QuestDefinition(
    questKey: 'medicine_90_percent',
    moduleId: 'medicine',
    titleKey: 'questMedicine90',
    descriptionKey: 'questMedicine90',
    target: 90,
    progressEvaluator: () async {
      final doses = await repository.dosesInRange(
        weekRange.start,
        weekRange.end,
        profileId: profileId,
      );
      final stats = calculateAdherence(doses: doses, now: clock.now());
      if (stats.total == 0) return 0;
      return (((stats.takenOnTime + stats.takenLate) / stats.total) * 100)
          .round();
    },
  ),
];
