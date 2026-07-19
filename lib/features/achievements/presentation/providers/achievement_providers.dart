import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// One achievement's definition (title/description/target) joined with
/// its persisted progress row, or zero/`null` progress if never
/// evaluated.
typedef AchievementView = ({
  AchievementDefinition definition,
  int progressCurrent,
  DateTime? unlockedAt,
});

/// Every registered module's achievement definitions joined with their
/// current persisted progress, for the badge gallery.
@riverpod
Stream<List<AchievementView>> achievementViews(Ref ref) {
  final modules = ref.watch(habitModulesProvider);
  final repository = ref.watch(achievementRepositoryProvider);
  return repository.watchAll().map((rows) {
    final rowsByKey = {for (final row in rows) row.key: row};
    return [
      for (final module in modules)
        for (final definition in module.achievementDefinitions)
          (
            definition: definition,
            progressCurrent: rowsByKey[definition.key]?.progressCurrent ?? 0,
            unlockedAt: () {
              final millis = rowsByKey[definition.key]?.unlockedAt;
              return millis == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
            }(),
          ),
    ];
  });
}
