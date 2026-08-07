import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/quests/quest_engine.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quest_providers.g.dart';

/// The shared [QuestRepository].
@Riverpod(keepAlive: true)
QuestRepository questRepository(Ref ref) {
  return QuestRepository(ref.watch(databaseProvider));
}

/// The shared [QuestEngine], rebuilt if the module list changes.
@Riverpod(keepAlive: true)
QuestEngine questEngine(Ref ref) {
  return QuestEngine(
    repository: ref.watch(questRepositoryProvider),
    modules: ref.watch(habitModulesProvider),
    medicineRepository: ref.watch(medicineRepositoryProvider),
  );
}

/// This week's quests, live-updating.
///
/// Hand-written (not `@riverpod` codegen) — `riverpod_generator` can't
/// convert a Drift-generated `DataClass` (`WeeklyQuestRow`) to code for
/// its provider metadata (`InvalidTypeException`, reproduced with the
/// pre-existing `AchievementRow` too, so this is a generator limitation
/// with any Drift row type, not something specific to this table).
final currentWeekQuestsProvider = StreamProvider<List<WeeklyQuestRow>>((ref) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  final weekKey = weekKeyForDate(localDayKey(clock.now()));
  return ref
      .watch(questRepositoryProvider)
      .watchCurrentWeek(weekKey: weekKey, profileId: profileId);
});

/// This week's quests that haven't been completed yet.
final activeQuestsProvider = Provider<List<WeeklyQuestRow>>((ref) {
  final quests = ref.watch(currentWeekQuestsProvider).value ?? const [];
  return quests.where((q) => q.completedAt == null).toList();
});
