# Weather-Aware Water Nudge Copy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Append a short, opt-in weather clause (e.g. "It's 34°C today.")
to Water's reminder body when a fresh cached temperature reading exists,
per `docs/superpowers/specs/02-delightful/07-weather-aware-water-nudge-
copy-design.md` — the app's first feature to touch the network at all,
shipped strictly behind a default-off toggle that degrades to today's
exact copy on any failure.

**Architecture:** One new file (`weather_client.dart`) owns the only
`http` call in the app (Open-Meteo, no API key). A second, independent
`geolocator` call site (`weather_location_resolver.dart`) resolves
weather-only location — deliberately not sharing Prayer's
`resolveLocation()`, since the two features need two independent opt-ins.
A cache (two new `water_settings` columns) is refreshed by the existing
Android WorkManager 8-hour top-up only; `WaterModule.pendingNotifications()`
only ever *reads* that cache — zero I/O on its own hot path. A 6-hour
staleness ceiling (a constant, not a setting) decides whether a cached
reading is still usable.

**Tech Stack:** Flutter/Dart, `http` (new), Riverpod (codegen), Drift
(codegen), `gen_l10n`, `flutter_test` (using `package:http/testing.dart`'s
`MockClient` — no new mocking dependency).

## Global Constraints

- **New dependency:** `http: ^1.2.0`. No weather-SDK package — a raw GET
  against Open-Meteo's public REST API
  (`https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m`,
  response at `current.temperature_2m`) is simpler than any wrapper.
- **First network-access exception to offline-first identity** — ships
  behind an explicit, default-off, clearly-explained opt-in (an explainer
  dialog before the location permission prompt), never silently enabled.
- **Migration:** one more `if (from < N)` block in
  `AppDatabase.migration.onUpgrade` (current `schemaVersion` is `7` as of
  this plan — if another schema-bumping plan merges first, adjust `7`/`N`
  to whatever is then current) adding `weatherNudgeEnabled` (bool, default
  `false`), `lastWeatherTemperatureCelsius` (nullable real),
  `lastWeatherFetchedAtMillis` (nullable int) to `WaterSettingsTable`.
- **No new call site inside `pendingNotifications()`'s own execution** —
  it only reads the cache; the only new network/location call site is the
  WorkManager top-up (Android-only, matching the existing platform
  asymmetry already documented at `notification_workmanager.dart:12-16`).
  On iOS the cache only refreshes on app-resume — this plan does not add
  an iOS refresh trigger; that's an accepted, documented gap, not a new
  mechanism to build.
- **Never blocks a reminder on a network call** — a network/location
  failure anywhere degrades silently to the existing plain copy; nothing
  above `logger.d`-level logging, nothing surfaced to the user as an error.
- **Staleness ceiling: 6 hours**, a `Duration` constant
  (`weatherCacheStalenessCeiling`), not a user-facing setting — same
  "not configurable" precedent as the undo snackbar's 4-second window.
- No weather-based timing/cadence changes, no general weather-display
  screen, no °C/°F setting (Celsius only), no copy-variant system (one
  template string), no retry/backoff (one attempt per WorkManager tick).
