import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late AchievementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AchievementRepository(db);
  });

  tearDown(() => db.close());

  test('upsertProgress creates a row when none exists', () async {
    await repo.upsertProgress(
      moduleId: 'water',
      key: 'water_first_log',
      current: 1,
      target: 1,
      now: DateTime.utc(2026, 6),
    );
    final row = await repo.byKey('water_first_log');
    expect(row, isNotNull);
    expect(row!.progressCurrent, 1);
    expect(row.unlockedAt, DateTime.utc(2026, 6).millisecondsSinceEpoch);
  });

  test(
    'upsertProgress updates an existing row without re-locking it',
    () async {
      await repo.upsertProgress(
        moduleId: 'water',
        key: 'water_streak_7',
        current: 7,
        target: 7,
        now: DateTime.utc(2026, 6),
      );
      final firstUnlock = (await repo.byKey('water_streak_7'))!.unlockedAt;

      await repo.upsertProgress(
        moduleId: 'water',
        key: 'water_streak_7',
        current: 0,
        target: 7,
        now: DateTime.utc(2026, 6, 2),
      );
      final row = await repo.byKey('water_streak_7');
      expect(row!.progressCurrent, 0);
      expect(row.unlockedAt, firstUnlock);
    },
  );

  test('byKey returns null for an unknown key', () async {
    expect(await repo.byKey('nope'), isNull);
  });
}
