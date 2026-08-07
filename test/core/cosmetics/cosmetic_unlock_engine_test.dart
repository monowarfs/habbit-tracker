import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_unlock_engine.dart';
import 'package:habit_tracker/core/database/app_database.dart';

const _profileId = 'system';

void main() {
  late AppDatabase db;
  late CosmeticRepository repository;
  late CosmeticUnlockEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = CosmeticRepository(db);
    engine = CosmeticUnlockEngine(cosmeticRepository: repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('unlocking a streak achievement records its avatar piece tagged '
      'with the matching slot', () async {
    await engine.onAchievementUnlocked('water_streak_7', profileId: _profileId);

    final unlocked = await repository.unlockedKeys(
      profileId: _profileId,
    );
    expect(unlocked, contains('head_bandana'));

    final row = await (db.select(
      db.cosmeticUnlocksTable,
    )..where((t) => t.cosmeticKey.equals('head_bandana'))).getSingle();
    expect(row.slot, 'head');
  });

  test('non-avatar cosmetic unlock leaves slot null', () async {
    await engine.onAchievementUnlocked('tenure_2_year', profileId: _profileId);

    final row = await (db.select(
      db.cosmeticUnlocksTable,
    )..where((t) => t.cosmeticKey.equals('theme_accent_midnight'))).getSingle();
    expect(row.slot, isNull);
  });

  test('unmapped achievement key is a no-op', () async {
    await engine.onAchievementUnlocked(
      'water_first_log',
      profileId: _profileId,
    );

    final unlocked = await repository.unlockedKeys(
      profileId: _profileId,
    );
    expect(unlocked, isEmpty);
  });

  test('unlocking twice does not duplicate the row', () async {
    await engine.onAchievementUnlocked('water_streak_7', profileId: _profileId);
    await engine.onAchievementUnlocked('water_streak_7', profileId: _profileId);

    final rows = await db.select(db.cosmeticUnlocksTable).get();
    expect(rows.where((r) => r.cosmeticKey == 'head_bandana'), hasLength(1));
  });

  test('watchUnlockedAvatarPieceIds excludes non-avatar cosmetics', () async {
    await engine.onAchievementUnlocked('water_streak_7', profileId: _profileId);
    await engine.onAchievementUnlocked('tenure_2_year', profileId: _profileId);

    final avatarOnly = await repository
        .watchUnlockedAvatarPieceIds(
          profileId: _profileId,
        )
        .first;
    expect(avatarOnly, {'head_bandana'});
    expect(avatarOnly, isNot(contains('theme_accent_midnight')));
  });
}