- New l10n keys go in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Weather HTTP client

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/water/data/weather_client.dart`
- Test: `test/features/water/data/weather_client_test.dart`

**Interfaces:**
- Produces: `typedef WeatherSnapshot = ({double temperatureCelsius,
  DateTime fetchedAt})`, `Future<Result<WeatherSnapshot>>
  fetchCurrentWeather({required double latitude, required double
  longitude, Duration timeout, http.Client? client})` — consumed by
  Task 4's cache refresher.

- [ ] **Step 1: Write the failing test**

Create `test/features/water/data/weather_client_test.dart`:

```dart
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/weather_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful response into a WeatherSnapshot', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.queryParameters['latitude'], '23.8103');
      expect(request.url.queryParameters['longitude'], '90.4125');
      expect(request.url.queryParameters['current'], 'temperature_2m');
      return http.Response(
        '{"latitude":23.8103,"longitude":90.4125,'
        '"current":{"temperature_2m":34.2,"time":"2026-06-01T12:00"}}',
        200,
      );
    });

    final result = await fetchCurrentWeather(
      latitude: 23.8103,
      longitude: 90.4125,
      client: client,
    );

    expect(result, isA<Success<WeatherSnapshot>>());
    expect(
      (result as Success<WeatherSnapshot>).value.temperatureCelsius,
      34.2,
    );
  });

  test('a non-200 response is a Failure, not a thrown exception', () async {
    final client = MockClient((request) async => http.Response('boom', 500));

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });

  test('a slow response past the timeout is a Failure', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{"current":{"temperature_2m":20}}', 200);
    });

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      timeout: const Duration(milliseconds: 5),
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });

  test('malformed JSON is a Failure', () async {
    final client = MockClient((request) async => http.Response('not json', 200));

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/data/weather_client_test.dart | tail -10`
Expected: FAIL — `lib/features/water/data/weather_client.dart` and the
`http` package don't exist yet.

- [ ] **Step 3: Add the dependency and write the implementation**

In `pubspec.yaml`, add to `dependencies:` (alphabetically, after
`home_widget`):

```yaml
  http: ^1.2.0
```

Run: `flutter pub get | tail -10`

Create `lib/features/water/data/weather_client.dart`:

```dart
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:http/http.dart' as http;

/// Current-conditions snapshot used for reminder-copy enrichment only —
/// never displayed as a dedicated weather feature (out of scope,
/// `docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`).
typedef WeatherSnapshot = ({double temperatureCelsius, DateTime fetchedAt});

/// Fetches current temperature for [latitude]/[longitude] from Open-Meteo
/// — the sole file touching the weather API or `http` directly, same
/// "one file owns the plugin" precedent as `notification_service.dart`/
/// `location_resolver.dart`. Never allowed to block notification
/// planning: a short [timeout], and any error (timeout, no connectivity,
/// bad response, malformed JSON) becomes a `Failure`, never a thrown
/// exception. [client] is an injectable seam for tests
/// (`package:http/testing.dart`'s `MockClient`) — production callers omit
/// it and get a real, short-lived `http.Client`.
Future<Result<WeatherSnapshot>> fetchCurrentWeather({
  required double latitude,
  required double longitude,
  Duration timeout = const Duration(seconds: 5),
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m',
    });
    final response = await httpClient.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return Result.failure(
        AppException.unexpected(
          Exception('weather fetch returned HTTP ${response.statusCode}'),
          StackTrace.current,
        ),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final temperature = (current['temperature_2m'] as num).toDouble();
    return Result.success((
      temperatureCelsius: temperature,
      fetchedAt: clock.now().toUtc(),
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  } finally {
    if (client == null) httpClient.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/water/data/weather_client_test.dart | tail -10`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/water/data/weather_client.dart | tail -10`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/water/data/weather_client.dart \
  test/features/water/data/weather_client_test.dart
git commit -m "feat(water): add the Open-Meteo current-weather client"
```

---

### Task 2: Water settings — weather opt-in and cache columns

**Files:**
- Modify: `lib/features/water/data/tables/water_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:53-54,100-107`
- Modify: `lib/features/water/domain/entities/water_settings.dart`
- Modify: `lib/features/water/domain/repositories/water_repository.dart`
- Modify: `lib/features/water/data/repositories/water_repository_impl.dart`
- Test: `test/features/water/data/repositories/water_repository_impl_test.dart`

**Interfaces:**
- Produces: `WaterSettings.weatherNudgeEnabled` (`bool`, `@Default(false)`),
  `WaterSettings.lastWeatherTemperatureCelsius` (`double?`),
  `WaterSettings.lastWeatherFetchedAt` (`DateTime?`) — consumed by
  Tasks 4/5/6.
- Produces: `WaterRepository.updateWeatherNudgeEnabled({required bool
  enabled})`, `WaterRepository.updateWeatherCache({required double
  temperatureCelsius, required DateTime fetchedAt})` — consumed by
  Tasks 4/6.

- [ ] **Step 1: Write the failing test**

Add to `test/features/water/data/repositories/water_repository_impl_test.dart`
(inside `main()`, after the existing `wipeAll` test):

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/data/repositories/water_repository_impl_test.dart | tail -10`
Expected: compile error — `weatherNudgeEnabled`/
`lastWeatherTemperatureCelsius`/`lastWeatherFetchedAt`/
`updateWeatherNudgeEnabled`/`updateWeatherCache` don't exist yet.

- [ ] **Step 3: Add the DB columns**

In `lib/features/water/data/tables/water_settings_table.dart`, add after
`reminderWindowOverrides`, before `createdAt`:

```dart
  /// Opt-in: attach a weather-derived clause to reminder copy
  /// (`docs/superpowers/specs/02-delightful/
  /// 07-weather-aware-water-nudge-copy-design.md`). Default `false` —
  /// never silently turns on network/location access.
  BoolColumn get weatherNudgeEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Last successful weather fetch's temperature, cached alongside the
  /// reading itself so `pendingNotifications()` never needs a network
  /// round-trip on its own hot path — populated only by the WorkManager
  /// refresh, read-only from `pendingNotifications()`.
  RealColumn get lastWeatherTemperatureCelsius => real().nullable()();

  /// UTC epoch millis of [lastWeatherTemperatureCelsius]'s fetch.
  IntColumn get lastWeatherFetchedAtMillis => integer().nullable()();
```

- [ ] **Step 4: Bump schema version and add the migration**

In `lib/core/database/app_database.dart`, change:

```dart
  @override
  int get schemaVersion => 7;
```

to:

```dart
  @override
  int get schemaVersion => 8;
```

And add a new block right before the `// Seam:` comment inside
`onUpgrade`:

```dart
      if (from < 8) {
        // Weather-aware water reminder copy (`docs/superpowers/specs/
        // 02-delightful/07-weather-aware-water-nudge-copy-design.md`).
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.weatherNudgeEnabled,
        );
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.lastWeatherTemperatureCelsius,
        );
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.lastWeatherFetchedAtMillis,
        );
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
```

- [ ] **Step 5: Add the entity fields**

In `lib/features/water/domain/entities/water_settings.dart`, change the
factory from:

```dart
    @Default({})
    Map<int, ({LocalTime start, LocalTime end})> reminderWindowOverrides,
  }) = _WaterSettings;
