import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';

void main() {
  late AppDatabase db;
  late WaterRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('wipeAll deletes every goal, log, and settings row', () async {
    await repo.addEntry(
      amountMl: 250,
      loggedAt: DateTime.utc(2026, 6),
      source: WaterEntrySource.quick,
    );
    await repo.setGoal(2000, effectiveFrom: DateTime.utc(2026, 6));
    await repo.updateQuickAddAmounts([100, 200]);

    await repo.wipeAll();

    expect(await repo.allEntries(), isEmpty);
    final goalRows = await db.select(db.waterGoalsTable).get();
    expect(goalRows, isEmpty);
    final settingsRows = await db.select(db.waterSettingsTable).get();
    expect(settingsRows, isEmpty);
  });

  test(
    'weather nudge defaults to off with no cache, persists a toggle, and '
    'persists a cached reading',
    () async {
      final firstRead = await repo.watchSettings().first;
      expect(firstRead.weatherNudgeEnabled, isFalse);
      expect(firstRead.lastWeatherTemperatureCelsius, isNull);
      expect(firstRead.lastWeatherFetchedAt, isNull);

      final toggleResult = await repo.updateWeatherNudgeEnabled(
        enabled: true,
      );
      expect(toggleResult, isA<Success<void>>());
      expect(
        (await repo.watchSettings().first).weatherNudgeEnabled,
        isTrue,
      );

      final fetchedAt = DateTime.utc(2026, 6, 1, 12);
      final cacheResult = await repo.updateWeatherCache(
        temperatureCelsius: 34.5,
        fetchedAt: fetchedAt,
      );
      expect(cacheResult, isA<Success<void>>());
      final afterCache = await repo.watchSettings().first;
      expect(afterCache.lastWeatherTemperatureCelsius, 34.5);
      expect(afterCache.lastWeatherFetchedAt, fetchedAt);
    },
  );
}
