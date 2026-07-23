# Weather-Aware Water Nudge Copy

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

`WaterModule.pendingNotifications()` (`lib/features/water/water_module.dart
:124-171`) builds every reminder's `title`/`body` from two hardcoded
string literals — `'Time to drink water'` / `'Keep your water goal on
track.'` (lines 159-160) — identical for every slot, every day, regardless
of conditions. There is no situational content anywhere in the module.

This is also, concretely, the **app's first feature requiring real network
access**. Confirmed by grep: `pubspec.yaml` (lines 10-65) has no `http`,
`dio`, or any HTTP client dependency at all — every existing module
(`Water`, `Medicine`, `Prayer`) is fully offline, and `Prayer`'s own
"location" use (`resolveLocation()`, `lib/features/prayer/data
/location_resolver.dart`) only touches `geolocator`/`flutter_timezone`
locally, never a network call. Whatever is built here is a genuine first,
not an extension of an existing pattern, and needs to be scoped as
tightly and defensively as that implies.

**Location permission already exists and should be reused, not
duplicated.** `resolveLocation()` (`location_resolver.dart:14-67`) is
the one file in the codebase that owns `Geolocator` calls directly —
service-enabled check, `checkPermission`/`requestPermission`, cached-fix-
first with a 10s timeout on `getCurrentPosition` (lines 51-58, added
specifically to avoid hanging indefinitely). It takes `PrayerSettings`
(for `LocationMode.manual` vs `.auto`) and returns
`Result<ResolvedLocation>` (`(latitude, longitude, ianaTimezone)`,
`prayer/domain/entities/resolved_location.dart`). This spec's own opening
note ("a user might want Prayer's location but not weather network calls,
or vice versa") is correct and needs its own opt-in state — see Design.

**Reminder generation timing constraint.** `pendingNotifications()` runs
inside `planAndApplyNotifications()`
(`lib/core/notifications/notification_planner.dart:104-147`), itself
triggered by app resume, the post-action conveyor belt, and Android's
8-hour WorkManager top-up (`notification_workmanager.dart:36-41`, `Duration(hours: 8)`).
`planNotifications()`'s pure window/cap/diff core
(`notification_planner.dart:59-97`) schedules up to 3 days
(`windowDays = 3` default) of notifications ahead of `now` in one pass —
so "weather at generation time" for a slot 60 hours out is unavoidably a
stale/forecast reading, never a live one. This is expected, not a bug to
engineer around.

## Design

### 1. New dependency: a weather HTTP client

Add exactly one new dependency: `http: ^1.2.0` (the Dart-team-maintained
minimal HTTP client — no heavier `dio`-style client is needed for one
GET request) plus a weather provider. Recommendation: **Open-Meteo**
(`api.open-meteo.com`) — no API key, no account, free for non-commercial
use at reasonable volume, matches the app's no-account/no-subscription
identity better than a keyed provider (OpenWeatherMap etc., which needs a
secret shipped in the client or a backend proxy neither of which this app
has). One new file, the sole file touching the weather API or `http`
directly (same "one file owns the plugin" precedent as
`notification_service.dart`/`location_resolver.dart`):

`lib/features/water/data/weather_client.dart`
```dart
/// Current-conditions snapshot used for reminder-copy enrichment only —
/// never displayed as a dedicated weather feature (out of scope, below).
typedef WeatherSnapshot = ({double temperatureCelsius, DateTime fetchedAt});

/// Fetches current temperature for [latitude]/[longitude] from Open-Meteo,
/// with a short timeout — never allowed to block notification planning.
/// Returns `Failure` on any error (timeout, no connectivity, bad response);
/// callers must treat that as "no weather copy this time," not retry-loop.
Future<Result<WeatherSnapshot>> fetchCurrentWeather({
  required double latitude,
  required double longitude,
  Duration timeout = const Duration(seconds: 5),
});
```
5-second timeout, `Result<T>` return (matching the existing
`AppException`/`Result<T>` taxonomy, `core/error/result.dart`) — a
failure here is silently swallowed by the caller, never surfaced as an
error to the user or logged above `logger.d`.

### 2. Independent opt-in — new `water_settings` column, not shared with Prayer's location

Per the original draft's own correct instinct: this needs its own opt-in,
not Prayer's `LocationMode`. Add to `WaterSettingsTable`
(`lib/features/water/data/tables/water_settings_table.dart`):

```dart
/// Opt-in: attach a weather-derived clause to reminder copy (FR-new).
/// Default false — never silently turns on network/location access.
BoolColumn get weatherNudgeEnabled =>
    boolean().withDefault(const Constant(false))();
```
`WaterSettings` (`lib/features/water/domain/entities/water_settings.dart:12-20`)
gets a matching `@Default(false) bool weatherNudgeEnabled` field.
`schemaVersion` bumps (to whatever it is after Ramadan mode's own bump,
or independently if shipped alone — `AppDatabase.migration.onUpgrade`,
`app_database.dart:59-110`, gets one more `if (from < N)` block adding
this single column).

**Location for weather** reuses `geolocator` (already a dependency,
`pubspec.yaml:28`) through a second, independent call site — not through
`resolveLocation()` itself, since that function is parametrized on
`PrayerSettings` and conflating the two opt-ins is exactly the mistake
flagged above. A thin sibling, `lib/features/water/data
/weather_location_resolver.dart`, duplicates only the
permission-check-then-`getLastKnownPosition`-then-`getCurrentPosition`
shape (~15 lines) rather than being parametrized to serve both features —
two independent opt-ins with two independent permission prompts is the
correct product behavior here (a user can decline weather-location while
keeping Prayer's), so sharing the function would need an awkward
"which feature is asking" parameter for no real code savings.

### 3. Caching / rate-limiting — new `water_settings` columns for the cache

Never fetch per-notification-generation-call; cache with a floor on
staleness:

```dart
/// Last successful fetch, cached alongside the reading itself so
/// `pendingNotifications()` never needs a network round-trip on its own
/// hot path — populated by a background refresh, read-only here.
RealColumn get lastWeatherTemperatureCelsius => real().nullable()();
IntColumn get lastWeatherFetchedAtMillis => integer().nullable()();
```
Refresh cadence: piggyback on the **existing** 8-hour WorkManager top-up
(`notification_workmanager.dart`'s `notificationWorkmanagerCallbackDispatcher`,
lines 17-30) — add one call there (`refreshWeatherCacheIfStale(db)`,
guarded by `weatherNudgeEnabled`) rather than inventing a second periodic
job. No fetch happens on iOS's app-resume-only path more than once per
resume (an in-memory/DB-timestamp guard, not a new timer). Staleness
ceiling for using a cached reading in copy: **6 hours** — past that,
`pendingNotifications()` falls back to the plain templated body rather
than asserting a now-implausible temperature (directly answers the
original draft's own open question). This is a constant, not a
user-facing setting — same "not configurable" precedent as the undo
snackbar's 4-second window.

### 4. Wiring into reminder copy

`WaterModule.pendingNotifications()` (`water_module.dart:151-165`) reads
the cached `lastWeatherTemperatureCelsius`/`lastWeatherFetchedAtMillis`
off `WaterSettings` (already fetched once per call at line 126) instead
of making any call itself:

```dart
final weatherClause = settings.weatherNudgeEnabled &&
        settings.lastWeatherFetchedAt != null &&
        now.difference(settings.lastWeatherFetchedAt!) < const Duration(hours: 6)
    ? weatherNudgeClause(settings.lastWeatherTemperatureCelsius!) // "It's 34°C today."
    : null;
notifications.add(PendingNotification(
  ...
  body: weatherClause == null
      ? 'Keep your water goal on track.'
      : 'Keep your water goal on track. $weatherClause',
  ...
));
```
`weatherNudgeClause(double celsius)` is a small pure formatter (new file
`lib/features/water/presentation/weather_nudge_copy.dart`, mirroring
`water_amount_formatter.dart`'s existing pattern) producing the l10n
string below with the rounded integer Celsius value — no Fahrenheit
conversion needed since `WaterUnit` (ml/flOz) governs volume display
only, temperature display is a separate, simpler concern the app doesn't
currently have a unit preference for (default to Celsius; out of scope
to add a temperature-unit setting for this).

### New l10n keys (`app_en.arb`/`app_bn.arb`)

- `weatherNudgeSettingsTitle` — "Weather-aware reminders"
- `weatherNudgeSettingsExplainerBody` — "Add today's temperature to water reminders. Requires location access and an internet connection; you can turn this off at any time." (same explainer-dialog pattern as `notificationPermissionExplainerBody`, `notification_permission_explainer_screen.dart:16`)
- `weatherNudgeClauseHot` — "It's {temp}°C today." (ICU `{temp}` placeholder — plain, no editorializing copy variants in v1; see Out of scope)
- `weatherNudgePermissionDeniedSnackbar` — "Location access is needed for weather-aware reminders"

## Out of scope

- No general in-app weather display/forecast screen — reminder-copy enrichment only.
- No weather-based reminder *timing/cadence* changes (hotter days → more frequent reminders) — copy only, `reminderIntervalMinutes`/window logic untouched.
- No mandatory location or network permission — decliners get byte-identical existing behavior (the `weatherClause == null` branch above, already the default).
- No weather-based adjustments for Prayer or Medicine.
- No temperature-unit (°C/°F) user setting — Celsius only in v1, consistent with the app's Bangladesh-first default audience.
- No copy-variant system (different phrasing for hot/cold/rainy) — one template string in v1; the atlas's own example ("it's 34°C today") is exactly what ships.
- No retry/backoff logic on fetch failure — a single attempt per WorkManager tick, silently skipped on failure, picked up again next tick per the existing 8-hour cadence.
- No dedicated reliability-stub screen (unlike notifications') — this is flavor text on an already-firing reminder, not a mechanism whose delivery reliability needs its own documented fallback story.

## Global Constraints

- **New dependencies:** `http: ^1.2.0` (HTTP client). No weather-SDK package — a raw GET against Open-Meteo's public REST API is simpler than any wrapper package for one endpoint.
- **First network-access exception to offline-first identity** — must ship behind an explicit, default-off, clearly-explained opt-in (the explainer dialog above), never silently enabled.
- **Migration:** one more `if (from < N)` block in `AppDatabase.migration.onUpgrade` (`app_database.dart:59-110`) adding `weatherNudgeEnabled` (bool, default false), `lastWeatherTemperatureCelsius` (nullable real), `lastWeatherFetchedAtMillis` (nullable int) to `WaterSettingsTable`.
- **No new call site inside `pendingNotifications()`'s own execution** — it only *reads* the cache; the only new network call site is the WorkManager top-up (Android-only, matching the existing platform asymmetry already documented for that mechanism at `notification_workmanager.dart:12-16`). On iOS, where WorkManager isn't registered, the cache only refreshes on app-resume — meaning weather copy is more likely to be stale/absent on iOS than Android; that's an accepted, documented gap, not a new mechanism to build.
- **Never blocks a reminder on a network call** — `pendingNotifications()` itself performs zero I/O beyond existing DB reads; a network failure anywhere degrades silently to the existing plain copy.
- New l10n keys listed above, both `app_en.arb`/`app_bn.arb`.
- New settings UI entry (a toggle + the explainer dialog) inside `water_settings_screen.dart`, following the existing `showNotificationPermissionExplainer`-style dialog-then-request pattern.