```

to:

```dart
    @Default({})
    Map<int, ({LocalTime start, LocalTime end})> reminderWindowOverrides,
    @Default(false) bool weatherNudgeEnabled,
    double? lastWeatherTemperatureCelsius,
    DateTime? lastWeatherFetchedAt,
  }) = _WaterSettings;
```

- [ ] **Step 6: Add the repository interface methods**

In `lib/features/water/domain/repositories/water_repository.dart`, add
after `updateReminderSettings`:

```dart
  /// Enables or disables the weather-derived reminder-copy clause. Default
  /// false — opt-in only, since enabling it implies location + network
  /// access.
  Future<Result<void>> updateWeatherNudgeEnabled({required bool enabled});

  /// Caches the latest successful weather fetch. Called only by the
  /// WorkManager cache refresher, never from `pendingNotifications()`'s
  /// own hot path.
  Future<Result<void>> updateWeatherCache({
    required double temperatureCelsius,
    required DateTime fetchedAt,
  });
```

- [ ] **Step 7: Implement them and wire `_settingsFromRow`**

In `lib/features/water/data/repositories/water_repository_impl.dart`,
add after `updateReminderSettings`'s implementation:

```dart
  @override
  Future<Result<void>> updateWeatherNudgeEnabled({
    required bool enabled,
  }) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          weatherNudgeEnabled: Value(enabled),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('update_weather_nudge_enabled', e),
      );
    }
  }

  @override
  Future<Result<void>> updateWeatherCache({
    required double temperatureCelsius,
    required DateTime fetchedAt,
  }) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          lastWeatherTemperatureCelsius: Value(temperatureCelsius),
          lastWeatherFetchedAtMillis: Value(
            fetchedAt.toUtc().millisecondsSinceEpoch,
          ),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_weather_cache', e));
    }
  }
```

Change `_settingsFromRow` from:

```dart
  WaterSettings _settingsFromRow(WaterSettingsRow row) => WaterSettings(
    quickAddAmountsMl: (jsonDecode(row.quickAddAmountsMl) as List<dynamic>)
        .cast<int>(),
    reminderEnabled: row.reminderEnabled,
    reminderIntervalMinutes: row.reminderIntervalMinutes,
    reminderWindowStart: LocalTime.parse(row.reminderWindowStart),
    reminderWindowEnd: LocalTime.parse(row.reminderWindowEnd),
    reminderWindowOverrides: {
      for (final entry
          in (jsonDecode(row.reminderWindowOverrides) as Map<String, dynamic>)
              .entries)
        int.parse(entry.key): (
          start: LocalTime.parse((entry.value as Map)['start'] as String),
          end: LocalTime.parse((entry.value as Map)['end'] as String),
        ),
    },
  );
```

to:

```dart
  WaterSettings _settingsFromRow(WaterSettingsRow row) => WaterSettings(
    quickAddAmountsMl: (jsonDecode(row.quickAddAmountsMl) as List<dynamic>)
        .cast<int>(),
    reminderEnabled: row.reminderEnabled,
    reminderIntervalMinutes: row.reminderIntervalMinutes,
    reminderWindowStart: LocalTime.parse(row.reminderWindowStart),
    reminderWindowEnd: LocalTime.parse(row.reminderWindowEnd),
    reminderWindowOverrides: {
      for (final entry
          in (jsonDecode(row.reminderWindowOverrides) as Map<String, dynamic>)
              .entries)
        int.parse(entry.key): (
          start: LocalTime.parse((entry.value as Map)['start'] as String),
          end: LocalTime.parse((entry.value as Map)['end'] as String),
        ),
    },
    weatherNudgeEnabled: row.weatherNudgeEnabled,
    lastWeatherTemperatureCelsius: row.lastWeatherTemperatureCelsius,
    lastWeatherFetchedAt: row.lastWeatherFetchedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.lastWeatherFetchedAtMillis!,
            isUtc: true,
          ),
  );
