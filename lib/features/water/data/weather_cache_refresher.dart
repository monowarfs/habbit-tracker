import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/data/weather_client.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

/// Staleness ceiling for using a cached weather reading in reminder copy
/// — a constant, not a user-facing setting (same "not configurable"
/// precedent as the undo snackbar's 4-second window;
/// `docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`).
const weatherCacheStalenessCeiling = Duration(hours: 6);

/// Refreshes the cached weather reading if `water_settings
/// .weather_nudge_enabled` is on and the cache is missing/stale — called
/// only from the Android WorkManager top-up, never from
/// `WaterModule.pendingNotifications()`'s own hot path. Silently no-ops
/// on any failure (permission denied, no connectivity, timeout); a missed
/// refresh is simply picked up again next tick.
///
/// [resolveLocation]/[fetchWeather] are test-only seams overriding
/// [resolveWeatherLocation]/[fetchCurrentWeather] — the same "nullable
/// function param, real implementation by default" pattern as
/// `PinSettingsScreen`'s `biometricAvailable`
/// (`docs/superpowers/plans/2026-07-21-pin-lock-toggles-fix.md`).
Future<void> refreshWeatherCacheIfStale(
  AppDatabase db, {
  Future<Result<WeatherLocation>> Function()? resolveLocation,
  Future<Result<WeatherSnapshot>> Function({
    required double latitude,
    required double longitude,
  })?
  fetchWeather,
}) async {
  final repository = WaterRepositoryImpl(db);
  final settings = await repository.watchSettings().first;
  if (!settings.weatherNudgeEnabled) return;

  final now = clock.now();
  final fetchedAt = settings.lastWeatherFetchedAt;
  if (fetchedAt != null &&
      now.difference(fetchedAt) < weatherCacheStalenessCeiling) {
    return;
  }

  final locationResult = await (resolveLocation ?? resolveWeatherLocation)();
  if (locationResult case Failure()) return;
  final location = (locationResult as Success<WeatherLocation>).value;

  final weatherResult = await (fetchWeather ?? _defaultFetchWeather)(
    latitude: location.latitude,
    longitude: location.longitude,
  );
  if (weatherResult case Failure()) return;
  final weather = (weatherResult as Success<WeatherSnapshot>).value;

  await repository.updateWeatherCache(
    temperatureCelsius: weather.temperatureCelsius,
    fetchedAt: weather.fetchedAt,
  );
}

Future<Result<WeatherSnapshot>> _defaultFetchWeather({
  required double latitude,
  required double longitude,
}) => fetchCurrentWeather(latitude: latitude, longitude: longitude);
