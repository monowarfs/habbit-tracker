import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/xp_award_listener.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this.achievementDefinitions);
  @override
  final String id;
  @override
  final List<AchievementDefinition> achievementDefinitions;
}

AchievementDefinition _def(String key, {int target = 1, int progress = 1}) =>
    AchievementDefinition(
      key: key,
      moduleId: 'water',
      titleKey: 'title',
      descriptionKey: 'desc',
      target: target,
      currentProgress: () async => progress,
    );

void main() {
  test(
    'awards XP for a justUnlocked streak achievement, ignores non-streak',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final module = _FakeModule('water', [
        _def('water_streak_7'),
        _def('water_first_log'),
      ]);
      final achievementEngine = AchievementEngine(
        repository: AchievementRepository(db),
        modules: [module],
      );
      final xpRepository = XpRepository(db);
      final listener = XpAwardListener(
        achievementEngine: achievementEngine,
        xpRepository: xpRepository,
      );
      final subscription = listener.listen();
      addTearDown(subscription.cancel);

      await achievementEngine.evaluate('water');
      // The event stream is async — let it flush.
      await Future<void>.delayed(Duration.zero);

      expect(await xpRepository.totalXp(), XpValues.streakMilestone);
      final ledger = await xpRepository.recentLedger();
      expect(ledger, hasLength(1));
      expect(ledger.single.sourceId, 'water_streak_7');
      expect(ledger.single.eventType, 'streak_milestone');
    },
  );

  test(
    'a second evaluate() of an already-unlocked streak does not re-award',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final module = _FakeModule('water', [_def('water_streak_7')]);
      final achievementEngine = AchievementEngine(
        repository: AchievementRepository(db),
        modules: [module],
      );
      final xpRepository = XpRepository(db);
      final listener = XpAwardListener(
        achievementEngine: achievementEngine,
        xpRepository: xpRepository,
      );
      final subscription = listener.listen();
      addTearDown(subscription.cancel);

      await achievementEngine.evaluate('water');
      await Future<void>.delayed(Duration.zero);
      await achievementEngine.evaluate('water');
      await Future<void>.delayed(Duration.zero);

      expect(await xpRepository.totalXp(), XpValues.streakMilestone);
    },
  );
}