```

- [ ] **Step 8: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `water_settings.freezed.dart` and
`app_database.g.dart` (both gitignored).

- [ ] **Step 9: Run the test, confirm it passes**

Run: `flutter test test/features/water/data/repositories/water_repository_impl_test.dart | tail -10`
Expected: `+2: All tests passed!` (the pre-existing `wipeAll` test plus
the new one).

- [ ] **Step 10: Analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add lib/features/water/data/tables/water_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/water/domain/entities/water_settings.dart \
  lib/features/water/domain/repositories/water_repository.dart \
  lib/features/water/data/repositories/water_repository_impl.dart \
  test/features/water/data/repositories/water_repository_impl_test.dart
git commit -m "feat(water): add weather-nudge opt-in and cache columns"
```

---

### Task 3: Weather-only location resolver

**Files:**
- Create: `lib/features/water/data/weather_location_resolver.dart`
- Test: `test/features/water/data/weather_location_resolver_test.dart`

**Interfaces:**
- Produces: `typedef WeatherLocation = ({double latitude, double
  longitude})`, `Future<Result<WeatherLocation>> resolveWeatherLocation()`
  — consumed by Task 4's cache refresher and Task 6's explainer dialog.

- [ ] **Step 1: Write the failing test**

Create `test/features/water/data/weather_location_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

void main() {
  test(
    'resolves to a clean Failure (never a thrown exception) when no '
    'geolocator platform channel is registered, as in this test '
    'environment — mirrors `location_resolver_test.dart`\'s own '
    'precedent for the one geolocator-touching branch that can\'t be '
    'exercised without a real device/emulator',
    () async {
      final result = await resolveWeatherLocation();
      expect(result, isA<Failure<WeatherLocation>>());
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/data/weather_location_resolver_test.dart | tail -10`
Expected: FAIL — the file doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/water/data/weather_location_resolver.dart`:

```dart
import 'package:geolocator/geolocator.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';

/// A weather-lookup location — coarse coordinates only, no timezone
/// (unlike Prayer's `ResolvedLocation`, which also carries an IANA
/// timezone this feature has no use for).
typedef WeatherLocation = ({double latitude, double longitude});

/// Resolves the device's current location for weather lookups
/// (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`) — a second, independent
/// `geolocator` call site from Prayer's own `resolveLocation()`
/// (deliberately not shared: two independent opt-ins, so a user can
/// decline weather-location while keeping Prayer's, or vice versa,
/// without an awkward "which feature is asking" parameter). The sole
/// other file (besides `features/prayer/data/location_resolver.dart`)
/// touching `geolocator` directly.
Future<Result<WeatherLocation>> resolveWeatherLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const Result.failure(
        AppException.permission('location_service'),
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Result.failure(AppException.permission('location'));
    }
    final position =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
    return Result.success((
      latitude: position.latitude,
      longitude: position.longitude,
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/water/data/weather_location_resolver_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/features/water/data/weather_location_resolver.dart | tail -10`
Expected: `No issues found!`

```bash
git add lib/features/water/data/weather_location_resolver.dart \
  test/features/water/data/weather_location_resolver_test.dart
git commit -m "feat(water): add the weather-only location resolver"
```

---

### Task 4: Cache refresher and WorkManager wiring

**Files:**
- Create: `lib/features/water/data/weather_cache_refresher.dart`
- Modify: `lib/core/notifications/notification_workmanager.dart:17-30`
- Test: `test/features/water/data/weather_cache_refresher_test.dart`

**Interfaces:**
- Consumes: `fetchCurrentWeather` (Task 1), `resolveWeatherLocation`
  (Task 3), `WaterRepository.updateWeatherCache`/`watchSettings` (Task 2).
- Produces: `const weatherCacheStalenessCeiling` (`Duration`, 6 hours),
  `Future<void> refreshWeatherCacheIfStale(AppDatabase db, {...})` —
  consumed by `notification_workmanager.dart` in this same task.

- [ ] **Step 1: Write the failing test**

Create `test/features/water/data/weather_cache_refresher_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
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
      resolveLocation: () async => const Result.failure(
        AppExceptionFixture.permission,
      ),
    );

    expect(
      (await repo.watchSettings().first).lastWeatherTemperatureCelsius,
      isNull,
    );
  });
}
```

Since `AppExceptionFixture` isn't a real thing, replace that last test's
failure value with a real `AppException` constructor instead — add this
import:

```dart
import 'package:habit_tracker/core/error/app_exception.dart';
```

and change:

```dart
      resolveLocation: () async => const Result.failure(
        AppExceptionFixture.permission,
      ),
