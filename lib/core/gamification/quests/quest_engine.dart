import 'package:habit_tracker/core/gamification/boss/boss_quest_definitions.dart';
import 'package:habit_tracker/core/gamification/boss/boss_rotation.dart';
import 'package:habit_tracker/core/gamification/quests/medicine_quests.dart';
import 'package:habit_tracker/core/gamification/quests/prayer_quests.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';
import 'package:habit_tracker/core/gamification/quests/water_quests.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';

/// Evaluates weekly quests for Water/Medicine/Prayer and persists
/// progress through [repository] (D-quest engine, mirrors
/// `core/achievements/achievement_engine.dart`'s evaluate-after-write
/// pattern with a weekly reset window instead of a lifetime one).
class QuestEngine {
  /// Creates an engine over [modules], persisting through [repository].
  /// [medicineRepository] is the one module-specific dependency the
  /// quest catalog needs beyond `HabitModule.dayStatus()`
  /// (`medicine_quests.dart`'s 90%-adherence quest).
  QuestEngine({
    required this.repository,
    required this.modules,
    required this.medicineRepository,
  });

  /// Where quest progress is stored.
  final QuestRepository repository;

  /// Every registered module — quest catalogs are built from whichever
  /// of these has `id == 'water'|'medicine'|'prayer'`.
  final List<HabitModule> modules;

  /// Backs the medicine 90%-adherence quest.
  final MedicineRepository medicineRepository;

  /// Generates the current week's quests if they don't already exist.
  /// Safe to call repeatedly — [QuestRepository.ensureCurrentWeekQuests]
  /// is a no-op for quests that already have a row.
  Future<void> generateWeek({
    required DateTime now,
    required String profileId,
  }) async {
    final weekRange = _weekRangeFor(now);
    await repository.ensureCurrentWeekQuests(
      definitions: _catalog(weekRange, profileId),
      now: now,
      profileId: profileId,
    );
    final weekKey = weekKeyForDate(localDayKey(now));
    final bossDef = _bossDefinition(weekKey, weekRange);
    if (bossDef != null) {
      await repository.ensureBossQuest(
        bossDef,
        weekKey: weekKey,
        now: now,
        profileId: profileId,
      );
    }
  }

  /// Re-evaluates [moduleId]'s quests for the current week, generating
  /// the week's quests first if this is the first write since Monday.
  /// Includes the week's boss quest when [moduleId] is this week's
  /// spotlighted boss module.
  Future<void> evaluateModule(
    String moduleId, {
    required DateTime now,
    required String profileId,
  }) async {
    await generateWeek(now: now, profileId: profileId);
    final weekKey = weekKeyForDate(localDayKey(now));
    final weekRange = _weekRangeFor(now);
    final defs = _catalog(
      weekRange,
      profileId,
    ).where((d) => d.moduleId == moduleId).toList();
    final bossDef = _bossDefinition(weekKey, weekRange);
    if (bossDef != null && bossDef.moduleId == moduleId) {
      defs.add(bossDef);
    }
    for (final def in defs) {
      final progress = await def.progressEvaluator();
      await repository.updateProgress(
        questKey: def.questKey,
        weekKey: weekKey,
        current: progress.clamp(0, def.target),
        now: now,
        profileId: profileId,
      );
    }
  }

  /// The current week's boss definition for whichever module
  /// [bossModuleForWeek] spotlights, or `null` if that module isn't
  /// currently registered (e.g. running with a restricted module set).
  QuestDefinition? _bossDefinition(String weekKey, DateRange weekRange) {
    final bossModuleId = bossModuleForWeek(weekKey);
    final module = _moduleById(bossModuleId);
    if (module == null) return null;
    return bossDefinitionFor(bossModuleId, module, weekRange);
  }

  DateRange _weekRangeFor(DateTime now) {
    final today = localDayKey(now);
    final monday = mondayOfWeek(today);
    return DateRange(start: monday, end: monday.addDays(6));
  }

  List<QuestDefinition> _catalog(DateRange weekRange, String profileId) {
    final water = _moduleById('water');
    final medicine = _moduleById('medicine');
    final prayer = _moduleById('prayer');
    return [
      if (water != null) ...waterQuestDefinitions(water, weekRange),
      if (medicine != null)
        ...medicineQuestDefinitions(
          medicine,
          medicineRepository,
          weekRange,
          profileId: profileId,
        ),
      if (prayer != null) ...prayerQuestDefinitions(prayer, weekRange),
    ];
  }

  HabitModule? _moduleById(String id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }
}
