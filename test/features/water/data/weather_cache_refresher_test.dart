import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/data/weather_cache_refresher.dart';
import 'package:habit_tracker/features/water/data/weather_client.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

import '../../../support/test_database.dart';

void main() {
  test('no-ops (never resolves location) when weatherNudgeEnabled is false',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = WaterRepositoryImpl(db);

    await refreshWeatherCacheIfStale(
      db,
      resolveLocation: () async => fail('should not be called'),
    );

    expect((await repo.watchSettings().first).lastWeatherFetchedAt, isNull);
  });

  test('no-ops when the cache is already fresh (under the 6-hour ceiling)',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = WaterRepositoryImpl(db);
    final now = DateTime.utc(2026, 6, 1, 12);

    await withClock(Clock.fixed(now), () async {
      await repo.updateWeatherNudgeEnabled(enabled: true);
      await repo.updateWeatherCache(
        temperatureCelsius: 30,
        fetchedAt: now.subtract(const Duration(hours: 1)),
      );

      await refreshWeatherCacheIfStale(
        db,
        resolveLocation: () async => fail('should not be called'),
      );

      expect(
        (await repo.watchSettings().first).lastWeatherTemperatureCelsius,
        30,
      );
    });
  });

  test('fetches and caches a fresh reading when enabled and stale', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = WaterRepositoryImpl(db);
    final now = DateTime.utc(2026, 6, 1, 12);

    await withClock(Clock.fixed(now), () async {
      await repo.updateWeatherNudgeEnabled(enabled: true);

      await refreshWeatherCacheIfStale(
        db,
        resolveLocation: () async =>
            const Result.success((latitude: 23.8103, longitude: 90.4125)),
        fetchWeather: ({required latitude, required longitude}) async =>
            Result.success((temperatureCelsius: 32.0, fetchedAt: now)),
      );

      final settings = await repo.watchSettings().first;
      expect(settings.lastWeatherTemperatureCelsius, 32.0);
      expect(settings.lastWeatherFetchedAt, now);
    });
  });

  test('leaves the cache untouched when location resolution fails',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = WaterRepositoryImpl(db);

    await repo.updateWeatherNudgeEnabled(enabled: true);

    await refreshWeatherCacheIfStale(
      db,
      resolveLocation: () async =>
          const Result.failure(AppException.permission('location')),
    );

    expect(
      (await repo.watchSettings().first).lastWeatherTemperatureCelsius,
      isNull,
    );
  });
}