```

to:

```dart
      resolveLocation: () async =>
          const Result.failure(AppException.permission('location')),
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/data/weather_cache_refresher_test.dart | tail -10`
Expected: FAIL — `lib/features/water/data/weather_cache_refresher.dart`
doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/water/data/weather_cache_refresher.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/water/data/weather_cache_refresher_test.dart | tail -10`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Wire the WorkManager top-up**

In `lib/core/notifications/notification_workmanager.dart`, add the
import:

```dart
import 'package:habit_tracker/features/water/data/weather_cache_refresher.dart';
```

Change the callback dispatcher from:

```dart
@pragma('vm:entry-point')
void notificationWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    try {
      await planAndApplyNotifications(db: db);
      await refreshAllWidgets(db);
      await syncWearableData(db);
    } finally {
      await db.close();
    }
    return true;
  });
}
```

to:

```dart
@pragma('vm:entry-point')
void notificationWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    try {
      await planAndApplyNotifications(db: db);
      await refreshWeatherCacheIfStale(db);
      await refreshAllWidgets(db);
      await syncWearableData(db);
    } finally {
      await db.close();
    }
    return true;
  });
}
```

(No test change needed here — this whole dispatcher already has no direct
unit test in this repo, same as `planAndApplyNotifications`'s own
Android-only WorkManager entry point; `weather_cache_refresher_test.dart`
above is where the actual logic is covered.)

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/water/data/weather_cache_refresher.dart lib/core/notifications/notification_workmanager.dart | tail -10`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/water/data/weather_cache_refresher.dart \
  lib/core/notifications/notification_workmanager.dart \
  test/features/water/data/weather_cache_refresher_test.dart
git commit -m "feat(water): refresh the weather cache from the WorkManager top-up"
```

---

### Task 5: Wire the cached weather into reminder copy

**Files:**
- Create: `lib/features/water/presentation/weather_nudge_copy.dart`
- Modify: `lib/features/water/water_module.dart:124-171`
- Test: `test/features/water/water_module_test.dart`

**Interfaces:**
- Produces: `String weatherNudgeClause(double temperatureCelsius)` —
  consumed only by `WaterModule.pendingNotifications()` in this task.
- Consumes: `weatherCacheStalenessCeiling` (Task 4),
  `WaterSettings.weatherNudgeEnabled`/`lastWeatherTemperatureCelsius`/
  `lastWeatherFetchedAt` (Task 2).

- [ ] **Step 1: Write the failing test**

In `test/features/water/water_module_test.dart`, change the existing
`_settings(...)` helper from:

```dart
WaterSettings _settings({
  required bool reminderEnabled,
  List<int> quickAddAmountsMl = const [250, 500, 750],
}) => WaterSettings(
  quickAddAmountsMl: quickAddAmountsMl,
  reminderEnabled: reminderEnabled,
  reminderIntervalMinutes: 120,
  reminderWindowStart: const LocalTime(8, 0),
  reminderWindowEnd: const LocalTime(10, 0),
);
```

to:

```dart
WaterSettings _settings({
  required bool reminderEnabled,
  List<int> quickAddAmountsMl = const [250, 500, 750],
  bool weatherNudgeEnabled = false,
  double? lastWeatherTemperatureCelsius,
  DateTime? lastWeatherFetchedAt,
}) => WaterSettings(
  quickAddAmountsMl: quickAddAmountsMl,
  reminderEnabled: reminderEnabled,
  reminderIntervalMinutes: 120,
  reminderWindowStart: const LocalTime(8, 0),
  reminderWindowEnd: const LocalTime(10, 0),
  weatherNudgeEnabled: weatherNudgeEnabled,
  lastWeatherTemperatureCelsius: lastWeatherTemperatureCelsius,
  lastWeatherFetchedAt: lastWeatherFetchedAt,
);
```

Add three new tests inside `main()`, after the existing
`'pendingNotifications projects slots across multiple upcoming days...'`
test:

