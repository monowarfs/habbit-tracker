import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// The shared [AchievementRepository].
@Riverpod(keepAlive: true)
AchievementRepository achievementRepository(Ref ref) {
  return AchievementRepository(ref.watch(databaseProvider));
}

/// The shared [AchievementEngine], rebuilt if the module list changes.
@Riverpod(keepAlive: true)
AchievementEngine achievementEngine(Ref ref) {
  return AchievementEngine(
    repository: ref.watch(achievementRepositoryProvider),
    modules: ref.watch(habitModulesProvider),
  );
}
