import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

const _profileId = 'system';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this._definitions);
  final List<AchievementDefinition> _definitions;

  @override
  String get id => 'fake';

  @override
  List<AchievementDefinition> get achievementDefinitions => _definitions;
}

void main() {
  late AppDatabase db;
  late AchievementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AchievementRepository(db);
  });

  tearDown(() => db.close());

  test(
    'evaluate persists progress for every definition the module contributes',
    () async {
      final module = _FakeModule([
        AchievementDefinition(
          key: 'fake_one',
          moduleId: 'fake',
          titleKey: 't',
          descriptionKey: 'd',
          target: 3,
          currentProgress: () async => 2,
        ),
      ]);
      final engine = AchievementEngine(repository: repo, modules: [module]);

      await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
        await engine.evaluate('fake', profileId: _profileId);
      });

      final row = await repo.byKey('fake_one', profileId: _profileId);
      expect(row, isNotNull);
      expect(row!.progressCurrent, 2);
      expect(row.progressTarget, 3);
      expect(row.unlockedAt, isNull);
    },
  );

  test(
    'evaluate sets unlockedAt exactly once when progress reaches target',
    () async {
      final module = _FakeModule([
        AchievementDefinition(
          key: 'fake_two',
          moduleId: 'fake',
          titleKey: 't',
          descriptionKey: 'd',
          target: 1,
          currentProgress: () async => 1,
        ),
      ]);
      final engine = AchievementEngine(repository: repo, modules: [module]);

      await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
        await engine.evaluate('fake', profileId: _profileId);
      });
      final firstUnlock = (await repo.byKey(
        'fake_two',
        profileId: _profileId,
      ))!.unlockedAt;
      expect(firstUnlock, isNotNull);

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 2)), () async {
        await engine.evaluate('fake', profileId: _profileId);
      });
      expect(
        (await repo.byKey('fake_two', profileId: _profileId))!.unlockedAt,
        firstUnlock,
      );
    },
  );
}