```dart
  test(
    'pendingNotifications appends the weather clause when enabled and the '
    'cached reading is fresh',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            weatherNudgeEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now.subtract(const Duration(hours: 1)),
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(
          notifications.first.body,
          "Keep your water goal on track. It's 34°C today.",
        );
      });
    },
  );

  test(
    'pendingNotifications omits the weather clause when the cached '
    'reading is older than the 6-hour staleness ceiling',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            weatherNudgeEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now.subtract(const Duration(hours: 7)),
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications.first.body, 'Keep your water goal on track.');
      });
    },
  );

  test(
    'pendingNotifications omits the weather clause when weatherNudgeEnabled '
    'is false, even with a fresh cached reading',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now,
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications.first.body, 'Keep your water goal on track.');
      });
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/water_module_test.dart | tail -10`
Expected: FAIL — `weatherNudgeEnabled`/`lastWeatherTemperatureCelsius`/
`lastWeatherFetchedAt` don't exist on `WaterSettings` in this branch yet
(Task 2 must land first — see the ordering note in this plan's Global
Constraints), and every generated notification body is still the plain
`'Keep your water goal on track.'` regardless of cache/enabled state.

- [ ] **Step 3: Write the pure formatter**

Create `lib/features/water/presentation/weather_nudge_copy.dart`:

```dart
/// A short weather clause appended to Water's reminder body when
/// weather-aware copy is enabled and a fresh-enough cached reading
/// exists (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`). Plain, non-localized
/// template text — matches this module's own pre-existing notification
/// title/body convention (`'Time to drink water'`/`'Keep your water goal
/// on track.'` are likewise hardcoded English, not routed through
/// `gen_l10n`; the `weatherNudgeClauseHot` ARB key documents this exact
/// English wording for translators/future use but isn't itself called
/// from `pendingNotifications()`, which has no `BuildContext`/locale to
/// resolve against — a known, already-accepted gap this one clause
/// doesn't newly introduce).
String weatherNudgeClause(double temperatureCelsius) =>
    "It's ${temperatureCelsius.round()}°C today.";
```

- [ ] **Step 4: Wire it into `WaterModule.pendingNotifications()`**

In `lib/features/water/water_module.dart`, add imports:

```dart
import 'package:habit_tracker/features/water/data/weather_cache_refresher.dart';
import 'package:habit_tracker/features/water/presentation/weather_nudge_copy.dart';
```

Change the method from:

```dart
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final settings = await _repository.watchSettings().first;
    if (!settings.reminderEnabled) return [];

    final now = clock.now();
    final notifications = <PendingNotification>[];
```

to:

```dart
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final settings = await _repository.watchSettings().first;
    if (!settings.reminderEnabled) return [];

    final now = clock.now();
    final fetchedAt = settings.lastWeatherFetchedAt;
    final weatherClause =
        settings.weatherNudgeEnabled &&
            fetchedAt != null &&
            now.difference(fetchedAt) < weatherCacheStalenessCeiling
        ? weatherNudgeClause(settings.lastWeatherTemperatureCelsius!)
        : null;
    final body = weatherClause == null
        ? 'Keep your water goal on track.'
        : 'Keep your water goal on track. $weatherClause';
    final notifications = <PendingNotification>[];
```

Change the `PendingNotification(` construction inside the loop from:

```dart
            PendingNotification(
              id:
                  'water_reminder_'
                  '${day.year}${day.month.toString().padLeft(2, '0')}'
                  '${day.day.toString().padLeft(2, '0')}_'
                  '${slot.hour}_${slot.minute}',
              scheduledAt: slot,
              title: 'Time to drink water',
              body: 'Keep your water goal on track.',
              sourceType: 'water_reminder',
              deepLinkRoute: '/water',
              quietHoursSuppressible: true,
            ),
```

to:

```dart
            PendingNotification(
              id:
                  'water_reminder_'
                  '${day.year}${day.month.toString().padLeft(2, '0')}'
                  '${day.day.toString().padLeft(2, '0')}_'
                  '${slot.hour}_${slot.minute}',
              scheduledAt: slot,
              title: 'Time to drink water',
              body: body,
              sourceType: 'water_reminder',
              deepLinkRoute: '/water',
              quietHoursSuppressible: true,
            ),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/water/water_module_test.dart | tail -10`
Expected: `+N: All tests passed!` (every pre-existing test plus the 3 new
ones).

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/water/water_module.dart lib/features/water/presentation/weather_nudge_copy.dart | tail -10`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/water/presentation/weather_nudge_copy.dart \
  lib/features/water/water_module.dart \
  test/features/water/water_module_test.dart
git commit -m "feat(water): append the cached weather clause to reminder copy"
```

---

### Task 6: Settings UI — toggle and explainer dialog

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Create: `lib/features/water/presentation/weather_nudge_explainer.dart`
- Modify: `lib/features/water/presentation/providers/water_controller.dart`
- Modify: `lib/features/water/presentation/screens/water_settings_screen.dart`
- Test: `test/features/water/presentation/water_settings_screen_test.dart`

**Interfaces:**
- Consumes: `resolveWeatherLocation` (Task 3),
  `WaterRepository.updateWeatherNudgeEnabled` (Task 2).
- Produces: nothing consumed by a later task — self-contained UI.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert right before the final closing `}`
(after the existing last key, whatever it is at the time this task
lands — this plan and the Ramadan-mode/Sunrise-countdown plans all use
the same "append before the final `}`" convention specifically so
independent plans don't collide on the same mid-file anchor):

```json
  "weatherNudgeSettingsTitle": "Weather-aware reminders",
  "@weatherNudgeSettingsTitle": {
    "description": "Toggle title for weather-derived reminder copy."
  },
  "weatherNudgeSettingsExplainerBody": "Add today's temperature to water reminders. Requires location access and an internet connection; you can turn this off at any time.",
  "@weatherNudgeSettingsExplainerBody": {
    "description": "Explainer dialog body shown before requesting location for weather-aware reminders."
  },
  "weatherNudgeClauseHot": "It's {temp}°C today.",
  "@weatherNudgeClauseHot": {
    "description": "Documents the exact English wording `weatherNudgeClause` (Dart, non-localized) produces — for translators/future use, not itself called from that pure formatter.",
    "placeholders": {
      "temp": {"type": "int"}
    }
  },
  "weatherNudgePermissionDeniedSnackbar": "Location access is needed for weather-aware reminders",
  "@weatherNudgePermissionDeniedSnackbar": {
    "description": "Snackbar shown when the user declines location access after opting into weather-aware reminders."
  }
}
```

In `lib/core/l10n/app_bn.arb`, apply the same "append before the final
`}`" edit:

```json
  "weatherNudgeSettingsTitle": "আবহাওয়া-সচেতন রিমাইন্ডার",
  "weatherNudgeSettingsExplainerBody": "পানির রিমাইন্ডারে আজকের তাপমাত্রা যোগ করুন। লোকেশন অ্যাক্সেস এবং ইন্টারনেট সংযোগ প্রয়োজন; আপনি যেকোনো সময় এটি বন্ধ করতে পারেন।",
  "weatherNudgeClauseHot": "আজ {temp}°সে।",
  "weatherNudgePermissionDeniedSnackbar": "আবহাওয়া-সচেতন রিমাইন্ডারের জন্য লোকেশন অ্যাক্সেস প্রয়োজন"
}
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing widget test**

Add to `test/features/water/presentation/water_settings_screen_test.dart`,
new imports:

```dart
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';
```

Add three new `testWidgets` inside `main()`, after the existing
`'tapping a preset updates the goal field...'` test:

```dart
  testWidgets(
    'toggling weather-aware reminders on, with location granted, persists '
    'the setting',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WaterSettingsScreen(
              resolveWeatherLocationOverride: () async => const Result.success(
                (latitude: 23.8103, longitude: 90.4125),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weather-aware reminders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      final repo = WaterRepositoryImpl(db);
      expect((await repo.watchSettings().first).weatherNudgeEnabled, isTrue);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'toggling weather-aware reminders on, with location denied, shows a '
    'snackbar and does not persist the setting',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WaterSettingsScreen(
              resolveWeatherLocationOverride: () async =>
                  const Result.failure(AppException.permission('location')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weather-aware reminders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(
        find.text('Location access is needed for weather-aware reminders'),
        findsOneWidget,
      );
      final repo = WaterRepositoryImpl(db);
      expect((await repo.watchSettings().first).weatherNudgeEnabled, isFalse);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'toggling weather-aware reminders off never shows the explainer',
    (tester) async {
      final repo = WaterRepositoryImpl(db);
      await repo.updateWeatherNudgeEnabled(enabled: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WaterSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weather-aware reminders'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect((await repo.watchSettings().first).weatherNudgeEnabled, isFalse);

      await disposeTree(tester);
    },
  );
```

Add the two missing imports this needs at the top of the file:

```dart
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
```

and add a `disposeTree` helper (matching this repo's convention) right
after `setUp`/`tearDown`, if the file doesn't already have one:

```dart
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: FAIL to compile — `WaterSettingsScreen` doesn't accept
`resolveWeatherLocationOverride` yet, and `'Weather-aware reminders'`
isn't on screen.

- [ ] **Step 5: Write the explainer dialog**

Create `lib/features/water/presentation/weather_nudge_explainer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

/// Shows a friendly explanation before requesting location access for
/// weather-aware reminder copy, then resolves that location if the user
/// agrees (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`) — same
/// explainer-then-request pattern as `showNotificationPermissionExplainer`.
/// Returns whether both the dialog was accepted *and* location resolved
/// successfully; shows a snackbar and returns `false` if location fails.
/// [resolveLocation] overrides [resolveWeatherLocation] — test-only seam.
Future<bool> showWeatherNudgeExplainer(
  BuildContext context, {
  Future<Result<WeatherLocation>> Function()? resolveLocation,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.weatherNudgeSettingsTitle),
      content: Text(l10n.weatherNudgeSettingsExplainerBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.notificationPermissionNotNowButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.notificationPermissionAllowButton),
        ),
      ],
    ),
  );
  if (proceed != true) return false;

  final locationResult = await (resolveLocation ?? resolveWeatherLocation)();
  if (locationResult case Failure()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.weatherNudgePermissionDeniedSnackbar)),
      );
    }
    return false;
  }
  return true;
}
```

Add the missing `Result`/`Failure` import at the top:

```dart
import 'package:habit_tracker/core/error/result.dart';
```

- [ ] **Step 6: Wire the controller method**

In `lib/features/water/presentation/providers/water_controller.dart`, add
after `updateReminderSettings`:

```dart
  /// Enables or disables the weather-derived reminder-copy clause
  /// (`docs/superpowers/specs/02-delightful/
  /// 07-weather-aware-water-nudge-copy-design.md`).
  Future<void> updateWeatherNudgeEnabled({required bool enabled}) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateWeatherNudgeEnabled(enabled: enabled);
    if (result case Failure(:final error)) logException(error);
  }
```

- [ ] **Step 7: Wire the screen**

In `lib/features/water/presentation/screens/water_settings_screen.dart`,
add imports:

```dart
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';
import 'package:habit_tracker/features/water/presentation/weather_nudge_explainer.dart';
```

Change the class declaration and constructor from:

```dart
class WaterSettingsScreen extends ConsumerWidget {
  /// Creates the water settings screen.
  const WaterSettingsScreen({super.key});
```

to:

```dart
class WaterSettingsScreen extends ConsumerWidget {
  /// Creates the water settings screen. [resolveWeatherLocationOverride]
  /// overrides `resolveWeatherLocation` — test-only seam, since
  /// `geolocator`'s platform channel isn't available under `flutter test`.
  const WaterSettingsScreen({super.key, this.resolveWeatherLocationOverride});

  /// Test seam for `resolveWeatherLocation`.
  final Future<Result<WeatherLocation>> Function()?
  resolveWeatherLocationOverride;
```

Add the `Result`/`WeatherLocation` import needed by that field's type:

```dart
import 'package:habit_tracker/core/error/result.dart';
```

Change the closing of the `body:`'s `children:` list from:

```dart
            _WeekdayOverridesSection(
              overrides: settings.reminderWindowOverrides,
              defaultStart: settings.reminderWindowStart,
              defaultEnd: settings.reminderWindowEnd,
              intervalMinutes: settings.reminderIntervalMinutes,
              onChanged: (overrides) => controller.updateReminderSettings(
                enabled: settings.reminderEnabled,
                intervalMinutes: settings.reminderIntervalMinutes,
                windowStart: settings.reminderWindowStart,
                windowEnd: settings.reminderWindowEnd,
                windowOverrides: overrides,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

to:

```dart
            _WeekdayOverridesSection(
              overrides: settings.reminderWindowOverrides,
              defaultStart: settings.reminderWindowStart,
              defaultEnd: settings.reminderWindowEnd,
              intervalMinutes: settings.reminderIntervalMinutes,
              onChanged: (overrides) => controller.updateReminderSettings(
                enabled: settings.reminderEnabled,
                intervalMinutes: settings.reminderIntervalMinutes,
                windowStart: settings.reminderWindowStart,
                windowEnd: settings.reminderWindowEnd,
                windowOverrides: overrides,
              ),
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.weatherNudgeSettingsTitle),
            subtitle: Text(l10n.weatherNudgeSettingsExplainerBody),
            value: settings.weatherNudgeEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final granted = await showWeatherNudgeExplainer(
                  context,
                  resolveLocation: resolveWeatherLocationOverride,
                );
                if (!granted) return;
              }
              unawaited(
                controller.updateWeatherNudgeEnabled(enabled: enabled),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: `+N: All tests passed!` (every pre-existing test plus the 3 new
ones).

- [ ] **Step 9: Analyze and format**

Run: `flutter analyze | tail -10`
Run: `dart format lib/features/water/presentation/weather_nudge_explainer.dart lib/features/water/presentation/providers/water_controller.dart lib/features/water/presentation/screens/water_settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/water/presentation/weather_nudge_explainer.dart \
  lib/features/water/presentation/providers/water_controller.dart \
  lib/features/water/presentation/screens/water_settings_screen.dart \
  test/features/water/presentation/water_settings_screen_test.dart
git commit -m "feat(water): add the weather-aware reminders settings toggle"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.
