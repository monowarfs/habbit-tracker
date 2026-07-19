# Prayer Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the complete Prayer module — domain, data, presentation, and
notifications — matching FR-P-01..10, D-06/07/08/09/13/14, and the
`prayer_settings`/`prayer_records`/`prayer_qadha_counters` schema,
registered as a full `HabitModule`.

**Architecture:** Clean Architecture slice mirroring `lib/features/medicine/`
(itself mirroring `lib/features/water/`), per `docs/superpowers/specs/
2026-07-19-prayer-module-design.md`. A pure `calculatePrayerTimes` wrapper
over `adhan_dart` (golden-tested against a published reference), a pure
`effectivePrayerStatus` derivation (Medicine's `effectiveDoseStatus`
precedent), a one-shot `sweepMissedPrayers` crossing-detector (Medicine's
low-stock-crossing precedent, applied to a status transition instead of a
stock threshold), and a much simpler day-based `planPrayerMaterialization`
(no repeat-rule engine — one settings row, not N schedules). Records
materialized into a 30-day rolling window by the same two triggers
`core/notifications` already uses (app-resume, WorkManager top-up) via
`PrayerModule.pendingNotifications()` itself — no new call sites.

**Tech Stack:** Flutter, Riverpod (codegen), Drift, Freezed, `clock`,
`timezone` (already present), `fl_chart` (existing `PeriodBarChart`),
`mocktail` (existing dev dep) — plus three new dependencies this run:
`adhan_dart`, `geolocator`, `flutter_timezone`.

## Global Constraints

- Status model is exactly `upcoming | due | prayed | missed` — **no
  `prayed-late`** (resolved scope decision, see design spec's "Scope
  decisions" section).
- No Hijri date this run — Gregorian only on the checklist screen.
- Jumu'ah is a **display label only**, applied at render time when
  `observesJumuah` is on and the day is Friday — the underlying
  `prayerName` is always `dhuhr`, sharing Dhuhr's schedule and Qadha
  bucket (D-07/FR-P-03). There is no `jumuah`-valued `PrayerRecord` row
  anywhere (see this plan's refinements section).
- Every domain unit reasoning about "now"/"today" takes time as an
  injected parameter or reads `clock.now()` — never `DateTime.now()`
  directly (`docs/strategies/testing.md`'s mandatory rule).
- Every repository mutation returns `Result<T>` (`core/error/result.dart`)
  and wraps its body in `try`/`on Object catch (e) => Result.failure(
  AppException.storage(...))`, matching `MedicineRepositoryImpl` exactly.
- Soft-delete: `prayer_records` has `deleted_at`; every read filters
  `deletedAt.isNull()`. `prayer_settings`/`prayer_qadha_counters` are
  singleton/fixed-row tables with no `deleted_at`, matching
  `database-design.md`'s committed schema exactly.
- All ids via `generateId()` (`core/utils/uuid.dart`, UUID v7). All stored
  instants are UTC epoch millis; `prayer_date`/`isha_day_rollover_time`
  are local strings (`"YYYY-MM-DD"`/`"HH:mm"`) per D-14.
- Lint: `public_member_api_docs` is enforced — every public class/member
  needs a `///` doc comment.
- Run `dart run build_runner build --delete-conflicting-outputs` after
  creating/editing any `@freezed` or `@riverpod` file, before running
  tests that import its generated `.g.dart`/`.freezed.dart`.
- Commands: `flutter test <file>`, `flutter analyze`,
  `dart format --output=none --set-exit-if-changed .`.

## Four implementation-level refinements over the design spec (all stay inside its intent)

1. **`PrayerName` has exactly five values (`fajr`/`dhuhr`/`asr`/`maghrib`/
   `isha`), never `jumuah`**, even though the design spec's own entity
   sketch lists `PrayerName: fajr|dhuhr|asr|maghrib|isha|jumuah`. The
   spec's own "Materialization" section is explicit that "Friday's Dhuhr
   slot is still `prayerName: dhuhr`... `jumuah` is a display label
   applied at render time... not a separate materialized row" — so a
   `jumuah` enum value would be structurally unreachable in every
   `PrayerRecord`/`PrayerQadhaCounter` this module ever creates. Carrying
   a dead enum value into `switch` statements everywhere (a manual-
   entity-sketch/materialization-section mismatch in the spec itself)
   would be a straight `ponytail`-flagged violation, not fidelity. A
   separate pure predicate, `isJumuahDisplay()` (Task 5), supplies the
   Friday relabeling at render time instead. This also means
   `CalculatePrayerStreakUseCase`'s required-prayer-count is a constant 5
   regardless of `observesJumuah` (Task 7) — Jumu'ah relabels an existing
   required prayer, it never adds a sixth.
2. **`sweepMissedPrayers`/`materializeRecords` take a `ResolvedLocation`
   parameter**, not just `DateTime now` as the design spec's signature
   sketch shows. The repository has no way to resolve GPS location itself
   (a platform call that doesn't belong inside a Drift-backed repository,
   and the design spec's own `planPrayerMaterialization` already takes
   `location` as a parameter rather than resolving it internally) — so
   `PrayerModule.pendingNotifications()` resolves location once via
   `resolveLocation()` (Task 14) and passes it to both calls, extending
   the same "location is supplied, not resolved here" reasoning the
   spec's pure planner already established.
3. **`updateSettings` soft-deletes future `upcoming` records when a
   location/method-affecting field changes**, then the controller
   immediately re-materializes. The design spec's task list doesn't wire
   up FR-P-01's explicit requirement ("changing it recalculates all
   future prayer times immediately") — without this, a pure gap-filler
   materializer (by design, matching Medicine's `planDoseMaterialization`
   precedent) would never revisit an already-materialized future slot, so
   stale prayer times would linger until the 30-day window naturally
   rolled past them. This mirrors Medicine's own FR-M-09 handling
   (`updateSchedule` deletes future `upcoming` doses so the next
   materialization pass regenerates them) applied to Prayer's settings
   instead of a schedule.
4. **`prayer_settings` gains three columns beyond `database-design.md`'s
   committed list**: `notifications_enabled` (default true),
   `pre_reminder_enabled` (default false), `pre_reminder_offset_minutes`
   (default 10) — FR-P-08's "optional pre-prayer reminder... adjustable
   offset" has nowhere to live in that doc's original column list. Same
   "settings gained a reminder column mid-run" precedent already
   documented for `water_settings.reminder_enabled` et al.

---

### Task 1: Add dependencies and the bundled city-list asset slot

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `adhan_dart`, `geolocator`, `flutter_timezone` available to
  every later task; the `assets/data/` asset path registered.

- [ ] **Step 1: Add the three dependencies**

In `pubspec.yaml`, insert alphabetically into the `dependencies:` block
(the file is already roughly alphabetical):

```yaml
dependencies:
  adhan_dart: ^2.0.1
  clock: ^1.1.2
  cupertino_icons: ^1.0.8
  drift: ^2.34.2
  fl_chart: ^1.2.0
  flutter:
    sdk: flutter
  flutter_local_notifications: ^22.0.1
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^3.3.2
  flutter_timezone: ^5.1.0
  freezed_annotation: ^3.1.0
  geolocator: ^14.0.3
  go_router: ^17.3.0
  intl: ^0.20.2
  logger: ^2.7.0
  meta: ^1.18.0
  path: ^1.9.1
  path_provider: ^2.1.6
  riverpod_annotation: ^4.0.3
  sqlite3: ^3.4.0
  timezone: ^0.11.1
  uuid: ^4.6.0
  # Android-only periodic top-up of the notification scheduling window
  # (`strategies/notifications.md`) — not used on iOS, see
  # core/notifications/notification_workmanager.dart.
  workmanager: ^0.9.0+3
```

- [ ] **Step 2: Register the bundled city-list asset**

Still in `pubspec.yaml`, under the `flutter:` block:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/data/prayer_cities.json
```

(The actual JSON file is created in Task 14, once `PrayerCity` — Task
2 — exists to shape its contents; declaring the path now means Task 14
only has to add the file, not touch `pubspec.yaml` again.)

- [ ] **Step 3: Install dependencies**

Run: `flutter pub get`
Expected: resolves cleanly, `pubspec.lock` updated with `adhan_dart`,
`geolocator`, `flutter_timezone` and their transitive deps.

- [ ] **Step 4: Add Android/iOS location permission declarations**

`geolocator` requires these even for a one-shot fix. In
`android/app/src/main/AndroidManifest.xml`, add alongside the existing
`<uses-permission>` lines (before `<application>`):

```xml
    <!-- One-shot GPS fix for prayer-time calculation location (FR-P-06,
         D-09) — `features/prayer/data/location_resolver.dart`. -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

In `ios/Runner/Info.plist`, add inside the root `<dict>` (alongside the
existing keys):

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Used to calculate accurate prayer times for your current location.</string>
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore(prayer): add adhan_dart/geolocator/flutter_timezone dependencies"
```

---

### Task 2: Domain entities

**Files:**
- Create: `lib/features/prayer/domain/entities/prayer_settings.dart`
- Create: `lib/features/prayer/domain/entities/prayer_record.dart`
- Create: `lib/features/prayer/domain/entities/prayer_qadha_counter.dart`
- Create: `lib/features/prayer/domain/entities/resolved_location.dart`
- Create: `lib/features/prayer/domain/entities/prayer_city.dart`

**Interfaces:**
- Produces: `CalculationMethod`, `AsrMethod`, `LocationMode`,
  `PrayerSettings`, `PrayerName`, `PrayerStatus`, `PrayerRecord`,
  `PrayerQadhaCounter`, `ResolvedLocation`, `PrayerCity` — used by every
  later task.

- [ ] **Step 1: Write `prayer_settings.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'prayer_settings.freezed.dart';

/// A standard prayer-time calculation method (FR-P-01, D-06) — exactly
/// the ten `adhan_dart` presets this run supports, matching
/// `technical/database-design.md`'s `prayer_settings.calculation_method`
/// enum.
enum CalculationMethod {
  mwl,
  isna,
  egyptian,
  ummAlQura,
  karachi,
  tehran,
  dubai,
  kuwait,
  qatar,
  singapore,
}

/// The Asr juristic method (FR-P-02, D-06).
enum AsrMethod {
  /// Shafi'i/Maliki/Hanbali.
  standard,

  /// Hanafi.
  hanafi,
}

/// Whether prayer times are computed from a live GPS fix or a fixed
/// location (FR-P-06, D-09).
enum LocationMode {
  /// One-shot GPS fix, re-resolved on app foreground/background refresh.
  auto,

  /// A fixed city/lat-long the user entered in Settings.
  manual,
}

/// The Prayer module's singleton settings row (`technical/database-
/// design.md`'s `prayer_settings`, same pattern as `app_settings`).
@freezed
sealed class PrayerSettings with _$PrayerSettings {
  /// Creates prayer settings.
  const factory PrayerSettings({
    required String id,
    required CalculationMethod calculationMethod,
    required AsrMethod asrMethod,
    @Default(false) bool observesJumuah,
    required LocationMode locationMode,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    @Default(LocalTime(0, 0)) LocalTime ishaDayRolloverTime,

    /// Whether the on-time prayer notification fires at all (FR-P-08) —
    /// an addition beyond `database-design.md`'s original column list
    /// (this plan's refinements section, #4).
    @Default(true) bool notificationsEnabled,

    /// Whether the optional pre-prayer reminder fires (FR-P-08).
    @Default(false) bool preReminderEnabled,

    /// Minutes before `scheduledFor` the pre-prayer reminder fires.
    @Default(10) int preReminderOffsetMinutes,
  }) = _PrayerSettings;
}
```

- [ ] **Step 2: Write `prayer_record.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'prayer_record.freezed.dart';

/// One of the five daily obligatory prayers. Exactly five values —
/// Jumu'ah is a Friday-only *display label* applied over `dhuhr`
/// (D-07/FR-P-03), never its own materialized value (this plan's
/// refinements section, #1).
enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

/// A prayer record's status. `due` is never persisted — computed at read
/// time (`effective_prayer_status.dart`). `missed` IS persisted, unlike
/// Medicine's transient `missed`, because crossing into it has a
/// one-shot Qadha side effect (FR-P-05).
enum PrayerStatus { upcoming, due, prayed, missed }

/// A materialized prayer record (D-13), one per prayer per local day,
/// rolling 30-day window (`technical/database-design.md`).
@freezed
sealed class PrayerRecord with _$PrayerRecord {
  /// Creates a prayer record.
  const factory PrayerRecord({
    required String id,
    required LocalDate prayerDate,
    required PrayerName prayerName,
    required DateTime scheduledFor,
    required PrayerStatus storedStatus,
    DateTime? statusChangedAt,
  }) = _PrayerRecord;
}
```

- [ ] **Step 3: Write `prayer_qadha_counter.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

part 'prayer_qadha_counter.freezed.dart';

/// One prayer's running Qadha (missed-prayer make-up) balance (D-08).
/// Exactly five rows exist, one per [PrayerName] — Jumu'ah shares Dhuhr's
/// bucket (D-07/FR-P-03), so there is no sixth row.
@freezed
sealed class PrayerQadhaCounter with _$PrayerQadhaCounter {
  /// Creates a Qadha counter.
  const factory PrayerQadhaCounter({
    required String id,
    required PrayerName prayerName,
    required int count,
    required DateTime updatedAt,
  }) = _PrayerQadhaCounter;
}
```

- [ ] **Step 4: Write `resolved_location.dart`**

```dart
/// A prayer-time calculation location, resolved from either a one-shot
/// GPS fix or the user's manual entry (FR-P-06/D-09) — the shared input
/// both `calculatePrayerTimes` and `planPrayerMaterialization` take, so
/// neither needs to know *how* it was resolved.
typedef ResolvedLocation = ({
  double latitude,
  double longitude,
  String ianaTimezone,
});
```

- [ ] **Step 5: Write `prayer_city.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'prayer_city.freezed.dart';

/// One entry in the bundled `assets/data/prayer_cities.json` picker list.
/// [nameKey] is resolved through `AppLocalizations` at render time (not a
/// raw display string), so the same bundled dataset serves both locales.
@freezed
sealed class PrayerCity with _$PrayerCity {
  /// Creates a city entry.
  const factory PrayerCity({
    required String nameKey,
    required double latitude,
    required double longitude,
    required String ianaTimezone,
  }) = _PrayerCity;
}
```

- [ ] **Step 6: Generate freezed code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 4 new `*.freezed.dart` files generated (settings/record/
qadha-counter/city — `resolved_location.dart` is a plain typedef, no
codegen needed), no errors.

Run: `flutter analyze lib/features/prayer/domain/entities/`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/prayer/domain/entities/
git commit -m "feat(prayer): add domain entities"
```

---

### Task 3: `calculatePrayerTimes` wrapper + golden tests

**Files:**
- Create: `lib/features/prayer/domain/usecases/calculate_prayer_times.dart`
- Test: `test/features/prayer/domain/calculate_prayer_times_golden_test.dart`

**Interfaces:**
- Consumes: `CalculationMethod`, `AsrMethod` (Task 2), `LocalDate`
  (`core/utils/local_date.dart`), `ensureTimeZonesInitialized`
  (`core/utils/local_day.dart`).
- Produces: `typedef PrayerTimes = ({DateTime fajr, DateTime dhuhr,
  DateTime asr, DateTime maghrib, DateTime isha})`, `PrayerTimes
  calculatePrayerTimes({required LocalDate date, required double
  latitude, required double longitude, required String ianaTimezone,
  required CalculationMethod method, required AsrMethod asrMethod})` —
  used by Task 6 (materialization planner) and every screen showing a
  prayer time.

**Golden reference values** are sourced from the Al Adhan API
(`https://aladhan.com/prayer-times-api`), which computes prayer times
using the same family of solar-angle astronomical formulas (derived from
PrayTimes.org) that `adhan`/`adhan_dart` implement — the two are expected
to agree within a small rounding tolerance, not bit-for-bit, hence this
run's ±2 minute tolerance. Fetched 2026-07-19 via
`GET https://api.aladhan.com/v1/timings/15-01-2026?latitude=<lat>&longitude=<long>&method=<n>&timezonestring=<tz>`,
`school=0` (Standard Asr, the API default, unspecified):

| City | Date | `method` id | Method name | Fajr | Dhuhr | Asr | Maghrib | Isha |
|---|---|---|---|---|---|---|---|---|
| Dhaka (23.8103, 90.4125, Asia/Dhaka) | 2026-01-15 | 1 | University of Islamic Sciences, Karachi | 05:23 | 12:08 | 15:11 | 17:33 | 18:52 |
| Kuala Lumpur (3.1390, 101.6869, Asia/Kuala_Lumpur) | 2026-01-15 | 11 | Majlis Ugama Islam Singapura, Singapore | 06:01 | 13:23 | 16:46 | 19:21 | 20:35 |
| London (51.5074, -0.1278, Europe/London) | 2026-01-15 | 3 | Muslim World League | 05:59 | 12:10 | 14:00 | 16:21 | 18:15 |

(Times above are local to each city's own timezone, as returned by the
API's `timezonestring` parameter.)

- [ ] **Step 1: Write the failing golden tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(ensureTimeZonesInitialized);

  DateTime localTime(String ianaTimezone, LocalDate date, String hhMm) {
    final location = tz.getLocation(ianaTimezone);
    final parts = hhMm.split(':');
    final local = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return local.toUtc();
  }

  void expectWithinTolerance(
    DateTime actual,
    DateTime expected, {
    Duration tolerance = const Duration(minutes: 2),
  }) {
    final diff = actual.difference(expected).abs();
    expect(
      diff <= tolerance,
      isTrue,
      reason:
          'expected $expected, got $actual, '
          'diff ${diff.inSeconds}s exceeds ${tolerance.inSeconds}s tolerance',
    );
  }

  test(
    'Dhaka, 2026-01-15, Karachi method, Standard Asr — matches the '
    'published Al Adhan API reference within 2 minutes',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 23.8103,
        longitude: 90.4125,
        ianaTimezone: 'Asia/Dhaka',
        method: CalculationMethod.karachi,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Asia/Dhaka', date, '05:23'));
      expectWithinTolerance(result.dhuhr, localTime('Asia/Dhaka', date, '12:08'));
      expectWithinTolerance(result.asr, localTime('Asia/Dhaka', date, '15:11'));
      expectWithinTolerance(result.maghrib, localTime('Asia/Dhaka', date, '17:33'));
      expectWithinTolerance(result.isha, localTime('Asia/Dhaka', date, '18:52'));
    },
  );

  test(
    'Kuala Lumpur, 2026-01-15, Singapore method, Standard Asr — matches '
    'the published Al Adhan API reference within 2 minutes',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 3.1390,
        longitude: 101.6869,
        ianaTimezone: 'Asia/Kuala_Lumpur',
        method: CalculationMethod.singapore,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Asia/Kuala_Lumpur', date, '06:01'));
      expectWithinTolerance(result.dhuhr, localTime('Asia/Kuala_Lumpur', date, '13:23'));
      expectWithinTolerance(result.asr, localTime('Asia/Kuala_Lumpur', date, '16:46'));
      expectWithinTolerance(result.maghrib, localTime('Asia/Kuala_Lumpur', date, '19:21'));
      expectWithinTolerance(result.isha, localTime('Asia/Kuala_Lumpur', date, '20:35'));
    },
  );

  test(
    'London, 2026-01-15, Muslim World League method, Standard Asr — '
    'matches the published Al Adhan API reference within 2 minutes',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 51.5074,
        longitude: -0.1278,
        ianaTimezone: 'Europe/London',
        method: CalculationMethod.mwl,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Europe/London', date, '05:59'));
      expectWithinTolerance(result.dhuhr, localTime('Europe/London', date, '12:10'));
      expectWithinTolerance(result.asr, localTime('Europe/London', date, '14:00'));
      expectWithinTolerance(result.maghrib, localTime('Europe/London', date, '16:21'));
      expectWithinTolerance(result.isha, localTime('Europe/London', date, '18:15'));
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/prayer/domain/calculate_prayer_times_golden_test.dart`
Expected: FAIL — `calculate_prayer_times.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// One day's five prayer instants, UTC.
typedef PrayerTimes = ({
  DateTime fajr,
  DateTime dhuhr,
  DateTime asr,
  DateTime maghrib,
  DateTime isha,
});

/// Pure wrapper over `adhan_dart` (FR-P-01/02) — no `clock.now()`, the
/// caller supplies [date]. The package's own import is aliased as
/// `adhan.*` throughout this file since its `PrayerTimes` class would
/// otherwise collide with this file's own [PrayerTimes] records typedef
/// (this plan's design carries the design spec's exact typedef name
/// forward; only the import needed disambiguating).
///
/// Requires `ensureTimeZonesInitialized()` (`core/utils/local_day.dart`)
/// to have already run.
PrayerTimes calculatePrayerTimes({
  required LocalDate date,
  required double latitude,
  required double longitude,
  required String ianaTimezone,
  required CalculationMethod method,
  required AsrMethod asrMethod,
}) {
  final location = tz.getLocation(ianaTimezone);
  // Noon (not midnight) local, converted to UTC — `adhan_dart` only needs
  // the calendar date component, and noon avoids any ambiguity a midnight
  // instant could hit right at a DST transition boundary.
  final localNoon = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    12,
  );
  final coordinates = adhan.Coordinates(latitude, longitude);
  final params = _parametersFor(method);
  params.madhab = asrMethod == AsrMethod.hanafi
      ? adhan.Madhab.hanafi
      : adhan.Madhab.shafi;

  final times = adhan.PrayerTimes(
    coordinates: coordinates,
    date: localNoon.toUtc(),
    calculationParameters: params,
    precision: true,
  );

  return (
    fajr: times.fajr.toUtc(),
    dhuhr: times.dhuhr.toUtc(),
    asr: times.asr.toUtc(),
    maghrib: times.maghrib.toUtc(),
    isha: times.isha.toUtc(),
  );
}

adhan.CalculationParameters _parametersFor(CalculationMethod method) =>
    switch (method) {
      CalculationMethod.mwl =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      CalculationMethod.isna =>
        adhan.CalculationMethodParameters.northAmerica(),
      CalculationMethod.egyptian =>
        adhan.CalculationMethodParameters.egyptian(),
      CalculationMethod.ummAlQura =>
        adhan.CalculationMethodParameters.ummAlQura(),
      CalculationMethod.karachi =>
        adhan.CalculationMethodParameters.karachi(),
      CalculationMethod.tehran =>
        adhan.CalculationMethodParameters.tehran(),
      CalculationMethod.dubai =>
        adhan.CalculationMethodParameters.dubai(),
      CalculationMethod.kuwait =>
        adhan.CalculationMethodParameters.kuwait(),
      CalculationMethod.qatar =>
        adhan.CalculationMethodParameters.qatar(),
      CalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
    };
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/calculate_prayer_times_golden_test.dart`
Expected: PASS (3 tests). If any city misses tolerance, investigate
before accepting — do not widen the tolerance to make it pass (per the
design spec's explicit instruction).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/calculate_prayer_times.dart test/features/prayer/domain/calculate_prayer_times_golden_test.dart
git commit -m "feat(prayer): calculatePrayerTimes wrapper over adhan_dart, golden-tested"
```

---

### Task 4: `effectivePrayerStatus` + `cutoffForPrayer`

**Files:**
- Create: `lib/features/prayer/domain/usecases/effective_prayer_status.dart`
- Test: `test/features/prayer/domain/effective_prayer_status_test.dart`

**Interfaces:**
- Consumes: `PrayerStatus`, `PrayerRecord` (Task 2), `LocalTime`
  (`core/utils/local_date.dart`).
- Produces: `PrayerStatus effectivePrayerStatus({required PrayerStatus
  storedStatus, required DateTime scheduledFor, required DateTime cutoff,
  required DateTime now})`, `DateTime cutoffForPrayer({required
  PrayerRecord record, required List<PrayerRecord> sameDayRecordsSorted,
  required LocalTime ishaDayRolloverTime, String? ianaTimezone})` — used
  by Task 11 (sweep), Task 15 (providers), Task 17 (checklist screen).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('effectivePrayerStatus', () {
    final scheduledFor = DateTime.utc(2026, 6, 1, 12);
    final cutoff = DateTime.utc(2026, 6, 1, 15);

    test('before scheduled time: upcoming', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor.subtract(const Duration(minutes: 1)),
        ),
        PrayerStatus.upcoming,
      );
    });

    test('at scheduled time: due', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor,
        ),
        PrayerStatus.due,
      );
    });

    test('just before cutoff: still due', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff.subtract(const Duration(minutes: 1)),
        ),
        PrayerStatus.due,
      );
    });

    test('at/after cutoff: missed', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff,
        ),
        PrayerStatus.missed,
      );
    });

    test('a prayed record stays prayed regardless of elapsed time', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.prayed,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff.add(const Duration(days: 1)),
        ),
        PrayerStatus.prayed,
      );
    });

    test('a missed record stays missed', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.missed,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor,
        ),
        PrayerStatus.missed,
      );
    });
  });

  group('cutoffForPrayer', () {
    final fajr = PrayerRecord(
      id: 'r1',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 0),
      storedStatus: PrayerStatus.upcoming,
    );
    final dhuhr = PrayerRecord(
      id: 'r2',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.dhuhr,
      scheduledFor: DateTime.utc(2026, 6, 1, 6),
      storedStatus: PrayerStatus.upcoming,
    );
    final isha = PrayerRecord(
      id: 'r3',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.isha,
      scheduledFor: DateTime.utc(2026, 6, 1, 13),
      storedStatus: PrayerStatus.upcoming,
    );
    final sameDay = [fajr, dhuhr, isha];

    test('a mid-day prayer\'s cutoff is the next prayer\'s scheduledFor', () {
      final cutoff = cutoffForPrayer(
        record: fajr,
        sameDayRecordsSorted: sameDay,
        ishaDayRolloverTime: const LocalTime(0, 0),
        ianaTimezone: 'UTC',
      );
      expect(cutoff, dhuhr.scheduledFor);
    });

    test(
      'the day\'s last prayer\'s cutoff is the Isha rollover time on the '
      'next calendar day, resolved in the given timezone',
      () {
        final cutoff = cutoffForPrayer(
          record: isha,
          sameDayRecordsSorted: sameDay,
          ishaDayRolloverTime: const LocalTime(0, 30),
          ianaTimezone: 'UTC',
        );
        expect(cutoff, DateTime.utc(2026, 6, 2, 0, 30));
      },
    );

    test('a null timezone falls back to the device ambient timezone', () {
      final cutoff = cutoffForPrayer(
        record: isha,
        sameDayRecordsSorted: sameDay,
        ishaDayRolloverTime: const LocalTime(0, 0),
      );
      // Same calendar instant regardless of host machine's timezone —
      // just verify it lands on the following calendar day at local
      // midnight, converted to UTC (exact instant depends on host TZ,
      // so only the day-forward relationship is asserted).
      expect(cutoff.isAfter(isha.scheduledFor), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/domain/effective_prayer_status_test.dart`
Expected: FAIL — `effective_prayer_status.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:timezone/timezone.dart' as tz;

/// Derives a prayer record's live status (FR-P-07). [storedStatus] is
/// only ever `upcoming`/`prayed`/`missed` in the database — `due` is
/// computed here, at read time, mirroring Medicine's
/// `effectiveDoseStatus` precedent.
PrayerStatus effectivePrayerStatus({
  required PrayerStatus storedStatus,
  required DateTime scheduledFor,
  required DateTime cutoff,
  required DateTime now,
}) {
  if (storedStatus != PrayerStatus.upcoming) return storedStatus;
  if (now.isBefore(scheduledFor)) return PrayerStatus.upcoming;
  if (now.isBefore(cutoff)) return PrayerStatus.due;
  return PrayerStatus.missed;
}

/// The cutoff instant (FR-P-05) for [record] — the next-in-day prayer's
/// `scheduledFor` among [sameDayRecordsSorted] (every record for the same
/// `prayerDate`, sorted by `scheduledFor` ascending), or — for the day's
/// last prayer (Isha) — [ishaDayRolloverTime] resolved to the *next*
/// calendar day in [ianaTimezone].
///
/// A `null` [ianaTimezone] falls back to the device's own ambient
/// timezone — same "accepted edge case" precedent as
/// `core/utils/local_day.dart`'s no-location overload of `localDayKey`.
/// Requires `ensureTimeZonesInitialized()` to have already run when
/// [ianaTimezone] is non-null.
DateTime cutoffForPrayer({
  required PrayerRecord record,
  required List<PrayerRecord> sameDayRecordsSorted,
  required LocalTime ishaDayRolloverTime,
  String? ianaTimezone,
}) {
  final index = sameDayRecordsSorted.indexWhere((r) => r.id == record.id);
  if (index != -1 && index < sameDayRecordsSorted.length - 1) {
    return sameDayRecordsSorted[index + 1].scheduledFor;
  }
  final rolloverDay = record.prayerDate.addDays(1);
  if (ianaTimezone == null) {
    final local = DateTime(
      rolloverDay.year,
      rolloverDay.month,
      rolloverDay.day,
      ishaDayRolloverTime.hour,
      ishaDayRolloverTime.minute,
    );
    return local.toUtc();
  }
  final location = tz.getLocation(ianaTimezone);
  final rollover = tz.TZDateTime(
    location,
    rolloverDay.year,
    rolloverDay.month,
    rolloverDay.day,
    ishaDayRolloverTime.hour,
    ishaDayRolloverTime.minute,
  );
  return rollover.toUtc();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/effective_prayer_status_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/effective_prayer_status.dart test/features/prayer/domain/effective_prayer_status_test.dart
git commit -m "feat(prayer): status derivation and cutoff-instant calculation"
```

---

### Task 5: `isJumuahDisplay`

**Files:**
- Create: `lib/features/prayer/domain/usecases/jumuah_label.dart`
- Test: `test/features/prayer/domain/jumuah_label_test.dart`

**Interfaces:**
- Consumes: `PrayerName` (Task 2), `LocalDate` (`core/utils/local_date.dart`).
- Produces: `bool isJumuahDisplay({required PrayerName prayerName,
  required LocalDate date, required bool observesJumuah})` — used by Task
  15 (providers), Task 17 (checklist screen).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';

void main() {
  // 2026-06-05 is a Friday.
  const friday = LocalDate(2026, 6, 5);
  const saturday = LocalDate(2026, 6, 6);

  test('Dhuhr on a Friday with observesJumuah on: true', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: friday,
        observesJumuah: true,
      ),
      isTrue,
    );
  });

  test('Dhuhr on a Friday with observesJumuah off: false', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: friday,
        observesJumuah: false,
      ),
      isFalse,
    );
  });

  test('Dhuhr on a non-Friday, even with observesJumuah on: false', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: saturday,
        observesJumuah: true,
      ),
      isFalse,
    );
  });

  test('a non-Dhuhr prayer on a Friday is never Jumu\'ah: false', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.asr,
        date: friday,
        observesJumuah: true,
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/domain/jumuah_label_test.dart`
Expected: FAIL — `jumuah_label.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Whether [prayerName] on [date] should display as "Jumu'ah" instead of
/// "Dhuhr" (D-07/FR-P-03) — a pure render-time label decision; the
/// underlying record is always `prayerName: dhuhr`, sharing Dhuhr's
/// schedule and Qadha bucket (this plan's refinements section, #1).
bool isJumuahDisplay({
  required PrayerName prayerName,
  required LocalDate date,
  required bool observesJumuah,
}) {
  if (prayerName != PrayerName.dhuhr || !observesJumuah) return false;
  return date.toDateTimeUtc().weekday == DateTime.friday;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/jumuah_label_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/jumuah_label.dart test/features/prayer/domain/jumuah_label_test.dart
git commit -m "feat(prayer): Jumu'ah display-label predicate"
```

---

### Task 6: `planPrayerMaterialization`

**Files:**
- Create: `lib/features/prayer/domain/usecases/plan_prayer_materialization.dart`
- Test: `test/features/prayer/domain/plan_prayer_materialization_test.dart`

**Interfaces:**
- Consumes: `calculatePrayerTimes` (Task 3), `PrayerSettings`,
  `ResolvedLocation`, `PrayerRecord`, `PrayerName` (Task 2).
- Produces: `typedef PlannedPrayerRecord = ({LocalDate prayerDate,
  PrayerName prayerName, DateTime scheduledFor})`,
  `List<PlannedPrayerRecord> planPrayerMaterialization({required
  PrayerSettings settings, required ResolvedLocation location, required
  List<PrayerRecord> existingRecords, required LocalDate windowStart,
  required LocalDate windowEnd})` — used by Task 12
  (`PrayerRepositoryImpl.materializeRecords`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/plan_prayer_materialization.dart';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.auto,
  );
  const location = (
    latitude: 23.8103,
    longitude: 90.4125,
    ianaTimezone: 'Asia/Dhaka',
  );

  test('generates 5 records per day across the window', () {
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 2),
    );
    expect(planned, hasLength(10)); // 2 days x 5 prayers
    expect(
      planned.map((p) => p.prayerName).toSet(),
      PrayerName.values.toSet(),
    );
  });

  test('never re-plans a slot that already has a record', () {
    final existing = PrayerRecord(
      id: 'r1',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 0),
      storedStatus: PrayerStatus.prayed,
    );
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: [existing],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, hasLength(4)); // 5 minus the already-existing Fajr
    expect(planned.any((p) => p.prayerName == PrayerName.fajr), isFalse);
  });

  test('windowEnd before windowStart returns empty, not an error', () {
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: const [],
      windowStart: const LocalDate(2026, 6, 10),
      windowEnd: const LocalDate(2026, 6, 5),
    );
    expect(planned, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/domain/plan_prayer_materialization_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';

/// A prayer record still to be inserted — the repository assigns its id
/// at insert time (ids are never generated in pure domain code).
typedef PlannedPrayerRecord = ({
  LocalDate prayerDate,
  PrayerName prayerName,
  DateTime scheduledFor,
});

/// Plans which new [PrayerRecord] rows need to exist for
/// `[windowStart, windowEnd]` (D-13's 30-day rolling window). Much
/// simpler than Medicine's repeat-rule planner — one settings row, not N
/// schedules, no collision resolution needed. For each day, for each of
/// the 5 prayers (Friday's Dhuhr slot is still `prayerName: dhuhr` —
/// Jumu'ah is a display label, not a separate row, per D-07), if
/// `(prayerDate, prayerName)` is missing from [existingRecords], plans it
/// via [calculatePrayerTimes].
List<PlannedPrayerRecord> planPrayerMaterialization({
  required PrayerSettings settings,
  required ResolvedLocation location,
  required List<PrayerRecord> existingRecords,
  required LocalDate windowStart,
  required LocalDate windowEnd,
}) {
  if (windowEnd.compareTo(windowStart) < 0) return [];
  final existingSlots = {
    for (final r in existingRecords) (r.prayerDate, r.prayerName),
  };
  final planned = <PlannedPrayerRecord>[];
  var day = windowStart;
  while (day.compareTo(windowEnd) <= 0) {
    final times = calculatePrayerTimes(
      date: day,
      latitude: location.latitude,
      longitude: location.longitude,
      ianaTimezone: location.ianaTimezone,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
    );
    for (final slot in _slotsFor(times)) {
      final key = (day, slot.name);
      if (existingSlots.contains(key)) continue;
      planned.add((
        prayerDate: day,
        prayerName: slot.name,
        scheduledFor: slot.time,
      ));
    }
    day = day.addDays(1);
  }
  return planned;
}

List<({PrayerName name, DateTime time})> _slotsFor(PrayerTimes times) => [
  (name: PrayerName.fajr, time: times.fajr),
  (name: PrayerName.dhuhr, time: times.dhuhr),
  (name: PrayerName.asr, time: times.asr),
  (name: PrayerName.maghrib, time: times.maghrib),
  (name: PrayerName.isha, time: times.isha),
];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/plan_prayer_materialization_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/plan_prayer_materialization.dart test/features/prayer/domain/plan_prayer_materialization_test.dart
git commit -m "feat(prayer): day-based materialization planner"
```

---

### Task 7: `CalculatePrayerStreakUseCase`

**Files:**
- Create: `lib/features/prayer/domain/usecases/calculate_prayer_streak.dart`
- Test: `test/features/prayer/domain/calculate_prayer_streak_test.dart`

**Interfaces:**
- Consumes: `PrayerRecord`, `PrayerStatus` (Task 2), `LocalDate`.
- Produces: `PrayerStreakResult` (freezed, `current`/`longest` int
  fields), `CalculatePrayerStreakUseCase` with `execute({required
  Map<LocalDate, List<PrayerRecord>> recordsByDay, required LocalDate
  earliestDay, required LocalDate today})` — used by Task 20 (stats
  screen).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';

void main() {
  List<PrayerRecord> allPrayed(LocalDate date) => [
    for (final name in PrayerName.values)
      PrayerRecord(
        id: '${date.toIso()}_${name.name}',
        prayerDate: date,
        prayerName: name,
        scheduledFor: date.toDateTimeUtc(),
        storedStatus: PrayerStatus.prayed,
      ),
  ];

  List<PrayerRecord> oneMissed(LocalDate date) => [
    for (final name in PrayerName.values)
      PrayerRecord(
        id: '${date.toIso()}_${name.name}',
        prayerDate: date,
        prayerName: name,
        scheduledFor: date.toDateTimeUtc(),
        storedStatus: name == PrayerName.fajr
            ? PrayerStatus.missed
            : PrayerStatus.prayed,
      ),
  ];

  test('3 consecutive fully-prayed days: current and longest both 3', () {
    final day1 = const LocalDate(2026, 6, 1);
    final day2 = const LocalDate(2026, 6, 2);
    final day3 = const LocalDate(2026, 6, 3);
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: {
        day1: allPrayed(day1),
        day2: allPrayed(day2),
        day3: allPrayed(day3),
      },
      earliestDay: day1,
      today: day3,
    );
    expect(result.current, 3);
    expect(result.longest, 3);
  });

  test('a day missing one prayer breaks the running streak', () {
    final day1 = const LocalDate(2026, 6, 1);
    final day2 = const LocalDate(2026, 6, 2);
    final day3 = const LocalDate(2026, 6, 3);
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: {
        day1: allPrayed(day1),
        day2: oneMissed(day2),
        day3: allPrayed(day3),
      },
      earliestDay: day1,
      today: day3,
    );
    expect(result.current, 1); // just day3
    expect(result.longest, 1); // day1 alone, before the break
  });

  test(
    'today still in progress (an upcoming record) is skipped, not '
    'counted and not broken — current reflects the last fully-resolved day',
    () {
      final day1 = const LocalDate(2026, 6, 1);
      final today = const LocalDate(2026, 6, 2);
      final inProgress = [
        for (final name in PrayerName.values)
          PrayerRecord(
            id: 'today_${name.name}',
            prayerDate: today,
            prayerName: name,
            scheduledFor: today.toDateTimeUtc(),
            storedStatus: name == PrayerName.isha
                ? PrayerStatus.upcoming
                : PrayerStatus.prayed,
          ),
      ];
      final result = const CalculatePrayerStreakUseCase().execute(
        recordsByDay: {day1: allPrayed(day1), today: inProgress},
        earliestDay: day1,
        today: today,
      );
      expect(result.current, 1);
    },
  );

  test('earliestDay after today returns a zero result', () {
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: const {},
      earliestDay: const LocalDate(2026, 6, 10),
      today: const LocalDate(2026, 6, 1),
    );
    expect(result.current, 0);
    expect(result.longest, 0);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/domain/calculate_prayer_streak_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

part 'calculate_prayer_streak.freezed.dart';

/// Current and longest prayer streaks (FR-P-09/10).
@freezed
sealed class PrayerStreakResult with _$PrayerStreakResult {
  /// Creates a streak result.
  const factory PrayerStreakResult({
    required int current,
    required int longest,
  }) = _PrayerStreakResult;
}

/// Streak = consecutive calendar days where every required prayer is
/// `prayed` before its cutoff (FR-P-09). The required count is always 5
/// — Jumu'ah relabels an existing required prayer (Dhuhr) on Fridays, it
/// never adds a sixth (this plan's refinements section, #1), so unlike
/// `CalculateWaterStreakUseCase` this use case needs no goal/settings
/// input at all, just the records themselves.
class CalculatePrayerStreakUseCase {
  /// Creates the use case.
  const CalculatePrayerStreakUseCase();

  /// Computes the current streak (consecutive days ending at [today]) and
  /// the longest streak found between [earliestDay] and [today]
  /// inclusive. [recordsByDay] maps a day to that day's records; a day
  /// with fewer than 5 records (not yet materialized) or any record still
  /// `upcoming` (not yet resolved, including "today" still in progress)
  /// is skipped — it neither counts nor breaks the running streak, since
  /// it hasn't failed yet. A day with 5 resolved records where at least
  /// one is `missed` breaks the streak.
  PrayerStreakResult execute({
    required Map<LocalDate, List<PrayerRecord>> recordsByDay,
    required LocalDate earliestDay,
    required LocalDate today,
  }) {
    if (earliestDay.compareTo(today) > 0) {
      return const PrayerStreakResult(current: 0, longest: 0);
    }

    var longest = 0;
    var running = 0;
    var current = 0;

    var day = earliestDay;
    while (day.compareTo(today) <= 0) {
      final records = recordsByDay[day] ?? const [];
      if (records.length < 5 ||
          records.any((r) => r.storedStatus == PrayerStatus.upcoming)) {
        day = day.addDays(1);
        continue;
      }
      final allPrayed = records.every(
        (r) => r.storedStatus == PrayerStatus.prayed,
      );
      if (allPrayed) {
        running += 1;
        current = running;
      } else {
        longest = running > longest ? running : longest;
        running = 0;
        current = 0;
      }
      day = day.addDays(1);
    }
    longest = running > longest ? running : longest;

    return PrayerStreakResult(current: current, longest: longest);
  }
}
```

- [ ] **Step 4: Run codegen and tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/prayer/domain/calculate_prayer_streak_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/calculate_prayer_streak.dart lib/features/prayer/domain/usecases/calculate_prayer_streak.freezed.dart test/features/prayer/domain/calculate_prayer_streak_test.dart
git commit -m "feat(prayer): streak calculation"
```

---

### Task 8: Qadha make-up adjustment

**Files:**
- Create: `lib/features/prayer/domain/usecases/qadha_adjustment.dart`
- Test: `test/features/prayer/domain/qadha_adjustment_test.dart`

**Interfaces:**
- Consumes: `PrayerQadhaCounter` (Task 2).
- Produces: `int applyQadhaMakeup(PrayerQadhaCounter counter)` — used by
  Task 11 (`PrayerRepositoryImpl.markQadhaMakeup`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/qadha_adjustment.dart';

void main() {
  test('decrements by 1', () {
    final counter = PrayerQadhaCounter(
      id: 'c1',
      prayerName: PrayerName.fajr,
      count: 5,
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    expect(applyQadhaMakeup(counter), 4);
  });

  test('clamps at 0, never goes negative', () {
    final counter = PrayerQadhaCounter(
      id: 'c1',
      prayerName: PrayerName.fajr,
      count: 0,
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    expect(applyQadhaMakeup(counter), 0);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/domain/qadha_adjustment_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';

/// New Qadha balance after applying [counter]'s make-up "−1" control
/// (FR-P-05), clamped at 0.
int applyQadhaMakeup(PrayerQadhaCounter counter) =>
    counter.count > 0 ? counter.count - 1 : 0;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/qadha_adjustment_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/qadha_adjustment.dart test/features/prayer/domain/qadha_adjustment_test.dart
git commit -m "feat(prayer): Qadha make-up adjustment calculator"
```

---

### Task 9: `calculateAdherence`

**Files:**
- Create: `lib/features/prayer/domain/usecases/calculate_adherence.dart`
- Test: `test/features/prayer/domain/calculate_adherence_test.dart`

**Interfaces:**
- Consumes: `PrayerRecord`, `PrayerStatus`, `PrayerName` (Task 2).
- Produces: `typedef PrayerAdherenceStats = ({int prayed, int missed, int
  total})`, `Map<PrayerName, PrayerAdherenceStats> calculateAdherence({
  required List<PrayerRecord> records})` — used by Task 20 (stats
  screen).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_adherence.dart';

void main() {
  PrayerRecord record({
    required PrayerName name,
    required PrayerStatus status,
  }) =>
      PrayerRecord(
        id: '${name.name}_${status.name}',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: name,
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: status,
      );

  test('classifies prayed/missed per prayer, excludes upcoming/due', () {
    final stats = calculateAdherence(
      records: [
        record(name: PrayerName.fajr, status: PrayerStatus.prayed),
        record(name: PrayerName.fajr, status: PrayerStatus.missed),
        record(name: PrayerName.dhuhr, status: PrayerStatus.prayed),
        record(name: PrayerName.dhuhr, status: PrayerStatus.upcoming),
      ],
    );
    expect(stats[PrayerName.fajr]!.prayed, 1);
    expect(stats[PrayerName.fajr]!.missed, 1);
    expect(stats[PrayerName.fajr]!.total, 2);
    expect(stats[PrayerName.dhuhr]!.prayed, 1);
    expect(stats[PrayerName.dhuhr]!.total, 1); // upcoming excluded
    expect(stats[PrayerName.asr]!.total, 0); // no records at all
  });
}
```

Add `import 'package:habit_tracker/core/utils/local_date.dart';` alongside
the other imports in the test file (for `LocalDate`).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/prayer/domain/calculate_adherence_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Per-prayer adherence breakdown (FR-P-10).
typedef PrayerAdherenceStats = ({int prayed, int missed, int total});

/// Classifies [records] by persisted status, grouped per [PrayerName]
/// (FR-P-10's "per-prayer on-time percentage" — there's no "prayed-late"
/// status in this module, so `prayed` already means on-time).
/// `upcoming`/`due` records (not yet resolved) are excluded from every
/// count. Trusts `storedStatus` directly rather than re-deriving via
/// `effectivePrayerStatus`: adherence windows are always past/completed
/// ranges, and `sweepMissedPrayers` (run on every app-resume via
/// `PrayerModule.pendingNotifications()`) keeps `missed` current well
/// before any stats screen reads it. Every [PrayerName] gets an entry,
/// even `(prayed: 0, missed: 0, total: 0)` if [records] has none for it.
Map<PrayerName, PrayerAdherenceStats> calculateAdherence({
  required List<PrayerRecord> records,
}) {
  final prayedCounts = <PrayerName, int>{};
  final missedCounts = <PrayerName, int>{};
  for (final record in records) {
    switch (record.storedStatus) {
      case PrayerStatus.prayed:
        prayedCounts[record.prayerName] =
            (prayedCounts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.missed:
        missedCounts[record.prayerName] =
            (missedCounts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.upcoming:
      case PrayerStatus.due:
        break;
    }
  }
  return {
    for (final name in PrayerName.values)
      name: (
        prayed: prayedCounts[name] ?? 0,
        missed: missedCounts[name] ?? 0,
        total: (prayedCounts[name] ?? 0) + (missedCounts[name] ?? 0),
      ),
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/domain/calculate_adherence_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/domain/usecases/calculate_adherence.dart test/features/prayer/domain/calculate_adherence_test.dart
git commit -m "feat(prayer): per-prayer adherence calculation"
```

---

### Task 10: Drift tables + `PrayerRepository` interface

**Files:**
- Create: `lib/features/prayer/data/tables/prayer_settings_table.dart`
- Create: `lib/features/prayer/data/tables/prayer_records_table.dart`
- Create: `lib/features/prayer/data/tables/prayer_qadha_counters_table.dart`
- Create: `lib/features/prayer/domain/repositories/prayer_repository.dart`
- Modify: `lib/core/database/app_database.dart`

**Interfaces:**
- Produces: 3 Drift tables registered in `AppDatabase`; the
  `PrayerRepository` abstract interface Tasks 11-13 implement and every
  presentation task consumes.

- [ ] **Step 1: Write the three table files**

```dart
// lib/features/prayer/data/tables/prayer_settings_table.dart
import 'package:drift/drift.dart';

/// The Prayer module's singleton settings row (`technical/database-
/// design.md`).
///
/// `notifications_enabled`/`pre_reminder_enabled`/
/// `pre_reminder_offset_minutes` are additions beyond that doc's original
/// column list (FR-P-08's reminder controls) — same "settings gained a
/// reminder column mid-run" precedent as `water_settings`.
@DataClassName('PrayerSettingsRow')
class PrayerSettingsTable extends Table {
  @override
  String get tableName => 'prayer_settings';

  /// Row id — always `'singleton'`.
  TextColumn get id => text()();

  /// D-06.
  TextColumn get calculationMethod => text()();

  /// `'standard'` | `'hanafi'` (D-06).
  TextColumn get asrMethod => text()();

  /// Default false (D-07).
  BoolColumn get observesJumuah =>
      boolean().withDefault(const Constant(false))();

  /// `'auto'` | `'manual'` (D-09).
  TextColumn get locationMode => text()();

  /// Used when `locationMode = 'manual'`.
  RealColumn get manualLatitude => real().nullable()();

  /// Used when `locationMode = 'manual'`.
  RealColumn get manualLongitude => real().nullable()();

  /// IANA tz id, e.g. `"Asia/Dhaka"`.
  TextColumn get manualTimezone => text().nullable()();

  /// Local `"HH:mm"`, default `"00:00"` (D-08 cutoff).
  TextColumn get ishaDayRolloverTime =>
      text().withDefault(const Constant('00:00'))();

  /// FR-P-08 — default true (unlike Water's reminders, which default off).
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// FR-P-08's optional pre-prayer reminder.
  BoolColumn get preReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Minutes before `scheduledFor`.
  IntColumn get preReminderOffsetMinutes =>
      integer().withDefault(const Constant(10))();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// lib/features/prayer/data/tables/prayer_records_table.dart
import 'package:drift/drift.dart';

/// A materialized prayer record (D-13) — one per prayer per local day,
/// rolling 30-day window.
@DataClassName('PrayerRecordRow')
@TableIndex(name: 'idx_prayer_records_scheduled_for', columns: {#scheduledFor})
class PrayerRecordsTable extends Table {
  @override
  String get tableName => 'prayer_records';

  /// Row id.
  TextColumn get id => text()();

  /// Local calendar date `"YYYY-MM-DD"` — materialized bucket key.
  TextColumn get prayerDate => text()();

  /// `'fajr'` | `'dhuhr'` | `'asr'` | `'maghrib'` | `'isha'` — Jumu'ah is
  /// a Friday display label over `'dhuhr'`, never its own stored value.
  TextColumn get prayerName => text()();

  /// UTC epoch millis, computed from `prayer_settings` + resolved
  /// location at generation time.
  IntColumn get scheduledFor => integer()();

  /// `'upcoming'` | `'prayed'` | `'missed'` only — `due` is derived at
  /// read time, never stored.
  TextColumn get status => text()();

  /// UTC epoch millis of the last explicit status change; null while
  /// still `upcoming`.
  IntColumn get statusChangedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {prayerDate, prayerName},
  ];
}
```

```dart
// lib/features/prayer/data/tables/prayer_qadha_counters_table.dart
import 'package:drift/drift.dart';

/// One prayer's running Qadha balance (D-08) — exactly five rows, one per
/// prayer, seeded at first setup.
@DataClassName('PrayerQadhaCounterRow')
class PrayerQadhaCountersTable extends Table {
  @override
  String get tableName => 'prayer_qadha_counters';

  /// Row id.
  TextColumn get id => text()();

  /// `'fajr'` | `'dhuhr'` | `'asr'` | `'maghrib'` | `'isha'` — no
  /// `'jumuah'` row, it shares Dhuhr's bucket (D-07/FR-P-03).
  TextColumn get prayerName => text()();

  /// Default 0, floors at 0 (app-enforced).
  IntColumn get count => integer().withDefault(const Constant(0))();

  /// UTC epoch millis.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {prayerName},
  ];
}
```

- [ ] **Step 2: Register the tables in `app_database.dart`**

In `lib/core/database/app_database.dart`, add the three imports:

```dart
import 'package:habit_tracker/features/prayer/data/tables/prayer_qadha_counters_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_records_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_settings_table.dart';
```

and add the three table classes to the `@DriftDatabase(tables: [...])`
list (alongside the existing Water/Medicine tables):

```dart
    PrayerSettingsTable,
    PrayerRecordsTable,
    PrayerQadhaCountersTable,
```

- [ ] **Step 3: Write the `PrayerRepository` interface**

```dart
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';

/// Reads and mutates the Prayer module's data.
abstract class PrayerRepository {
  /// Streams the (auto-seeded) singleton settings row.
  Stream<PrayerSettings> watchSettings();

  /// Updates settings fields; only non-null arguments change. Soft-
  /// deletes future `upcoming` records when a location/method-affecting
  /// field changes, so the next materialization pass regenerates them
  /// with the new times (FR-P-01, this plan's refinements section, #3).
  Future<Result<void>> updateSettings({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
    bool? observesJumuah,
    LocationMode? locationMode,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    LocalTime? ishaDayRolloverTime,
    bool? notificationsEnabled,
    bool? preReminderEnabled,
    int? preReminderOffsetMinutes,
  });

  /// Streams all five Qadha counters (seeded at first settings read).
  Stream<List<PrayerQadhaCounter>> watchQadhaCounters();

  /// Applies the "−1" make-up control (FR-P-05).
  Future<Result<void>> markQadhaMakeup(PrayerName prayerName);

  /// Sets a counter directly (FR-P-04's onboarding/Settings starting-
  /// balance entry — a raw input, not derived logic). Clamped at 0.
  Future<Result<void>> setQadhaBalance(PrayerName prayerName, int count);

  /// Tops up `prayer_records` for the D-13 30-day rolling window ahead of
  /// [now], given the currently resolved [location] (this plan's
  /// refinements section, #2). Idempotent.
  Future<void> materializeRecords(DateTime now, ResolvedLocation location);

  /// One-shot missed-prayer sweep + Qadha+1 (FR-P-05), given the
  /// currently resolved [location] (needed for the Isha rollover
  /// cutoff's timezone). Idempotent — a record only ever makes the
  /// upcoming->missed transition once.
  Future<void> sweepMissedPrayers(DateTime now, ResolvedLocation location);

  /// Streams every (non-deleted) record scheduled on [day].
  Stream<List<PrayerRecord>> watchRecordsForDay(LocalDate day);

  /// Every (non-deleted) record with `prayerDate` in `[start, end]`
  /// inclusive.
  Future<List<PrayerRecord>> recordsInRange(LocalDate start, LocalDate end);

  /// Marks a record prayed (FR-P-07's one-tap toggle). Fails validation
  /// if the record is already `missed` (never a manual tap target).
  Future<Result<void>> markPrayed(String recordId);

  /// Un-marks a prayed record back to `upcoming` (toggle off).
  Future<Result<void>> unmarkPrayed(String recordId);

  /// Marks a record explicitly missed via a Skip notification action
  /// (FR-P-08) — same transition `sweepMissedPrayers` would eventually
  /// make, just user-triggered; bumps that prayer's Qadha counter.
  Future<Result<void>> markMissedBySkip(String recordId);

  /// Every (non-deleted) record, across every day — export groundwork.
  Future<List<PrayerRecord>> allRecords();
}
```

- [ ] **Step 4: Generate Drift code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerates with the 3 new tables, no
errors.

Run: `flutter analyze lib/features/prayer/ lib/core/database/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/data/tables/ lib/features/prayer/domain/repositories/ lib/core/database/app_database.dart lib/core/database/app_database.g.dart
git commit -m "feat(prayer): Drift tables and repository interface"
```

---

### Task 11: `PrayerRepositoryImpl` — settings and Qadha counters

**Files:**
- Create: `lib/features/prayer/data/repositories/prayer_repository_impl.dart`
- Test: `test/features/prayer/data/prayer_repository_impl_test.dart`

**Interfaces:**
- Consumes: `PrayerRepository` (Task 10), `applyQadhaMakeup` (Task 8),
  `generateId()` (`core/utils/uuid.dart`).
- Produces: `PrayerRepositoryImpl` class (constructor
  `PrayerRepositoryImpl(AppDatabase db, {CalculationMethod Function()?
  defaultCalculationMethod, AsrMethod Function()? defaultAsrMethod})`)
  implementing the settings/Qadha half of the interface — Tasks 12-13 add
  the remaining methods to this same class.

- [ ] **Step 1: Write the failing tests (settings/Qadha subset)**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';

void main() {
  late AppDatabase db;
  late PrayerRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PrayerRepositoryImpl(
      db,
      defaultCalculationMethod: () => CalculationMethod.karachi,
      defaultAsrMethod: () => AsrMethod.hanafi,
    );
  });

  tearDown(() => db.close());

  test('watchSettings seeds a singleton row on first read', () async {
    final settings = await repo.watchSettings().first;
    expect(settings.id, 'singleton');
    expect(settings.calculationMethod, CalculationMethod.karachi);
    expect(settings.asrMethod, AsrMethod.hanafi);
    expect(settings.locationMode, LocationMode.auto);
  });

  test('watchQadhaCounters seeds exactly 5 rows, one per PrayerName', () async {
    final counters = await repo.watchQadhaCounters().first;
    expect(counters, hasLength(5));
    expect(
      counters.map((c) => c.prayerName).toSet(),
      PrayerName.values.toSet(),
    );
    expect(counters.every((c) => c.count == 0), isTrue);
  });

  test('updateSettings changes only the given fields', () async {
    await repo.watchSettings().first; // ensure seeded
    final result = await repo.updateSettings(observesJumuah: true);
    expect(result, isA<Success<void>>());
    final settings = await repo.watchSettings().first;
    expect(settings.observesJumuah, isTrue);
    expect(settings.calculationMethod, CalculationMethod.karachi); // unchanged
  });

  test('markQadhaMakeup decrements the named counter by 1, clamped at 0', () async {
    await repo.watchQadhaCounters().first; // ensure seeded
    await repo.setQadhaBalance(PrayerName.fajr, 3);

    final result = await repo.markQadhaMakeup(PrayerName.fajr);
    expect(result, isA<Success<void>>());
    final counters = await repo.watchQadhaCounters().first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.fajr).count,
      2,
    );
  });

  test('setQadhaBalance clamps a negative input at 0', () async {
    await repo.watchQadhaCounters().first;
    await repo.setQadhaBalance(PrayerName.dhuhr, -5);
    final counters = await repo.watchQadhaCounters().first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.dhuhr).count,
      0,
    );
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: FAIL — `prayer_repository_impl.dart` doesn't exist.

- [ ] **Step 3: Write the implementation (settings/Qadha half)**

```dart
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/plan_prayer_materialization.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/qadha_adjustment.dart';

const _singletonId = 'singleton';
const _materializationWindowDays = 30;

/// Drift-backed [PrayerRepository]. No DAO — same precedent as Water/
/// Medicine, one caller.
class PrayerRepositoryImpl implements PrayerRepository {
  /// Creates a repository backed by [_db]. [defaultCalculationMethod]/
  /// [defaultAsrMethod] resolve the values a first-ever launch seeds the
  /// singleton row with — default to a device-locale heuristic (D-06:
  /// Bangladesh -> Karachi/Hanafi, else MWL/Standard), overridable for
  /// tests, same pattern as `SettingsRepositoryImpl`'s `defaultLocale`.
  PrayerRepositoryImpl(
    this._db, {
    CalculationMethod Function()? defaultCalculationMethod,
    AsrMethod Function()? defaultAsrMethod,
  }) : _defaultCalculationMethod =
           defaultCalculationMethod ?? _systemDefaultCalculationMethod,
       _defaultAsrMethod = defaultAsrMethod ?? _systemDefaultAsrMethod;

  final AppDatabase _db;
  final CalculationMethod Function() _defaultCalculationMethod;
  final AsrMethod Function() _defaultAsrMethod;

  static bool _isBangladeshLocale() =>
      PlatformDispatcher.instance.locale.countryCode == 'BD';

  static CalculationMethod _systemDefaultCalculationMethod() =>
      _isBangladeshLocale() ? CalculationMethod.karachi : CalculationMethod.mwl;

  static AsrMethod _systemDefaultAsrMethod() =>
      _isBangladeshLocale() ? AsrMethod.hanafi : AsrMethod.standard;

  @override
  Stream<PrayerSettings> watchSettings() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      final query = _db.select(_db.prayerSettingsTable)
        ..where((t) => t.id.equals(_singletonId));
      return query.watchSingle().map(_settingsFromRow);
    });
  }

  Future<void> _ensureSeeded() async {
    final existing = await (_db.select(
      _db.prayerSettingsTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing == null) {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await _db
          .into(_db.prayerSettingsTable)
          .insertOnConflictUpdate(
            PrayerSettingsTableCompanion.insert(
              id: _singletonId,
              calculationMethod: _defaultCalculationMethod().toDb(),
              asrMethod: _defaultAsrMethod().toDb(),
              locationMode: LocationMode.auto.toDb(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await _ensureQadhaCountersSeeded();
  }

  Future<void> _ensureQadhaCountersSeeded() async {
    final existing = await _db.select(_db.prayerQadhaCountersTable).get();
    final existingNames = existing.map((r) => r.prayerName).toSet();
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    for (final name in PrayerName.values) {
      if (existingNames.contains(name.toDb())) continue;
      await _db
          .into(_db.prayerQadhaCountersTable)
          .insertOnConflictUpdate(
            PrayerQadhaCountersTableCompanion.insert(
              id: generateId(),
              prayerName: name.toDb(),
              updatedAt: now,
            ),
          );
    }
  }

  @override
  Future<Result<void>> updateSettings({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
    bool? observesJumuah,
    LocationMode? locationMode,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    LocalTime? ishaDayRolloverTime,
    bool? notificationsEnabled,
    bool? preReminderEnabled,
    int? preReminderOffsetMinutes,
  }) async {
    try {
      await _ensureSeeded();
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerSettingsTable,
      )..where((t) => t.id.equals(_singletonId))).write(
        PrayerSettingsTableCompanion(
          calculationMethod: calculationMethod == null
              ? const Value.absent()
              : Value(calculationMethod.toDb()),
          asrMethod: asrMethod == null
              ? const Value.absent()
              : Value(asrMethod.toDb()),
          observesJumuah: observesJumuah == null
              ? const Value.absent()
              : Value(observesJumuah),
          locationMode: locationMode == null
              ? const Value.absent()
              : Value(locationMode.toDb()),
          manualLatitude: manualLatitude == null
              ? const Value.absent()
              : Value(manualLatitude),
          manualLongitude: manualLongitude == null
              ? const Value.absent()
              : Value(manualLongitude),
          manualTimezone: manualTimezone == null
              ? const Value.absent()
              : Value(manualTimezone),
          ishaDayRolloverTime: ishaDayRolloverTime == null
              ? const Value.absent()
              : Value(ishaDayRolloverTime.format()),
          notificationsEnabled: notificationsEnabled == null
              ? const Value.absent()
              : Value(notificationsEnabled),
          preReminderEnabled: preReminderEnabled == null
              ? const Value.absent()
              : Value(preReminderEnabled),
          preReminderOffsetMinutes: preReminderOffsetMinutes == null
              ? const Value.absent()
              : Value(preReminderOffsetMinutes),
          updatedAt: Value(nowMillis),
        ),
      );

      // FR-P-01: a location/method change recalculates all *future* prayer
      // times immediately — soft-delete future `upcoming` records so the
      // next materialization pass regenerates them (this plan's
      // refinements section, #3). Past/prayed/missed records are never
      // touched.
      final locationOrMethodChanged =
          calculationMethod != null ||
          asrMethod != null ||
          locationMode != null ||
          manualLatitude != null ||
          manualLongitude != null ||
          manualTimezone != null;
      if (locationOrMethodChanged) {
        await (_db.update(_db.prayerRecordsTable)..where(
          (t) =>
              t.status.equals('upcoming') &
              t.scheduledFor.isBiggerThanValue(now.toUtc().millisecondsSinceEpoch) &
              t.deletedAt.isNull(),
        )).write(
          PrayerRecordsTableCompanion(
            deletedAt: Value(nowMillis),
            updatedAt: Value(nowMillis),
          ),
        );
      }

      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_prayer_settings', e));
    }
  }

  @override
  Stream<List<PrayerQadhaCounter>> watchQadhaCounters() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      return _db.select(_db.prayerQadhaCountersTable).watch().map(
        (rows) => rows.map(_qadhaFromRow).toList(growable: false),
      );
    });
  }

  @override
  Future<Result<void>> markQadhaMakeup(PrayerName prayerName) async {
    try {
      await _ensureSeeded();
      final row = await (_db.select(
        _db.prayerQadhaCountersTable,
      )..where((t) => t.prayerName.equals(prayerName.toDb()))).getSingleOrNull();
      if (row == null) {
        return Result.failure(
          AppException.notFound('PrayerQadhaCounter', prayerName.toDb()),
        );
      }
      final newCount = applyQadhaMakeup(_qadhaFromRow(row));
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerQadhaCountersTable,
      )..where((t) => t.id.equals(row.id))).write(
        PrayerQadhaCountersTableCompanion(
          count: Value(newCount),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('mark_qadha_makeup', e));
    }
  }

  @override
  Future<Result<void>> setQadhaBalance(PrayerName prayerName, int count) async {
    try {
      await _ensureSeeded();
      final clamped = count < 0 ? 0 : count;
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.prayerQadhaCountersTable,
          )..where((t) => t.prayerName.equals(prayerName.toDb()))).write(
            PrayerQadhaCountersTableCompanion(
              count: Value(clamped),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(
          AppException.notFound('PrayerQadhaCounter', prayerName.toDb()),
        );
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('set_qadha_balance', e));
    }
  }

  PrayerSettings _settingsFromRow(PrayerSettingsRow row) => PrayerSettings(
    id: row.id,
    calculationMethod: CalculationMethodDb.fromDb(row.calculationMethod),
    asrMethod: AsrMethodDb.fromDb(row.asrMethod),
    observesJumuah: row.observesJumuah,
    locationMode: LocationModeDb.fromDb(row.locationMode),
    manualLatitude: row.manualLatitude,
    manualLongitude: row.manualLongitude,
    manualTimezone: row.manualTimezone,
    ishaDayRolloverTime: LocalTime.parse(row.ishaDayRolloverTime),
    notificationsEnabled: row.notificationsEnabled,
    preReminderEnabled: row.preReminderEnabled,
    preReminderOffsetMinutes: row.preReminderOffsetMinutes,
  );

  PrayerQadhaCounter _qadhaFromRow(PrayerQadhaCounterRow row) =>
      PrayerQadhaCounter(
        id: row.id,
        prayerName: PrayerNameDb.fromDb(row.prayerName),
        count: row.count,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
      );
}

/// `CalculationMethod` <-> DB string mapping, by explicit literal (never
/// `EnumName.values.byName`, so a stored value never silently breaks if
/// the enum is reordered).
extension CalculationMethodDb on CalculationMethod {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    CalculationMethod.mwl => 'mwl',
    CalculationMethod.isna => 'isna',
    CalculationMethod.egyptian => 'egyptian',
    CalculationMethod.ummAlQura => 'umm_al_qura',
    CalculationMethod.karachi => 'karachi',
    CalculationMethod.tehran => 'tehran',
    CalculationMethod.dubai => 'dubai',
    CalculationMethod.kuwait => 'kuwait',
    CalculationMethod.qatar => 'qatar',
    CalculationMethod.singapore => 'singapore',
  };

  /// Parses a stored DB string back to [CalculationMethod].
  static CalculationMethod fromDb(String value) => switch (value) {
    'isna' => CalculationMethod.isna,
    'egyptian' => CalculationMethod.egyptian,
    'umm_al_qura' => CalculationMethod.ummAlQura,
    'tehran' => CalculationMethod.tehran,
    'dubai' => CalculationMethod.dubai,
    'kuwait' => CalculationMethod.kuwait,
    'qatar' => CalculationMethod.qatar,
    'singapore' => CalculationMethod.singapore,
    'karachi' => CalculationMethod.karachi,
    _ => CalculationMethod.mwl,
  };
}

/// `AsrMethod` <-> DB string mapping, same convention as [CalculationMethodDb].
extension AsrMethodDb on AsrMethod {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    AsrMethod.standard => 'standard',
    AsrMethod.hanafi => 'hanafi',
  };

  /// Parses a stored DB string back to [AsrMethod].
  static AsrMethod fromDb(String value) => switch (value) {
    'hanafi' => AsrMethod.hanafi,
    _ => AsrMethod.standard,
  };
}

/// `LocationMode` <-> DB string mapping, same convention as [CalculationMethodDb].
extension LocationModeDb on LocationMode {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    LocationMode.auto => 'auto',
    LocationMode.manual => 'manual',
  };

  /// Parses a stored DB string back to [LocationMode].
  static LocationMode fromDb(String value) => switch (value) {
    'manual' => LocationMode.manual,
    _ => LocationMode.auto,
  };
}

/// `PrayerName` <-> DB string mapping, same convention as [CalculationMethodDb].
extension PrayerNameDb on PrayerName {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    PrayerName.fajr => 'fajr',
    PrayerName.dhuhr => 'dhuhr',
    PrayerName.asr => 'asr',
    PrayerName.maghrib => 'maghrib',
    PrayerName.isha => 'isha',
  };

  /// Parses a stored DB string back to [PrayerName].
  static PrayerName fromDb(String value) => switch (value) {
    'dhuhr' => PrayerName.dhuhr,
    'asr' => PrayerName.asr,
    'maghrib' => PrayerName.maghrib,
    'isha' => PrayerName.isha,
    _ => PrayerName.fajr,
  };
}

/// `PrayerStatus` <-> DB string mapping, same convention as [CalculationMethodDb].
extension PrayerStatusDb on PrayerStatus {
  /// The stored DB string for this value. `due` is never actually
  /// persisted (FR-P-07) — included here only so the mapping is total.
  String toDb() => switch (this) {
    PrayerStatus.upcoming => 'upcoming',
    PrayerStatus.due => 'due',
    PrayerStatus.prayed => 'prayed',
    PrayerStatus.missed => 'missed',
  };

  /// Parses a stored DB string back to [PrayerStatus].
  static PrayerStatus fromDb(String value) => switch (value) {
    'prayed' => PrayerStatus.prayed,
    'missed' => PrayerStatus.missed,
    'due' => PrayerStatus.due,
    _ => PrayerStatus.upcoming,
  };
}
```

Note: this file is not yet complete — `materializeRecords`,
`sweepMissedPrayers`, `watchRecordsForDay`, `recordsInRange`,
`markPrayed`, `unmarkPrayed`, `markMissedBySkip`, `allRecords` are added
by Tasks 12-13. Until then, `flutter analyze` will report "missing
implementation" errors for those; that's expected mid-plan (same
sequencing as Medicine's Tasks 9-11).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: PASS (5 tests) — the abstract-method compile errors for the
not-yet-implemented methods will surface as analyzer errors, not test
failures, until Task 12 adds stub/real bodies; add temporary
`UnimplementedError()`-throwing stubs for the remaining interface methods
now so this file compiles standalone:

```dart
  @override
  Future<void> materializeRecords(DateTime now, ResolvedLocation location) =>
      throw UnimplementedError();

  @override
  Future<void> sweepMissedPrayers(DateTime now, ResolvedLocation location) =>
      throw UnimplementedError();

  @override
  Stream<List<PrayerRecord>> watchRecordsForDay(LocalDate day) =>
      throw UnimplementedError();

  @override
  Future<List<PrayerRecord>> recordsInRange(LocalDate start, LocalDate end) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> markPrayed(String recordId) => throw UnimplementedError();

  @override
  Future<Result<void>> unmarkPrayed(String recordId) => throw UnimplementedError();

  @override
  Future<Result<void>> markMissedBySkip(String recordId) =>
      throw UnimplementedError();

  @override
  Future<List<PrayerRecord>> allRecords() => throw UnimplementedError();
```

Add these stub methods inside the `PrayerRepositoryImpl` class body
(after `setQadhaBalance`, before the private `_settingsFromRow` helper).

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/data/repositories/prayer_repository_impl.dart test/features/prayer/data/prayer_repository_impl_test.dart
git commit -m "feat(prayer): settings and Qadha-counter repository methods"
```

---

### Task 12: `PrayerRepositoryImpl` — materialization, sweep, and record queries

**Files:**
- Modify: `lib/features/prayer/data/repositories/prayer_repository_impl.dart`
- Modify: `test/features/prayer/data/prayer_repository_impl_test.dart`

**Interfaces:**
- Consumes: `planPrayerMaterialization` (Task 6), `cutoffForPrayer`
  (Task 4).
- Produces: real implementations of `materializeRecords`,
  `sweepMissedPrayers`, `watchRecordsForDay`, `recordsInRange` (replacing
  Task 11's stubs).

- [ ] **Step 1: Add failing tests**

Append to `test/features/prayer/data/prayer_repository_impl_test.dart`:

```dart
  test(
    'materializeRecords fills the window with 5 records/day and is '
    'idempotent on a second call',
    () async {
      const location = (
        latitude: 23.8103,
        longitude: 90.4125,
        ianaTimezone: 'Asia/Dhaka',
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await repo.materializeRecords(clock.now(), location);
      });
      final firstPass = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 7, 1),
      );
      expect(firstPass, hasLength(31 * 5));

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await repo.materializeRecords(clock.now(), location);
      });
      final secondPass = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 7, 1),
      );
      expect(secondPass, hasLength(31 * 5)); // unchanged, not duplicated
    },
  );

  test('watchRecordsForDay reflects a single day\'s 5 records', () async {
    const location = (
      latitude: 23.8103,
      longitude: 90.4125,
      ianaTimezone: 'Asia/Dhaka',
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    final records = await repo.watchRecordsForDay(const LocalDate(2026, 6, 1)).first;
    expect(records, hasLength(5));
  });

  test(
    'sweepMissedPrayers persists missed for a record past its cutoff and '
    'bumps its Qadha counter exactly once',
    () async {
      const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
        await repo.materializeRecords(clock.now(), location);
      });
      await repo.watchQadhaCounters().first; // ensure seeded

      // Far enough past every prayer's cutoff on 2026-06-01 that all 5
      // records should sweep to missed.
      final farFuture = DateTime.utc(2026, 6, 2, 23);
      await repo.sweepMissedPrayers(farFuture, location);

      final records = await repo.recordsInRange(
        const LocalDate(2026, 6, 1),
        const LocalDate(2026, 6, 1),
      );
      expect(records.every((r) => r.storedStatus == PrayerStatus.missed), isTrue);

      final counters = await repo.watchQadhaCounters().first;
      expect(counters.every((c) => c.count == 1), isTrue);

      // Idempotent: sweeping again doesn't double-bump.
      await repo.sweepMissedPrayers(farFuture, location);
      final countersAfterSecondSweep = await repo.watchQadhaCounters().first;
      expect(countersAfterSecondSweep.every((c) => c.count == 1), isTrue);
    },
  );
```

Add `import 'package:clock/clock.dart';` to the test file's imports.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: FAIL with `UnimplementedError`.

- [ ] **Step 3: Replace the stubs with real implementations**

Remove the four stub methods this task covers and replace with:

```dart
  @override
  Future<void> materializeRecords(
    DateTime now,
    ResolvedLocation location,
  ) async {
    final windowStart = LocalDate.fromDateTime(now.toUtc());
    final windowEnd = windowStart.addDays(_materializationWindowDays);
    final settings = await watchSettings().first;
    final existing = await recordsInRange(windowStart, windowEnd);

    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: existing,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    if (planned.isEmpty) return;

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final record in planned) {
        batch.insert(
          _db.prayerRecordsTable,
          PrayerRecordsTableCompanion.insert(
            id: generateId(),
            prayerDate: record.prayerDate.toIso(),
            prayerName: record.prayerName.toDb(),
            scheduledFor: record.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: 'upcoming',
            createdAt: nowMillis,
            updatedAt: nowMillis,
          ),
          // The (prayerDate, prayerName) unique index guards a race with a
          // concurrent materialization pass (e.g. app-resume firing at the
          // same moment as the WorkManager top-up).
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  @override
  Future<void> sweepMissedPrayers(
    DateTime now,
    ResolvedLocation location,
  ) async {
    final today = LocalDate.fromDateTime(
      now.toUtc(),
    );
    final scanStart = today.addDays(-1);
    final records = await recordsInRange(scanStart, today);
    if (records.isEmpty) return;

    final settings = await watchSettings().first;
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      byDay.putIfAbsent(record.prayerDate, () => []).add(record);
    }

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    for (final dayRecords in byDay.values) {
      dayRecords.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      for (final record in dayRecords) {
        if (record.storedStatus != PrayerStatus.upcoming) continue;
        final cutoff = cutoffForPrayer(
          record: record,
          sameDayRecordsSorted: dayRecords,
          ishaDayRolloverTime: settings.ishaDayRolloverTime,
          ianaTimezone: location.ianaTimezone,
        );
        if (!now.isAfter(cutoff)) continue;
        await (_db.update(
          _db.prayerRecordsTable,
        )..where((t) => t.id.equals(record.id))).write(
          PrayerRecordsTableCompanion(
            status: const Value('missed'),
            statusChangedAt: Value(nowMillis),
            updatedAt: Value(nowMillis),
          ),
        );
        await _bumpQadha(record.prayerName, now);
      }
    }
  }

  Future<void> _bumpQadha(PrayerName prayerName, DateTime now) async {
    final row = await (_db.select(
      _db.prayerQadhaCountersTable,
    )..where((t) => t.prayerName.equals(prayerName.toDb()))).getSingleOrNull();
    if (row == null) return; // seeded at first settings read; defensive no-op
    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.prayerQadhaCountersTable,
    )..where((t) => t.id.equals(row.id))).write(
      PrayerQadhaCountersTableCompanion(
        count: Value(row.count + 1),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  @override
  Stream<List<PrayerRecord>> watchRecordsForDay(LocalDate day) {
    final query = _db.select(_db.prayerRecordsTable)
      ..where((t) => t.deletedAt.isNull() & t.prayerDate.equals(day.toIso()))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]);
    return query.watch().map(
      (rows) => rows.map(_recordFromRow).toList(growable: false),
    );
  }

  @override
  Future<List<PrayerRecord>> recordsInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    final rows = await (_db.select(_db.prayerRecordsTable)..where(
          (t) =>
              t.deletedAt.isNull() &
              t.prayerDate.isBiggerOrEqualValue(start.toIso()) &
              t.prayerDate.isSmallerOrEqualValue(end.toIso()),
        ))
        .get();
    return rows.map(_recordFromRow).toList(growable: false);
  }
```

Add the row mapper next to `_settingsFromRow`/`_qadhaFromRow`:

```dart
  PrayerRecord _recordFromRow(PrayerRecordRow row) => PrayerRecord(
    id: row.id,
    prayerDate: LocalDate.parse(row.prayerDate),
    prayerName: PrayerNameDb.fromDb(row.prayerName),
    scheduledFor: DateTime.fromMillisecondsSinceEpoch(
      row.scheduledFor,
      isUtc: true,
    ),
    storedStatus: PrayerStatusDb.fromDb(row.status),
    statusChangedAt: row.statusChangedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.statusChangedAt!,
            isUtc: true,
          ),
  );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: PASS (8 tests total).

Run: `flutter analyze lib/features/prayer/`
Expected: errors remain only for the 4 still-stubbed methods (Task 13
replaces them) — no other issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/data/repositories/prayer_repository_impl.dart test/features/prayer/data/prayer_repository_impl_test.dart
git commit -m "feat(prayer): materialization, missed-prayer sweep, and record queries"
```

---

### Task 13: `PrayerRepositoryImpl` — mark actions and export support

**Files:**
- Modify: `lib/features/prayer/data/repositories/prayer_repository_impl.dart`
- Modify: `test/features/prayer/data/prayer_repository_impl_test.dart`

**Interfaces:**
- Produces: real implementations of `markPrayed`, `unmarkPrayed`,
  `markMissedBySkip`, `allRecords` (replacing Task 11's stubs) —
  completes `PrayerRepositoryImpl`.

- [ ] **Step 1: Add failing tests**

Append to `test/features/prayer/data/prayer_repository_impl_test.dart`:

```dart
  test('markPrayed marks a record prayed', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    final recordId = records.first.id;

    final result = await repo.markPrayed(recordId);
    expect(result, isA<Success<void>>());
    final updated = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    expect(
      updated.firstWhere((r) => r.id == recordId).storedStatus,
      PrayerStatus.prayed,
    );
  });

  test('unmarkPrayed reverts a prayed record to upcoming (toggle off)', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    final recordId = records.first.id;
    await repo.markPrayed(recordId);

    final result = await repo.unmarkPrayed(recordId);
    expect(result, isA<Success<void>>());
    final updated = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    expect(
      updated.firstWhere((r) => r.id == recordId).storedStatus,
      PrayerStatus.upcoming,
    );
  });

  test('markPrayed fails validation on an already-missed record', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    await repo.watchQadhaCounters().first;
    await repo.sweepMissedPrayers(DateTime.utc(2026, 6, 2, 23), location);
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    final missedId = records.first.id;

    final result = await repo.markPrayed(missedId);
    expect(result, isA<Failure<void>>());
  });

  test('markMissedBySkip marks missed and bumps the Qadha counter', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    await repo.watchQadhaCounters().first;
    final records = await repo.recordsInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    final fajr = records.firstWhere((r) => r.prayerName == PrayerName.fajr);

    final result = await repo.markMissedBySkip(fajr.id);
    expect(result, isA<Success<void>>());
    final counters = await repo.watchQadhaCounters().first;
    expect(
      counters.firstWhere((c) => c.prayerName == PrayerName.fajr).count,
      1,
    );
  });

  test('allRecords returns every non-deleted record', () async {
    const location = (latitude: 0.0, longitude: 0.0, ianaTimezone: 'UTC');
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 0)), () async {
      await repo.materializeRecords(clock.now(), location);
    });
    final all = await repo.allRecords();
    expect(all, hasLength(30 * 5));
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: FAIL with `UnimplementedError` on the remaining stubs.

- [ ] **Step 3: Replace the remaining stubs with real implementations**

```dart
  @override
  Future<Result<void>> markPrayed(String recordId) => _resolveRecord(
    recordId,
    guard: (record) => record.storedStatus != PrayerStatus.missed,
    apply: (record, nowMillis) => PrayerRecordsTableCompanion(
      status: const Value('prayed'),
      statusChangedAt: Value(nowMillis),
      updatedAt: Value(nowMillis),
    ),
  );

  @override
  Future<Result<void>> unmarkPrayed(String recordId) => _resolveRecord(
    recordId,
    guard: (record) => record.storedStatus == PrayerStatus.prayed,
    apply: (record, nowMillis) => PrayerRecordsTableCompanion(
      status: const Value('upcoming'),
      statusChangedAt: const Value(null),
      updatedAt: Value(nowMillis),
    ),
  );

  @override
  Future<Result<void>> markMissedBySkip(String recordId) async {
    final result = await _resolveRecord(
      recordId,
      guard: (record) => record.storedStatus == PrayerStatus.upcoming,
      apply: (record, nowMillis) => PrayerRecordsTableCompanion(
        status: const Value('missed'),
        statusChangedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
    if (result case Success()) {
      final record = await _recordById(recordId);
      if (record != null) await _bumpQadha(record.prayerName, clock.now());
    }
    return result;
  }

  Future<PrayerRecord?> _recordById(String id) async {
    final row = await (_db.select(
      _db.prayerRecordsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _recordFromRow(row);
  }

  /// Shared "look up record, check [guard], apply the write" skeleton for
  /// the three checklist/notification mark-action methods above.
  Future<Result<void>> _resolveRecord(
    String recordId, {
    required bool Function(PrayerRecord record) guard,
    required PrayerRecordsTableCompanion Function(
      PrayerRecord record,
      int nowMillis,
    )
    apply,
  }) async {
    try {
      final record = await _recordById(recordId);
      if (record == null) {
        return Result.failure(AppException.notFound('PrayerRecord', recordId));
      }
      if (!guard(record)) {
        return Result.failure(
          AppException.validation(
            'storedStatus',
            'Record is not in a valid state for this action',
          ),
        );
      }
      final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerRecordsTable,
      )..where((t) => t.id.equals(recordId))).write(apply(record, nowMillis));
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('resolve_prayer_record_action', e),
      );
    }
  }

  @override
  Future<List<PrayerRecord>> allRecords() async {
    final rows = await (_db.select(
      _db.prayerRecordsTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_recordFromRow).toList(growable: false);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/data/prayer_repository_impl_test.dart`
Expected: PASS (13 tests total).

Run: `flutter analyze lib/features/prayer/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/data/repositories/prayer_repository_impl.dart test/features/prayer/data/prayer_repository_impl_test.dart
git commit -m "feat(prayer): mark-prayed/skip actions and export support"
```

---

### Task 14: Bundled city asset + location resolver

**Files:**
- Create: `assets/data/prayer_cities.json`
- Create: `lib/features/prayer/data/prayer_cities_loader.dart`
- Create: `lib/features/prayer/data/location_resolver.dart`
- Test: `test/features/prayer/data/location_resolver_test.dart`

**Interfaces:**
- Consumes: `PrayerSettings`, `LocationMode`, `PrayerCity` (Task 2).
- Produces: `Future<List<PrayerCity>> loadPrayerCities()`,
  `Future<Result<ResolvedLocation>> resolveLocation(PrayerSettings
  settings)` — used by Task 15 (providers), Task 16 (`PrayerModule`).

- [ ] **Step 1: Write the bundled city list**

```json
[
  {"nameKey": "cityDhaka", "latitude": 23.8103, "longitude": 90.4125, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityChattogram", "latitude": 22.3569, "longitude": 91.7832, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityRajshahi", "latitude": 24.3745, "longitude": 88.6042, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityKhulna", "latitude": 22.8456, "longitude": 89.5403, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityBarishal", "latitude": 22.7010, "longitude": 90.3535, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "citySylhet", "latitude": 24.8949, "longitude": 91.8687, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityRangpur", "latitude": 25.7439, "longitude": 89.2752, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityMymensingh", "latitude": 24.7471, "longitude": 90.4203, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityGazipur", "latitude": 23.9999, "longitude": 90.4203, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityNarayanganj", "latitude": 23.6238, "longitude": 90.5000, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityCumilla", "latitude": 23.4607, "longitude": 91.1809, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityCoxsBazar", "latitude": 21.4272, "longitude": 92.0058, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityBogura", "latitude": 24.8465, "longitude": 89.3776, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityJashore", "latitude": 23.1667, "longitude": 89.2167, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityDinajpur", "latitude": 25.6217, "longitude": 88.6354, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityKushtia", "latitude": 23.9013, "longitude": 89.1206, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityPabna", "latitude": 24.0064, "longitude": 89.2372, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityTangail", "latitude": 24.2513, "longitude": 89.9167, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityFaridpur", "latitude": 23.6070, "longitude": 89.8429, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityNoakhali", "latitude": 22.8696, "longitude": 91.0995, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityFeni", "latitude": 23.0159, "longitude": 91.3976, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityBrahmanbaria", "latitude": 23.9571, "longitude": 91.1119, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityNarsingdi", "latitude": 23.9322, "longitude": 90.7150, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityManikganj", "latitude": 23.8644, "longitude": 90.0047, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityJamalpur", "latitude": 24.9375, "longitude": 89.9372, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityNetrokona", "latitude": 24.8700, "longitude": 90.7280, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityKishoreganj", "latitude": 24.4449, "longitude": 90.7766, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "citySatkhira", "latitude": 22.7185, "longitude": 89.0705, "ianaTimezone": "Asia/Dhaka"},
  {"nameKey": "cityMecca", "latitude": 21.3891, "longitude": 39.8579, "ianaTimezone": "Asia/Riyadh"},
  {"nameKey": "cityMedina", "latitude": 24.5247, "longitude": 39.5692, "ianaTimezone": "Asia/Riyadh"},
  {"nameKey": "cityJeddah", "latitude": 21.4858, "longitude": 39.1925, "ianaTimezone": "Asia/Riyadh"},
  {"nameKey": "cityRiyadh", "latitude": 24.7136, "longitude": 46.6753, "ianaTimezone": "Asia/Riyadh"},
  {"nameKey": "cityDammam", "latitude": 26.4207, "longitude": 50.0888, "ianaTimezone": "Asia/Riyadh"},
  {"nameKey": "cityCairo", "latitude": 30.0444, "longitude": 31.2357, "ianaTimezone": "Africa/Cairo"},
  {"nameKey": "cityAlexandria", "latitude": 31.2001, "longitude": 29.9187, "ianaTimezone": "Africa/Cairo"},
  {"nameKey": "cityIstanbul", "latitude": 41.0082, "longitude": 28.9784, "ianaTimezone": "Europe/Istanbul"},
  {"nameKey": "cityAnkara", "latitude": 39.9334, "longitude": 32.8597, "ianaTimezone": "Europe/Istanbul"},
  {"nameKey": "cityDubai", "latitude": 25.2048, "longitude": 55.2708, "ianaTimezone": "Asia/Dubai"},
  {"nameKey": "cityAbuDhabi", "latitude": 24.4539, "longitude": 54.3773, "ianaTimezone": "Asia/Dubai"},
  {"nameKey": "cityDoha", "latitude": 25.2854, "longitude": 51.5310, "ianaTimezone": "Asia/Qatar"},
  {"nameKey": "cityKuwaitCity", "latitude": 29.3759, "longitude": 47.9774, "ianaTimezone": "Asia/Kuwait"},
  {"nameKey": "cityManama", "latitude": 26.2285, "longitude": 50.5860, "ianaTimezone": "Asia/Bahrain"},
  {"nameKey": "cityMuscat", "latitude": 23.5859, "longitude": 58.4059, "ianaTimezone": "Asia/Muscat"},
  {"nameKey": "cityAmman", "latitude": 31.9454, "longitude": 35.9284, "ianaTimezone": "Asia/Amman"},
  {"nameKey": "cityBeirut", "latitude": 33.8938, "longitude": 35.5018, "ianaTimezone": "Asia/Beirut"},
  {"nameKey": "cityBaghdad", "latitude": 33.3152, "longitude": 44.3661, "ianaTimezone": "Asia/Baghdad"},
  {"nameKey": "cityTehran", "latitude": 35.6892, "longitude": 51.3890, "ianaTimezone": "Asia/Tehran"},
  {"nameKey": "cityKarachi", "latitude": 24.8607, "longitude": 67.0011, "ianaTimezone": "Asia/Karachi"},
  {"nameKey": "cityLahore", "latitude": 31.5497, "longitude": 74.3436, "ianaTimezone": "Asia/Karachi"},
  {"nameKey": "cityIslamabad", "latitude": 33.6844, "longitude": 73.0479, "ianaTimezone": "Asia/Karachi"},
  {"nameKey": "cityDelhi", "latitude": 28.6139, "longitude": 77.2090, "ianaTimezone": "Asia/Kolkata"},
  {"nameKey": "cityMumbai", "latitude": 19.0760, "longitude": 72.8777, "ianaTimezone": "Asia/Kolkata"},
  {"nameKey": "cityKualaLumpur", "latitude": 3.1390, "longitude": 101.6869, "ianaTimezone": "Asia/Kuala_Lumpur"},
  {"nameKey": "cityJakarta", "latitude": -6.2088, "longitude": 106.8456, "ianaTimezone": "Asia/Jakarta"},
  {"nameKey": "citySingapore", "latitude": 1.3521, "longitude": 103.8198, "ianaTimezone": "Asia/Singapore"},
  {"nameKey": "cityBangkok", "latitude": 13.7563, "longitude": 100.5018, "ianaTimezone": "Asia/Bangkok"},
  {"nameKey": "cityLondon", "latitude": 51.5074, "longitude": -0.1278, "ianaTimezone": "Europe/London"},
  {"nameKey": "cityManchester", "latitude": 53.4808, "longitude": -2.2426, "ianaTimezone": "Europe/London"},
  {"nameKey": "cityBirmingham", "latitude": 52.4862, "longitude": -1.8904, "ianaTimezone": "Europe/London"},
  {"nameKey": "cityParis", "latitude": 48.8566, "longitude": 2.3522, "ianaTimezone": "Europe/Paris"},
  {"nameKey": "cityBerlin", "latitude": 52.5200, "longitude": 13.4050, "ianaTimezone": "Europe/Berlin"},
  {"nameKey": "cityToronto", "latitude": 43.6532, "longitude": -79.3832, "ianaTimezone": "America/Toronto"},
  {"nameKey": "cityNewYork", "latitude": 40.7128, "longitude": -74.0060, "ianaTimezone": "America/New_York"},
  {"nameKey": "cityChicago", "latitude": 41.8781, "longitude": -87.6298, "ianaTimezone": "America/Chicago"},
  {"nameKey": "cityHouston", "latitude": 29.7604, "longitude": -95.3698, "ianaTimezone": "America/Chicago"},
  {"nameKey": "cityLosAngeles", "latitude": 34.0522, "longitude": -118.2437, "ianaTimezone": "America/Los_Angeles"},
  {"nameKey": "citySydney", "latitude": -33.8688, "longitude": 151.2093, "ianaTimezone": "Australia/Sydney"},
  {"nameKey": "cityMelbourne", "latitude": -37.8136, "longitude": 144.9631, "ianaTimezone": "Australia/Melbourne"}
]
```

- [ ] **Step 2: Write `prayer_cities_loader.dart`**

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';

/// Loads the bundled city picker list (`assets/data/prayer_cities.json`).
Future<List<PrayerCity>> loadPrayerCities() async {
  final raw = await rootBundle.loadString('assets/data/prayer_cities.json');
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((entry) {
        final map = entry as Map<String, dynamic>;
        return PrayerCity(
          nameKey: map['nameKey'] as String,
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          ianaTimezone: map['ianaTimezone'] as String,
        );
      })
      .toList(growable: false);
}
```

- [ ] **Step 3: Write the failing location-resolver tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';

void main() {
  test('manual mode resolves directly from settings fields', () async {
    const settings = PrayerSettings(
      id: 'singleton',
      calculationMethod: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
      locationMode: LocationMode.manual,
      manualLatitude: 23.8103,
      manualLongitude: 90.4125,
      manualTimezone: 'Asia/Dhaka',
    );
    final result = await resolveLocation(settings);
    expect(result, isA<Success<ResolvedLocation>>());
    final location = (result as Success<ResolvedLocation>).value;
    expect(location.latitude, 23.8103);
    expect(location.ianaTimezone, 'Asia/Dhaka');
  });

  test(
    'manual mode with an incomplete manual location fails validation',
    () async {
      const settings = PrayerSettings(
        id: 'singleton',
        calculationMethod: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
        locationMode: LocationMode.manual,
      );
      final result = await resolveLocation(settings);
      expect(result, isA<Failure<ResolvedLocation>>());
    },
  );
}
```

(Auto-mode's GPS path isn't covered here — `Geolocator`/`FlutterTimezone`
are platform channels with no fake registered in a plain `flutter_test`
run; it's covered instead by this run's manual smoke-test script, Task
23.)

- [ ] **Step 4: Run to verify they fail**

Run: `flutter test test/features/prayer/data/location_resolver_test.dart`
Expected: FAIL — `location_resolver.dart` doesn't exist.

- [ ] **Step 5: Write `location_resolver.dart`**

```dart
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';

/// Resolves prayer-time calculation location from [settings] (FR-P-06/
/// D-09) — a one-shot GPS fix + the OS's own timezone when
/// `locationMode == auto`, or the stored manual lat/long/timezone
/// otherwise. The sole file touching `geolocator`/`flutter_timezone`
/// directly, same "one file owns the plugin" precedent as
/// `core/notifications/notification_service.dart`.
Future<Result<ResolvedLocation>> resolveLocation(
  PrayerSettings settings,
) async {
  if (settings.locationMode == LocationMode.manual) {
    final lat = settings.manualLatitude;
    final long = settings.manualLongitude;
    final timezone = settings.manualTimezone;
    if (lat == null || long == null || timezone == null) {
      return const Result.failure(
        AppException.validation(
          'manualLocation',
          'Manual location mode requires latitude, longitude, and timezone',
        ),
      );
    }
    return Result.success((latitude: lat, longitude: long, ianaTimezone: timezone));
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const Result.failure(AppException.permission('location_service'));
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Result.failure(AppException.permission('location'));
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    final timezone = await FlutterTimezone.getLocalTimezone();
    return Result.success((
      latitude: position.latitude,
      longitude: position.longitude,
      ianaTimezone: timezone.identifier,
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/prayer/data/location_resolver_test.dart`
Expected: PASS (2 tests).

Run: `flutter analyze lib/features/prayer/`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add assets/data/prayer_cities.json lib/features/prayer/data/prayer_cities_loader.dart lib/features/prayer/data/location_resolver.dart test/features/prayer/data/location_resolver_test.dart
git commit -m "feat(prayer): bundled city list and location resolver"
```

---

### Task 15: Riverpod providers and controller

**Files:**
- Create: `lib/features/prayer/presentation/providers/prayer_providers.dart`
- Create: `lib/features/prayer/presentation/providers/prayer_controller.dart`

**Interfaces:**
- Consumes: `PrayerRepositoryImpl` (Tasks 11-13), `PrayerRepository`,
  entities (Task 2), `effectivePrayerStatus`/`cutoffForPrayer` (Task 4),
  `isJumuahDisplay` (Task 5), `resolveLocation` (Task 14),
  `loadPrayerCities` (Task 14).
- Produces: `prayerRepositoryProvider`, `prayerSettingsProvider`,
  `prayerQadhaCountersProvider`, `prayerCitiesProvider`,
  `resolvedPrayerLocationProvider`, `todaysPrayerRecordsProvider`,
  `prayerRecordsInRangeProvider({required LocalDate start, required
  LocalDate end})`, `todaysPrayerViewsProvider`, `PrayerRecordView`
  typedef, `prayerController` — consumed by every screen task.

- [ ] **Step 1: Write `prayer_providers.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/data/prayer_cities_loader.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prayer_providers.g.dart';

/// The Prayer module's [PrayerRepository].
@Riverpod(keepAlive: true)
PrayerRepository prayerRepository(Ref ref) {
  return PrayerRepositoryImpl(ref.watch(databaseProvider));
}

LocalDate _today() => localDayKey(clock.now());

/// The (auto-seeded) singleton settings row.
@riverpod
Stream<PrayerSettings> prayerSettings(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchSettings();
}

/// The five Qadha counters.
@riverpod
Stream<List<PrayerQadhaCounter>> prayerQadhaCounters(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchQadhaCounters();
}

/// The bundled city picker list, loaded once.
@Riverpod(keepAlive: true)
Future<List<PrayerCity>> prayerCities(Ref ref) => loadPrayerCities();

/// The currently resolved calculation location — re-resolves whenever
/// [prayerSettingsProvider] changes (e.g. switching location mode), or
/// `null` if resolution failed (permission denied, incomplete manual
/// entry) — callers show a "location unavailable" state rather than
/// crashing.
@riverpod
Future<ResolvedLocation?> resolvedPrayerLocation(Ref ref) async {
  final settings = await ref.watch(prayerSettingsProvider.future);
  final result = await resolveLocation(settings);
  return switch (result) {
    Success(:final value) => value,
    Failure() => null,
  };
}

/// Every (non-deleted) record with `prayerDate` in `[start, end]`
/// inclusive — used by the history calendar and stats screens.
@riverpod
Future<List<PrayerRecord>> prayerRecordsInRange(
  Ref ref, {
  required LocalDate start,
  required LocalDate end,
}) {
  return ref.watch(prayerRepositoryProvider).recordsInRange(start, end);
}

/// Today's five prayer records.
@riverpod
Stream<List<PrayerRecord>> todaysPrayerRecords(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchRecordsForDay(_today());
}

/// A prayer record paired with its live-derived status and Jumu'ah
/// display flag — what the checklist screen actually renders.
typedef PrayerRecordView = ({
  PrayerRecord record,
  PrayerStatus effectiveStatus,
  bool showAsJumuah,
});

/// Today's records, joined with derived status/display info, sorted by
/// scheduled time — or `null` while still loading.
@riverpod
List<PrayerRecordView>? todaysPrayerViews(Ref ref) {
  final records = ref.watch(todaysPrayerRecordsProvider).value;
  final settings = ref.watch(prayerSettingsProvider).value;
  if (records == null || settings == null) return null;
  final location = ref.watch(resolvedPrayerLocationProvider).value;
  final now = clock.now();
  final sorted = [...records]
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  return [
    for (final record in sorted)
      (
        record: record,
        effectiveStatus: effectivePrayerStatus(
          storedStatus: record.storedStatus,
          scheduledFor: record.scheduledFor,
          cutoff: cutoffForPrayer(
            record: record,
            sameDayRecordsSorted: sorted,
            ishaDayRolloverTime: settings.ishaDayRolloverTime,
            ianaTimezone: location?.ianaTimezone,
          ),
          now: now,
        ),
        showAsJumuah: isJumuahDisplay(
          prayerName: record.prayerName,
          date: record.prayerDate,
          observesJumuah: settings.observesJumuah,
        ),
      ),
  ];
}
```

- [ ] **Step 2: Write `prayer_controller.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prayer_controller.g.dart';

/// Mutation surface for the Prayer module — mirrors `MedicineController`'s
/// shape (no state of its own; screens watch the read providers in
/// `prayer_providers.dart`).
@Riverpod(keepAlive: true)
class PrayerController extends _$PrayerController {
  @override
  void build() {}

  /// Toggles a record's prayed status (FR-P-07 — one-tap toggle, not a
  /// multi-state cycle).
  Future<void> togglePrayed(
    String recordId, {
    required bool currentlyPrayed,
  }) async {
    final repository = ref.read(prayerRepositoryProvider);
    final result = currentlyPrayed
        ? await repository.unmarkPrayed(recordId)
        : await repository.markPrayed(recordId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Applies the "−1" Qadha make-up control (FR-P-05).
  Future<void> markQadhaMakeup(PrayerName prayerName) async {
    final result = await ref
        .read(prayerRepositoryProvider)
        .markQadhaMakeup(prayerName);
    if (result case Failure(:final error)) logException(error);
  }

  /// Sets a Qadha counter directly (FR-P-04's onboarding/Settings entry).
  Future<void> setQadhaBalance(PrayerName prayerName, int count) async {
    final result = await ref
        .read(prayerRepositoryProvider)
        .setQadhaBalance(prayerName, count);
    if (result case Failure(:final error)) logException(error);
  }

  /// Updates settings; only non-null arguments change. A location/method
  /// change re-materializes immediately afterward (rather than waiting
  /// for the next app-resume cycle) so the checklist reflects it right
  /// away — the repository has already cleared the stale future records
  /// as part of `updateSettings` itself (this plan's refinements
  /// section, #3).
  Future<void> updateSettings({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
    bool? observesJumuah,
    LocationMode? locationMode,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    LocalTime? ishaDayRolloverTime,
    bool? notificationsEnabled,
    bool? preReminderEnabled,
    int? preReminderOffsetMinutes,
  }) async {
    final repository = ref.read(prayerRepositoryProvider);
    final result = await repository.updateSettings(
      calculationMethod: calculationMethod,
      asrMethod: asrMethod,
      observesJumuah: observesJumuah,
      locationMode: locationMode,
      manualLatitude: manualLatitude,
      manualLongitude: manualLongitude,
      manualTimezone: manualTimezone,
      ishaDayRolloverTime: ishaDayRolloverTime,
      notificationsEnabled: notificationsEnabled,
      preReminderEnabled: preReminderEnabled,
      preReminderOffsetMinutes: preReminderOffsetMinutes,
    );
    if (result case Failure(:final error)) logException(error);
    ref.invalidate(resolvedPrayerLocationProvider);
    final location = await ref.read(resolvedPrayerLocationProvider.future);
    if (location != null) {
      await repository.materializeRecords(clock.now(), location);
    }
  }
}
```

- [ ] **Step 3: Generate Riverpod code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `prayer_providers.g.dart`/`prayer_controller.g.dart` generated,
no errors.

Run: `flutter analyze lib/features/prayer/presentation/providers/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/prayer/presentation/providers/
git commit -m "feat(prayer): Riverpod providers and controller"
```

---

### Task 16: `PrayerModule` (`HabitModule` registration) + wiring

**Files:**
- Create: `lib/features/prayer/prayer_module.dart`
- Test: `test/features/prayer/prayer_module_test.dart`
- Modify: `lib/core/modules/module_registry.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/notifications/notification_service.dart`
- Delete: `lib/features/prayer/presentation/screens/prayer_home_screen.dart` (placeholder — Task 17 recreates it for real)

**Interfaces:**
- Consumes: `PrayerRepository` (Tasks 11-13), `HabitModule`/
  `PendingNotification`/`NotificationActionType` (`core/modules/
  habit_module.dart`), `resolveLocation` (Task 14), `isJumuahDisplay`
  (Task 5), screens from Tasks 17-21 (this task wires their routes; the
  screens themselves land in those tasks — same forward-reference
  precedent as Medicine's Task 13).
- Produces: `PrayerModule` class, registered in `buildHabitModules`.

**Note on sequencing:** this task references `PrayerHomeScreen`,
`PrayerHistoryScreen`, `PrayerQadhaScreen`, `PrayerStatsScreen`,
`PrayerSettingsScreen` from Tasks 17-21. Implement this task's non-route
pieces (`pendingNotifications`, `onNotificationAction`, `exportData`/
`importData`, the module test) first and stub the 5 screens as trivial
placeholders so the app compiles, then Tasks 17-21 replace each stub with
the real screen.

- [ ] **Step 1: Write minimal screen stubs (Tasks 17-21 replace these)**

```dart
// lib/features/prayer/presentation/screens/prayer_home_screen.dart
import 'package:flutter/material.dart';

/// Stub — replaced by Task 17.
class PrayerHomeScreen extends StatelessWidget {
  /// Creates the stub.
  const PrayerHomeScreen({super.key, this.highlightRecordId});

  /// Record id to highlight when opened via a notification deep link.
  final String? highlightRecordId;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Repeat the same trivial `StatelessWidget` + `const Placeholder()` pattern
for:
- `lib/features/prayer/presentation/screens/prayer_history_screen.dart`
  (`PrayerHistoryScreen`, no constructor params)
- `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`
  (`PrayerQadhaScreen`, no constructor params)
- `lib/features/prayer/presentation/screens/prayer_stats_screen.dart`
  (`PrayerStatsScreen`, no constructor params)
- `lib/features/prayer/presentation/screens/prayer_settings_screen.dart`
  (`PrayerSettingsScreen`, no constructor params)

- [ ] **Step 2: Write the failing module test**

```dart
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;
  late PrayerModule module;

  setUpAll(() {
    registerFallbackValue(const LocalDate(2026, 1, 1));
  });

  setUp(() {
    repo = _MockPrayerRepository();
    module = PrayerModule(repo);
  });

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.manual,
    manualLatitude: 23.8103,
    manualLongitude: 90.4125,
    manualTimezone: 'Asia/Dhaka',
  );

  test(
    'pendingNotifications sweeps then materializes before querying, and '
    'maps upcoming records within 3 days to PendingNotification',
    () async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final record = PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.dhuhr,
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: PrayerStatus.upcoming,
      );

      when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));
      when(
        () => repo.sweepMissedPrayers(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.materializeRecords(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => [record]);

      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, hasLength(1));
        expect(notifications.single.sourceType, 'prayer_record');
        expect(notifications.single.deepLinkRoute, '/prayer/record/r1');
      });

      verifyInOrder([
        () => repo.sweepMissedPrayers(any(), any()),
        () => repo.materializeRecords(any(), any()),
      ]);
    },
  );

  test(
    'pendingNotifications includes a pre-reminder when preReminderEnabled',
    () async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final record = PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.dhuhr,
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: PrayerStatus.upcoming,
      );
      final settingsWithReminder = settings.copyWith(
        preReminderEnabled: true,
        preReminderOffsetMinutes: 10,
      );

      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => Stream.value(settingsWithReminder));
      when(
        () => repo.sweepMissedPrayers(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.materializeRecords(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => [record]);

      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, hasLength(2)); // on-time + pre-reminder
      });
    },
  );

  test('onNotificationAction(done) marks the record prayed', () async {
    when(
      () => repo.markPrayed(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('r1', NotificationActionType.done);

    verify(() => repo.markPrayed('r1')).called(1);
  });

  test(
    'onNotificationAction(skip) marks the record missed via markMissedBySkip',
    () async {
      when(
        () => repo.markMissedBySkip(any()),
      ).thenAnswer((_) async => const Result.success(null));

      await module.onNotificationAction('r1', NotificationActionType.skip);

      verify(() => repo.markMissedBySkip('r1')).called(1);
    },
  );

  test('onNotificationAction(snooze) never mutates record data', () async {
    await module.onNotificationAction('r1', NotificationActionType.snooze);
    verifyNever(() => repo.markPrayed(any()));
    verifyNever(() => repo.markMissedBySkip(any()));
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/features/prayer/prayer_module_test.dart`
Expected: FAIL — `prayer_module.dart` doesn't exist.

- [ ] **Step 4: Write `prayer_module.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_history_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_qadha_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_stats_screen.dart';

/// The Prayer module's [HabitModule] registration
/// (`technical/architecture.md`). Mirrors `MedicineModule`'s shape almost
/// exactly (`docs/superpowers/specs/2026-07-19-prayer-module-design.md`).
class PrayerModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const PrayerModule(this._repository);

  final PrayerRepository _repository;

  @override
  String get id => 'prayer';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Prayer',
    icon: Icons.mosque,
    accentColor: ModuleAccents.prayer,
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/prayer',
      builder: (context, state) => const PrayerHomeScreen(),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) => const PrayerHistoryScreen(),
        ),
        GoRoute(
          path: 'qadha',
          builder: (context, state) => const PrayerQadhaScreen(),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const PrayerStatsScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const PrayerSettingsScreen(),
        ),
        GoRoute(
          path: 'record/:id',
          builder: (context, state) => PrayerHomeScreen(
            highlightRecordId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
  ];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null || views.isEmpty) return const SizedBox.shrink();
    final next = views.firstWhere(
      (v) =>
          v.effectiveStatus == PrayerStatus.upcoming ||
          v.effectiveStatus == PrayerStatus.due,
      orElse: () => views.last,
    );
    final allPrayed = views.every((v) => v.effectiveStatus == PrayerStatus.prayed);
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: const Icon(Icons.mosque, color: ModuleAccents.prayer),
          title: Text(metadata.displayName),
          subtitle: Text(
            allPrayed
                ? 'All prayers done for today'
                : '${next.record.prayerName.name} next',
          ),
          onTap: () => context.go('/prayer'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) {
    return Builder(
      builder: (context) => ListTile(
        leading: const Icon(Icons.mosque, color: ModuleAccents.prayer),
        title: Text(metadata.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/prayer/settings'),
      ),
    );
  }

  static const _lookaheadDays = 3;

  /// Order matters (design spec): sweep before topping up, so a
  /// freshly-materialized `upcoming` row for today's already-past prayer
  /// is never possible. Resolves location once and threads it through
  /// both calls (this plan's refinements section, #2) — same "runs first
  /// thing, no new call site, reuses Run 08's app-resume/WorkManager
  /// triggers" precedent as Medicine.
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final now = clock.now();
    final settings = await _repository.watchSettings().first;
    final locationResult = await resolveLocation(settings);
    if (locationResult case Failure()) {
      return const []; // no location yet — nothing to schedule this cycle
    }
    final location = (locationResult as Success<ResolvedLocation>).value;

    await _repository.sweepMissedPrayers(now, location);
    await _repository.materializeRecords(now, location);

    if (!settings.notificationsEnabled) return const [];

    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final records = await _repository.recordsInRange(
      localDayKey(now),
      windowEnd,
    );
    final notifications = <PendingNotification>[];
    for (final record in records) {
      if (record.storedStatus != PrayerStatus.upcoming) continue;
      if (!record.scheduledFor.isAfter(now)) continue;
      final label = isJumuahDisplay(
        prayerName: record.prayerName,
        date: record.prayerDate,
        observesJumuah: settings.observesJumuah,
      )
          ? "Jumu'ah"
          : _titleCase(record.prayerName.name);
      notifications.add(
        PendingNotification(
          id: record.id,
          scheduledAt: record.scheduledFor,
          title: label,
          body: "It's time for $label prayer",
          sourceType: 'prayer_record',
          deepLinkRoute: '/prayer/record/${record.id}',
        ),
      );
      if (settings.preReminderEnabled) {
        final reminderAt = record.scheduledFor.subtract(
          Duration(minutes: settings.preReminderOffsetMinutes),
        );
        if (reminderAt.isAfter(now)) {
          notifications.add(
            PendingNotification(
              id: 'prayer_prereminder_${record.id}',
              scheduledAt: reminderAt,
              title: label,
              body: '$label prayer is coming up soon',
              sourceType: 'prayer_record',
              deepLinkRoute: '/prayer/record/${record.id}',
            ),
          );
        }
      }
    }
    return notifications;
  }

  String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    // Pre-reminder ids resolve back to the same underlying record.
    final recordId = sourceId.startsWith('prayer_prereminder_')
        ? sourceId.substring('prayer_prereminder_'.length)
        : sourceId;
    switch (action) {
      case NotificationActionType.done:
        await _repository.markPrayed(recordId);
      case NotificationActionType.skip:
        await _repository.markMissedBySkip(recordId);
      case NotificationActionType.snooze:
        break; // streak-neutral, same precedent as Water/Medicine.
    }
  }

  @override
  Future<ModuleExport> exportData() async {
    final settings = await _repository.watchSettings().first;
    final records = await _repository.allRecords();
    return ModuleExport({
      'settings': _settingsToJson(settings),
      'records': records.map(_recordToJson).toList(),
    });
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final settingsJson = data.payload['settings'] as Map<String, dynamic>?;
    if (settingsJson != null) {
      await _repository.updateSettings(
        calculationMethod: CalculationMethodDb.fromDb(
          settingsJson['calculationMethod'] as String,
        ),
        asrMethod: AsrMethodDb.fromDb(settingsJson['asrMethod'] as String),
        observesJumuah: settingsJson['observesJumuah'] as bool,
        locationMode: LocationModeDb.fromDb(
          settingsJson['locationMode'] as String,
        ),
        manualLatitude: (settingsJson['manualLatitude'] as num?)?.toDouble(),
        manualLongitude: (settingsJson['manualLongitude'] as num?)?.toDouble(),
        manualTimezone: settingsJson['manualTimezone'] as String?,
      );
    }
    // Historical records are informational-only export groundwork
    // (v1.1) — re-materialization regenerates future records from the
    // imported settings on the next `pendingNotifications()` cycle, so
    // records aren't re-inserted here.
  }

  Map<String, Object?> _settingsToJson(PrayerSettings settings) => {
    'calculationMethod': settings.calculationMethod.toDb(),
    'asrMethod': settings.asrMethod.toDb(),
    'observesJumuah': settings.observesJumuah,
    'locationMode': settings.locationMode.toDb(),
    'manualLatitude': settings.manualLatitude,
    'manualLongitude': settings.manualLongitude,
    'manualTimezone': settings.manualTimezone,
  };

  Map<String, Object?> _recordToJson(PrayerRecord record) => {
    'prayerDate': record.prayerDate.toIso(),
    'prayerName': record.prayerName.toDb(),
    'scheduledFor': record.scheduledFor.toIso8601String(),
    'status': record.storedStatus.toDb(),
  };
}
```

- [ ] **Step 5: Run the module test**

Run: `flutter test test/features/prayer/prayer_module_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Register in `module_registry.dart`**

In `lib/core/modules/module_registry.dart`, add the import and include
`PrayerModule` in the returned list:

```dart
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
```

```dart
List<HabitModule> buildHabitModules(AppDatabase db) {
  return [
    MedicineModule(MedicineRepositoryImpl(db)),
    WaterModule(WaterRepositoryImpl(db)),
    PrayerModule(PrayerRepositoryImpl(db)),
  ];
}
```

- [ ] **Step 7: Wire the real routes into `app_router.dart`**

In `lib/core/router/app_router.dart`, remove the
`import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';`
import and the placeholder `PrayerHomeScreen()` branch; mirror how
Water's/Medicine's branches are built:

```dart
  final waterRoutes = modules.firstWhere((m) => m.id == 'water').routes;
  final medicineRoutes = modules.firstWhere((m) => m.id == 'medicine').routes;
  final prayerRoutes = modules.firstWhere((m) => m.id == 'prayer').routes;
```

and replace the Prayer `StatefulShellBranch` body with:

```dart
          StatefulShellBranch(routes: prayerRoutes),
```

- [ ] **Step 8: Register the Android notification channel**

In `lib/core/notifications/notification_service.dart`, add a `prayer`
entry to `notificationChannels`:

```dart
const Map<String, AndroidNotificationChannel> notificationChannels = {
  'water': AndroidNotificationChannel(
    'water_reminders',
    'Water reminders',
    description: 'Reminders to log your water intake',
  ),
  'medicine': AndroidNotificationChannel(
    'medicine_reminders',
    'Medicine reminders',
    description: 'Reminders to take your medicine and low-stock alerts',
  ),
  'prayer': AndroidNotificationChannel(
    'prayer_reminders',
    'Prayer reminders',
    description: 'Prayer-time notifications and pre-prayer reminders',
  ),
};
```

- [ ] **Step 9: Verify the app compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/prayer/prayer_module.dart lib/features/prayer/presentation/screens/ test/features/prayer/prayer_module_test.dart lib/core/modules/module_registry.dart lib/core/router/app_router.dart lib/core/notifications/notification_service.dart
git commit -m "feat(prayer): HabitModule registration, notification wiring, and routing"
```

---

### Task 17: Prayer checklist screen (today's five/six prayers)

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_home_screen.dart` (replaces Task 16's stub)
- Create: `lib/features/prayer/presentation/widgets/prayer_tile.dart`
- Test: `test/features/prayer/presentation/prayer_home_screen_test.dart`

**Interfaces:**
- Consumes: `todaysPrayerViewsProvider`, `PrayerRecordView`
  (`prayer_providers.dart`, Task 15), `prayerControllerProvider` (Task
  15).
- Produces: `PrayerTile` widget, the real `PrayerHomeScreen`. All display
  strings are hardcoded English literals in this task — Task 22
  (localization) replaces them with `AppLocalizations` calls (same
  ordering Medicine's Tasks 14/19 used).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.manual,
    manualLatitude: 23.8103,
    manualLongitude: 90.4125,
    manualTimezone: 'Asia/Dhaka',
  );

  setUp(() {
    repo = _MockPrayerRepository();
  });

  Widget buildApp() => ProviderScope(
    overrides: [prayerRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: PrayerHomeScreen()),
  );

  testWidgets('shows the empty state when there are no records today', (
    tester,
  ) async {
    when(
      () => repo.watchRecordsForDay(any()),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 6)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
    });

    expect(find.text('No prayers scheduled for today'), findsOneWidget);
  });

  testWidgets('shows a tile per record, labeled by prayer name', (
    tester,
  ) async {
    final records = [
      PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 6, 1, 0),
        storedStatus: PrayerStatus.upcoming,
      ),
    ];
    when(
      () => repo.watchRecordsForDay(any()),
    ).thenAnswer((_) => Stream.value(records));
    when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
    });

    expect(find.text('Fajr'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/prayer/presentation/prayer_home_screen_test.dart`
Expected: FAIL — the stub `PrayerHomeScreen` renders `Placeholder`, not
the expected text.

- [ ] **Step 3: Write `prayer_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:intl/intl.dart';

/// One row of the checklist (FR-P-07) — a prayer's display label,
/// scheduled time, live status, and a tap-to-mark-prayed toggle (only
/// while not yet `missed` — the toggle is a one-tap "Prayed" action,
/// never a manual "missed" tap target).
class PrayerTile extends StatelessWidget {
  /// Creates a prayer tile.
  const PrayerTile({
    required this.view,
    required this.onToggle,
    this.highlighted = false,
    super.key,
  });

  /// The record view to render.
  final PrayerRecordView view;

  /// Called when the user taps the "Prayed" toggle.
  final VoidCallback onToggle;

  /// Whether this tile should be visually highlighted (notification
  /// deep-link target).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = theme.extension<AppSemanticColors>()!.success;
    final label = view.showAsJumuah ? "Jumu'ah" : _labelFor(view.record.prayerName);
    final canToggle = view.effectiveStatus != PrayerStatus.missed;
    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          '${DateFormat.jm().format(view.record.scheduledFor.toLocal())} · '
          '${_statusLabel(view.effectiveStatus)}',
        ),
        trailing: canToggle
            ? IconButton(
                icon: Icon(
                  view.effectiveStatus == PrayerStatus.prayed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: view.effectiveStatus == PrayerStatus.prayed
                      ? success
                      : null,
                ),
                onPressed: onToggle,
              )
            : const Icon(Icons.cancel_outlined),
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  String _statusLabel(PrayerStatus status) => switch (status) {
    PrayerStatus.upcoming => 'Upcoming',
    PrayerStatus.due => 'Due',
    PrayerStatus.prayed => 'Prayed',
    PrayerStatus.missed => 'Missed',
  };
}
```

- [ ] **Step 4: Write the real `prayer_home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/widgets/prayer_tile.dart';

/// Today's prayer checklist — countdown to next prayer (via each tile's
/// live status), Gregorian date, tap-to-mark-prayed toggle (FR-P-07).
class PrayerHomeScreen extends ConsumerWidget {
  /// Creates the checklist screen.
  const PrayerHomeScreen({super.key, this.highlightRecordId});

  /// Record id to highlight when opened via a notification deep link.
  final String? highlightRecordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'History',
            onPressed: () => context.push('/prayer/history'),
          ),
          IconButton(
            icon: const Icon(Icons.pending_actions),
            tooltip: 'Qadha',
            onPressed: () => context.push('/prayer/qadha'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => context.push('/prayer/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/prayer/settings'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? const Center(child: Text('No prayers scheduled for today'))
          : ListView.builder(
              itemCount: views.length,
              itemBuilder: (context, index) {
                final view = views[index];
                return PrayerTile(
                  view: view,
                  highlighted: view.record.id == highlightRecordId,
                  onToggle: () => ref
                      .read(prayerControllerProvider.notifier)
                      .togglePrayed(
                        view.record.id,
                        currentlyPrayed:
                            view.effectiveStatus == PrayerStatus.prayed,
                      ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/prayer/presentation/prayer_home_screen_test.dart`
Expected: PASS (2 tests).

Run: `flutter analyze lib/features/prayer/presentation/`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_home_screen.dart lib/features/prayer/presentation/widgets/prayer_tile.dart test/features/prayer/presentation/prayer_home_screen_test.dart
git commit -m "feat(prayer): checklist screen with tap-to-mark-prayed toggle"
```

---

### Task 18: Prayer history calendar screen

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_history_screen.dart` (replaces Task 16's stub)

**Interfaces:**
- Consumes: `prayerRecordsInRangeProvider` (Task 15).
- Produces: the real `PrayerHistoryScreen` (per-day completion coloring +
  day drill-down).

- [ ] **Step 1: Write the real screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Per-day completion coloring + day drill-down, visualizing FR-P-09's
/// streak data over a calendar month.
class PrayerHistoryScreen extends ConsumerStatefulWidget {
  /// Creates the history screen.
  const PrayerHistoryScreen({super.key});

  @override
  ConsumerState<PrayerHistoryScreen> createState() =>
      _PrayerHistoryScreenState();
}

class _PrayerHistoryScreenState extends ConsumerState<PrayerHistoryScreen> {
  DateTime _visibleMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final monthStart = LocalDate(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final monthEnd = LocalDate(_visibleMonth.year, _visibleMonth.month, daysInMonth);
    final recordsAsync = ref.watch(
      prayerRecordsInRangeProvider(start: monthStart, end: monthEnd),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
            }),
          ),
        ],
      ),
      body: recordsAsync.when(
        data: (records) {
          final byDay = <LocalDate, List<PrayerRecord>>{};
          for (final record in records) {
            byDay.putIfAbsent(record.prayerDate, () => []).add(record);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = LocalDate(
                _visibleMonth.year,
                _visibleMonth.month,
                index + 1,
              );
              final dayRecords = byDay[day] ?? const [];
              final allPrayed =
                  dayRecords.length == 5 &&
                  dayRecords.every((r) => r.storedStatus == PrayerStatus.prayed);
              final anyMissed = dayRecords.any(
                (r) => r.storedStatus == PrayerStatus.missed,
              );
              final color = allPrayed
                  ? Theme.of(context).extension<AppSemanticColors>()!.success
                  : anyMissed
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest;
              return InkWell(
                onTap: dayRecords.isEmpty
                    ? null
                    : () => _showDayDetail(context, dayRecords),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  color: color,
                  alignment: Alignment.center,
                  child: Text('${index + 1}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  void _showDayDetail(BuildContext context, List<PrayerRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final record in sorted)
            ListTile(
              title: Text(_labelFor(record.prayerName)),
              trailing: Text(_statusLabel(record.storedStatus)),
            ),
        ],
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  String _statusLabel(PrayerStatus status) => switch (status) {
    PrayerStatus.upcoming => 'Upcoming',
    PrayerStatus.due => 'Due',
    PrayerStatus.prayed => 'Prayed',
    PrayerStatus.missed => 'Missed',
  };
}
```

- [ ] **Step 2: Verify it compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_history_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_history_screen.dart
git commit -m "feat(prayer): history calendar with per-day coloring and drill-down"
```

---

### Task 19: Qadha screen

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart` (replaces Task 16's stub)

**Interfaces:**
- Consumes: `prayerQadhaCountersProvider`, `prayerControllerProvider`
  (Task 15).
- Produces: the real `PrayerQadhaScreen` (five counters, "−1" make-up
  control, manual balance entry — FR-P-04/05).

- [ ] **Step 1: Write the real screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Five Qadha counters with a "−1" make-up control and manual balance
/// entry (FR-P-04/05).
class PrayerQadhaScreen extends ConsumerWidget {
  /// Creates the Qadha screen.
  const PrayerQadhaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Qadha')),
      body: ListView(
        children: [
          for (final counter in counters)
            ListTile(
              title: Text(_labelFor(counter.prayerName)),
              subtitle: Text('${counter.count} owed'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Mark one made up',
                    onPressed: counter.count == 0
                        ? null
                        : () => ref
                              .read(prayerControllerProvider.notifier)
                              .markQadhaMakeup(counter.prayerName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Set balance',
                    onPressed: () => _showEditDialog(context, ref, counter),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    PrayerQadhaCounter counter,
  ) async {
    final controller = TextEditingController(text: counter.count.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Qadha balance'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(prayerControllerProvider.notifier)
          .setQadhaBalance(counter.prayerName, result);
    }
  }
}
```

- [ ] **Step 2: Verify it compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_qadha_screen.dart
git commit -m "feat(prayer): Qadha screen with make-up control and manual balance entry"
```

---

### Task 20: Stats screen

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_stats_screen.dart` (replaces Task 16's stub)

**Interfaces:**
- Consumes: `prayerRecordsInRangeProvider`, `prayerQadhaCountersProvider`
  (Task 15), `CalculatePrayerStreakUseCase` (Task 7), `calculateAdherence`
  (Task 9), `PeriodBarChart`/`BarChartPoint`
  (`core/widgets/charts/period_bar_chart.dart`).
- Produces: the real `PrayerStatsScreen` (streak, longest streak,
  per-prayer on-time %, Qadha summary — FR-P-10).

- [ ] **Step 1: Write the real screen**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_adherence.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Streak, longest streak, per-prayer on-time %, Qadha summary (FR-P-10).
/// Reuses `core/widgets/charts/period_bar_chart.dart`.
class PrayerStatsScreen extends ConsumerWidget {
  /// Creates the stats screen.
  const PrayerStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    final rangeStart = today.addDays(-29);
    final recordsAsync = ref.watch(
      prayerRecordsInRangeProvider(start: rangeStart, end: today),
    );
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer stats')),
      body: recordsAsync.when(
        data: (records) {
          final byDay = <LocalDate, List<PrayerRecord>>{};
          for (final record in records) {
            byDay.putIfAbsent(record.prayerDate, () => []).add(record);
          }
          final streak = const CalculatePrayerStreakUseCase().execute(
            recordsByDay: byDay,
            earliestDay: rangeStart,
            today: today,
          );
          final adherence = calculateAdherence(records: records);
          final points = [
            for (var offset = 6; offset >= 0; offset--)
              BarChartPoint(
                label: today.addDays(-offset).day.toString(),
                value: (byDay[today.addDays(-offset)] ?? const [])
                    .where((r) => r.storedStatus == PrayerStatus.prayed)
                    .length
                    .toDouble(),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Current streak: ${streak.current} days'),
              Text('Longest streak: ${streak.longest} days'),
              const SizedBox(height: 16),
              const Text('Prayers completed, last 7 days'),
              PeriodBarChart(
                points: points,
                color: ModuleAccents.prayer,
                targetLine: 5,
              ),
              const SizedBox(height: 16),
              const Text('Qadha summary'),
              for (final counter in counters)
                Text('${_labelFor(counter.prayerName)}: ${counter.count}'),
              const SizedBox(height: 16),
              const Text('On-time %, last 30 days'),
              for (final entry in adherence.entries)
                Text(
                  '${_labelFor(entry.key)}: '
                  '${entry.value.total == 0 ? 0 : (entry.value.prayed * 100 / entry.value.total).round()}%',
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };
}
```

- [ ] **Step 2: Verify it compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_stats_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_stats_screen.dart
git commit -m "feat(prayer): stats screen with streak, on-time %, and Qadha summary"
```

---

### Task 21: Settings screen

**Files:**
- Modify: `lib/features/prayer/presentation/screens/prayer_settings_screen.dart` (replaces Task 16's stub)

**Interfaces:**
- Consumes: `prayerSettingsProvider`, `prayerCitiesProvider`,
  `prayerControllerProvider` (Task 15).
- Produces: the real `PrayerSettingsScreen` (calculation method, Asr
  madhab, Jumu'ah toggle, location, reminders, Isha day-rollover time,
  "using manual location" banner — D-09).

- [ ] **Step 1: Write the real screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Calculation method, Asr madhab, Jumu'ah toggle, location, reminders,
/// Isha day-rollover time, and the "using manual location" banner (D-09).
class PrayerSettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerSettingsProvider).value;
    final cities = ref.watch(prayerCitiesProvider).value ?? const [];
    final controller = ref.read(prayerControllerProvider.notifier);
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prayer settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer settings')),
      body: ListView(
        children: [
          if (settings.locationMode == LocationMode.manual)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: const Text('Using manual location'),
            ),
          ListTile(
            title: const Text('Calculation method'),
            trailing: DropdownButton<CalculationMethod>(
              value: settings.calculationMethod,
              items: [
                for (final method in CalculationMethod.values)
                  DropdownMenuItem(value: method, child: Text(method.name)),
              ],
              onChanged: (method) {
                if (method != null) {
                  controller.updateSettings(calculationMethod: method);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Asr method'),
            trailing: DropdownButton<AsrMethod>(
              value: settings.asrMethod,
              items: const [
                DropdownMenuItem(value: AsrMethod.standard, child: Text('Standard')),
                DropdownMenuItem(value: AsrMethod.hanafi, child: Text('Hanafi')),
              ],
              onChanged: (method) {
                if (method != null) controller.updateSettings(asrMethod: method);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Observe Jumu\'ah'),
            value: settings.observesJumuah,
            onChanged: (value) => controller.updateSettings(observesJumuah: value),
          ),
          ListTile(
            title: const Text('Location'),
            trailing: DropdownButton<LocationMode>(
              value: settings.locationMode,
              items: const [
                DropdownMenuItem(value: LocationMode.auto, child: Text('Automatic (GPS)')),
                DropdownMenuItem(value: LocationMode.manual, child: Text('Manual')),
              ],
              onChanged: (mode) {
                if (mode != null) controller.updateSettings(locationMode: mode);
              },
            ),
          ),
          if (settings.locationMode == LocationMode.manual)
            ListTile(
              title: const Text('City'),
              trailing: DropdownButton<PrayerCity>(
                items: [
                  for (final city in cities)
                    DropdownMenuItem(value: city, child: Text(city.nameKey)),
                ],
                onChanged: (city) {
                  if (city != null) {
                    controller.updateSettings(
                      manualLatitude: city.latitude,
                      manualLongitude: city.longitude,
                      manualTimezone: city.ianaTimezone,
                    );
                  }
                },
              ),
            ),
          SwitchListTile(
            title: const Text('Prayer-time notifications'),
            value: settings.notificationsEnabled,
            onChanged: (value) =>
                controller.updateSettings(notificationsEnabled: value),
          ),
          SwitchListTile(
            title: const Text('Pre-prayer reminder'),
            value: settings.preReminderEnabled,
            onChanged: (value) =>
                controller.updateSettings(preReminderEnabled: value),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/prayer/presentation/screens/prayer_settings_screen.dart
git commit -m "feat(prayer): settings screen for method/madhab/Jumu'ah/location/reminders"
```

---

### Task 22: Localization (en + bn)

**Files:**
- Modify: `lib/core/l10n/app_en.arb`
- Modify: `lib/core/l10n/app_bn.arb`
- Create: `lib/features/prayer/presentation/prayer_city_labels.dart`
- Modify: every screen/widget from Tasks 17-21 that currently uses a
  hardcoded English string literal (replace with
  `AppLocalizations.of(context)!.<key>`)

**Interfaces:**
- Produces: `prayerHome*`, `prayerHistory*`, `prayerQadha*`,
  `prayerStats*`, `prayerSettings*`, `prayerName*`, `prayerStatus*`,
  `calcMethod*`, and `city*` keys, following the exact `medicine*`-key
  convention already in `app_en.arb`; `cityDisplayName(AppLocalizations,
  String)` — resolves a bundled city's `nameKey` to its localized name.

- [ ] **Step 1: Add English keys to `app_en.arb`**

Add these entries (alongside the existing `medicine*` block, same
`"key": "value"` + `"@key": {"description": "..."}` pairing style):

```json
  "prayerHomeTitle": "Prayer",
  "@prayerHomeTitle": {"description": "Title of the prayer checklist screen."},
  "prayerHomeHistoryButton": "History",
  "@prayerHomeHistoryButton": {"description": "Button that navigates to the prayer history screen."},
  "prayerHomeQadhaButton": "Qadha",
  "@prayerHomeQadhaButton": {"description": "Button that navigates to the Qadha screen."},
  "prayerHomeStatsButton": "Stats",
  "@prayerHomeStatsButton": {"description": "Button that navigates to the prayer stats screen."},
  "prayerHomeSettingsButton": "Settings",
  "@prayerHomeSettingsButton": {"description": "Button that navigates to the prayer settings screen."},
  "prayerHomeEmpty": "No prayers scheduled for today",
  "@prayerHomeEmpty": {"description": "Shown on the checklist when there are no records today."},
  "prayerNameFajr": "Fajr",
  "@prayerNameFajr": {"description": "Prayer name: Fajr."},
  "prayerNameDhuhr": "Dhuhr",
  "@prayerNameDhuhr": {"description": "Prayer name: Dhuhr."},
  "prayerNameAsr": "Asr",
  "@prayerNameAsr": {"description": "Prayer name: Asr."},
  "prayerNameMaghrib": "Maghrib",
  "@prayerNameMaghrib": {"description": "Prayer name: Maghrib."},
  "prayerNameIsha": "Isha",
  "@prayerNameIsha": {"description": "Prayer name: Isha."},
  "prayerNameJumuah": "Jumu'ah",
  "@prayerNameJumuah": {"description": "Friday display label for Dhuhr when observesJumuah is on."},
  "prayerStatusUpcoming": "Upcoming",
  "@prayerStatusUpcoming": {"description": "Label for a prayer not yet due."},
  "prayerStatusDue": "Due",
  "@prayerStatusDue": {"description": "Label for a prayer within its current window."},
  "prayerStatusPrayed": "Prayed",
  "@prayerStatusPrayed": {"description": "Label for a prayer marked prayed."},
  "prayerStatusMissed": "Missed",
  "@prayerStatusMissed": {"description": "Label for a prayer past its cutoff, unactioned."},
  "prayerHistoryTitle": "History",
  "@prayerHistoryTitle": {"description": "Title of the prayer history calendar screen."},
  "prayerQadhaTitle": "Qadha",
  "@prayerQadhaTitle": {"description": "Title of the Qadha screen."},
  "prayerQadhaCountLabel": "{count} owed",
  "@prayerQadhaCountLabel": {
    "description": "Current Qadha balance for one prayer.",
    "placeholders": {"count": {"type": "int"}}
  },
  "prayerQadhaMakeupButton": "Mark one made up",
  "@prayerQadhaMakeupButton": {"description": "Tooltip for the -1 Qadha make-up control."},
  "prayerQadhaEditButton": "Set balance",
  "@prayerQadhaEditButton": {"description": "Tooltip/title for the manual Qadha balance entry dialog."},
  "prayerStatsTitle": "Prayer stats",
  "@prayerStatsTitle": {"description": "Title of the prayer stats screen."},
  "prayerStatsCurrentStreak": "Current streak: {days} days",
  "@prayerStatsCurrentStreak": {
    "description": "Current streak display.",
    "placeholders": {"days": {"type": "int"}}
  },
  "prayerStatsLongestStreak": "Longest streak: {days} days",
  "@prayerStatsLongestStreak": {
    "description": "Longest streak display.",
    "placeholders": {"days": {"type": "int"}}
  },
  "prayerStatsLast7DaysLabel": "Prayers completed, last 7 days",
  "@prayerStatsLast7DaysLabel": {"description": "Section header for the completed-prayers chart."},
  "prayerStatsQadhaSummaryLabel": "Qadha summary",
  "@prayerStatsQadhaSummaryLabel": {"description": "Section header for the Qadha counters summary."},
  "prayerStatsOnTimeLabel": "On-time %, last 30 days",
  "@prayerStatsOnTimeLabel": {"description": "Section header for the per-prayer on-time percentage list."},
  "prayerSettingsTitle": "Prayer settings",
  "@prayerSettingsTitle": {"description": "Title of the prayer settings screen."},
  "prayerSettingsMethodLabel": "Calculation method",
  "@prayerSettingsMethodLabel": {"description": "Label for the calculation-method dropdown."},
  "prayerSettingsAsrLabel": "Asr method",
  "@prayerSettingsAsrLabel": {"description": "Label for the Asr madhab dropdown."},
  "prayerSettingsAsrStandard": "Standard",
  "@prayerSettingsAsrStandard": {"description": "Asr method option: Standard (Shafi'i/Maliki/Hanbali)."},
  "prayerSettingsAsrHanafi": "Hanafi",
  "@prayerSettingsAsrHanafi": {"description": "Asr method option: Hanafi."},
  "prayerSettingsJumuahLabel": "Observe Jumu'ah",
  "@prayerSettingsJumuahLabel": {"description": "Switch label for the Jumu'ah display toggle."},
  "prayerSettingsLocationModeLabel": "Location",
  "@prayerSettingsLocationModeLabel": {"description": "Label for the location-mode dropdown."},
  "prayerSettingsLocationAuto": "Automatic (GPS)",
  "@prayerSettingsLocationAuto": {"description": "Location mode option: one-shot GPS fix."},
  "prayerSettingsLocationManual": "Manual",
  "@prayerSettingsLocationManual": {"description": "Location mode option: fixed city/lat-long."},
  "prayerSettingsCityPickerLabel": "City",
  "@prayerSettingsCityPickerLabel": {"description": "Label for the bundled city picker dropdown."},
  "prayerSettingsManualLocationBanner": "Using manual location",
  "@prayerSettingsManualLocationBanner": {"description": "Persistent banner shown while locationMode is manual (D-09)."},
  "prayerSettingsNotificationsLabel": "Prayer-time notifications",
  "@prayerSettingsNotificationsLabel": {"description": "Switch label for the on-time prayer notification."},
  "prayerSettingsPreReminderLabel": "Pre-prayer reminder",
  "@prayerSettingsPreReminderLabel": {"description": "Switch label for the optional pre-prayer reminder."},
  "calcMethodMwl": "Muslim World League",
  "@calcMethodMwl": {"description": "Calculation method name."},
  "calcMethodIsna": "Islamic Society of North America",
  "@calcMethodIsna": {"description": "Calculation method name."},
  "calcMethodEgyptian": "Egyptian General Authority",
  "@calcMethodEgyptian": {"description": "Calculation method name."},
  "calcMethodUmmAlQura": "Umm al-Qura, Makkah",
  "@calcMethodUmmAlQura": {"description": "Calculation method name."},
  "calcMethodKarachi": "University of Islamic Sciences, Karachi",
  "@calcMethodKarachi": {"description": "Calculation method name."},
  "calcMethodTehran": "Institute of Geophysics, Tehran",
  "@calcMethodTehran": {"description": "Calculation method name."},
  "calcMethodDubai": "Dubai",
  "@calcMethodDubai": {"description": "Calculation method name."},
  "calcMethodKuwait": "Kuwait",
  "@calcMethodKuwait": {"description": "Calculation method name."},
  "calcMethodQatar": "Qatar",
  "@calcMethodQatar": {"description": "Calculation method name."},
  "calcMethodSingapore": "Majlis Ugama Islam Singapura, Singapore",
  "@calcMethodSingapore": {"description": "Calculation method name."},
```

Add the bundled city keys — English value is simply the city's common
English name (translations table below covers both locales at once):

```json
  "cityDhaka": "Dhaka",
  "@cityDhaka": {"description": "Bundled prayer-city picker entry."},
  "cityChattogram": "Chattogram",
  "@cityChattogram": {"description": "Bundled prayer-city picker entry."},
  "cityRajshahi": "Rajshahi",
  "@cityRajshahi": {"description": "Bundled prayer-city picker entry."},
  "cityKhulna": "Khulna",
  "@cityKhulna": {"description": "Bundled prayer-city picker entry."},
  "cityBarishal": "Barishal",
  "@cityBarishal": {"description": "Bundled prayer-city picker entry."},
  "citySylhet": "Sylhet",
  "@citySylhet": {"description": "Bundled prayer-city picker entry."},
  "cityRangpur": "Rangpur",
  "@cityRangpur": {"description": "Bundled prayer-city picker entry."},
  "cityMymensingh": "Mymensingh",
  "@cityMymensingh": {"description": "Bundled prayer-city picker entry."},
  "cityGazipur": "Gazipur",
  "@cityGazipur": {"description": "Bundled prayer-city picker entry."},
  "cityNarayanganj": "Narayanganj",
  "@cityNarayanganj": {"description": "Bundled prayer-city picker entry."},
  "cityCumilla": "Cumilla",
  "@cityCumilla": {"description": "Bundled prayer-city picker entry."},
  "cityCoxsBazar": "Cox's Bazar",
  "@cityCoxsBazar": {"description": "Bundled prayer-city picker entry."},
  "cityBogura": "Bogura",
  "@cityBogura": {"description": "Bundled prayer-city picker entry."},
  "cityJashore": "Jashore",
  "@cityJashore": {"description": "Bundled prayer-city picker entry."},
  "cityDinajpur": "Dinajpur",
  "@cityDinajpur": {"description": "Bundled prayer-city picker entry."},
  "cityKushtia": "Kushtia",
  "@cityKushtia": {"description": "Bundled prayer-city picker entry."},
  "cityPabna": "Pabna",
  "@cityPabna": {"description": "Bundled prayer-city picker entry."},
  "cityTangail": "Tangail",
  "@cityTangail": {"description": "Bundled prayer-city picker entry."},
  "cityFaridpur": "Faridpur",
  "@cityFaridpur": {"description": "Bundled prayer-city picker entry."},
  "cityNoakhali": "Noakhali",
  "@cityNoakhali": {"description": "Bundled prayer-city picker entry."},
  "cityFeni": "Feni",
  "@cityFeni": {"description": "Bundled prayer-city picker entry."},
  "cityBrahmanbaria": "Brahmanbaria",
  "@cityBrahmanbaria": {"description": "Bundled prayer-city picker entry."},
  "cityNarsingdi": "Narsingdi",
  "@cityNarsingdi": {"description": "Bundled prayer-city picker entry."},
  "cityManikganj": "Manikganj",
  "@cityManikganj": {"description": "Bundled prayer-city picker entry."},
  "cityJamalpur": "Jamalpur",
  "@cityJamalpur": {"description": "Bundled prayer-city picker entry."},
  "cityNetrokona": "Netrokona",
  "@cityNetrokona": {"description": "Bundled prayer-city picker entry."},
  "cityKishoreganj": "Kishoreganj",
  "@cityKishoreganj": {"description": "Bundled prayer-city picker entry."},
  "citySatkhira": "Satkhira",
  "@citySatkhira": {"description": "Bundled prayer-city picker entry."},
  "cityMecca": "Mecca",
  "@cityMecca": {"description": "Bundled prayer-city picker entry."},
  "cityMedina": "Medina",
  "@cityMedina": {"description": "Bundled prayer-city picker entry."},
  "cityJeddah": "Jeddah",
  "@cityJeddah": {"description": "Bundled prayer-city picker entry."},
  "cityRiyadh": "Riyadh",
  "@cityRiyadh": {"description": "Bundled prayer-city picker entry."},
  "cityDammam": "Dammam",
  "@cityDammam": {"description": "Bundled prayer-city picker entry."},
  "cityCairo": "Cairo",
  "@cityCairo": {"description": "Bundled prayer-city picker entry."},
  "cityAlexandria": "Alexandria",
  "@cityAlexandria": {"description": "Bundled prayer-city picker entry."},
  "cityIstanbul": "Istanbul",
  "@cityIstanbul": {"description": "Bundled prayer-city picker entry."},
  "cityAnkara": "Ankara",
  "@cityAnkara": {"description": "Bundled prayer-city picker entry."},
  "cityDubai": "Dubai",
  "@cityDubai": {"description": "Bundled prayer-city picker entry."},
  "cityAbuDhabi": "Abu Dhabi",
  "@cityAbuDhabi": {"description": "Bundled prayer-city picker entry."},
  "cityDoha": "Doha",
  "@cityDoha": {"description": "Bundled prayer-city picker entry."},
  "cityKuwaitCity": "Kuwait City",
  "@cityKuwaitCity": {"description": "Bundled prayer-city picker entry."},
  "cityManama": "Manama",
  "@cityManama": {"description": "Bundled prayer-city picker entry."},
  "cityMuscat": "Muscat",
  "@cityMuscat": {"description": "Bundled prayer-city picker entry."},
  "cityAmman": "Amman",
  "@cityAmman": {"description": "Bundled prayer-city picker entry."},
  "cityBeirut": "Beirut",
  "@cityBeirut": {"description": "Bundled prayer-city picker entry."},
  "cityBaghdad": "Baghdad",
  "@cityBaghdad": {"description": "Bundled prayer-city picker entry."},
  "cityTehran": "Tehran",
  "@cityTehran": {"description": "Bundled prayer-city picker entry."},
  "cityKarachi": "Karachi",
  "@cityKarachi": {"description": "Bundled prayer-city picker entry."},
  "cityLahore": "Lahore",
  "@cityLahore": {"description": "Bundled prayer-city picker entry."},
  "cityIslamabad": "Islamabad",
  "@cityIslamabad": {"description": "Bundled prayer-city picker entry."},
  "cityDelhi": "Delhi",
  "@cityDelhi": {"description": "Bundled prayer-city picker entry."},
  "cityMumbai": "Mumbai",
  "@cityMumbai": {"description": "Bundled prayer-city picker entry."},
  "cityKualaLumpur": "Kuala Lumpur",
  "@cityKualaLumpur": {"description": "Bundled prayer-city picker entry."},
  "cityJakarta": "Jakarta",
  "@cityJakarta": {"description": "Bundled prayer-city picker entry."},
  "citySingapore": "Singapore",
  "@citySingapore": {"description": "Bundled prayer-city picker entry."},
  "cityBangkok": "Bangkok",
  "@cityBangkok": {"description": "Bundled prayer-city picker entry."},
  "cityLondon": "London",
  "@cityLondon": {"description": "Bundled prayer-city picker entry."},
  "cityManchester": "Manchester",
  "@cityManchester": {"description": "Bundled prayer-city picker entry."},
  "cityBirmingham": "Birmingham",
  "@cityBirmingham": {"description": "Bundled prayer-city picker entry."},
  "cityParis": "Paris",
  "@cityParis": {"description": "Bundled prayer-city picker entry."},
  "cityBerlin": "Berlin",
  "@cityBerlin": {"description": "Bundled prayer-city picker entry."},
  "cityToronto": "Toronto",
  "@cityToronto": {"description": "Bundled prayer-city picker entry."},
  "cityNewYork": "New York",
  "@cityNewYork": {"description": "Bundled prayer-city picker entry."},
  "cityChicago": "Chicago",
  "@cityChicago": {"description": "Bundled prayer-city picker entry."},
  "cityHouston": "Houston",
  "@cityHouston": {"description": "Bundled prayer-city picker entry."},
  "cityLosAngeles": "Los Angeles",
  "@cityLosAngeles": {"description": "Bundled prayer-city picker entry."},
  "citySydney": "Sydney",
  "@citySydney": {"description": "Bundled prayer-city picker entry."},
  "cityMelbourne": "Melbourne",
  "@cityMelbourne": {"description": "Bundled prayer-city picker entry."},
```

- [ ] **Step 2: Add matching Bangla keys to `app_bn.arb`**

Add the same key set with Bangla translations (values only, no `@key`
blocks, matching `app_bn.arb`'s existing style):

```json
  "prayerHomeTitle": "নামাজ",
  "prayerHomeHistoryButton": "ইতিহাস",
  "prayerHomeQadhaButton": "কাজা",
  "prayerHomeStatsButton": "পরিসংখ্যান",
  "prayerHomeSettingsButton": "সেটিংস",
  "prayerHomeEmpty": "আজকের জন্য কোনো নামাজ নির্ধারিত নেই",
  "prayerNameFajr": "ফজর",
  "prayerNameDhuhr": "যোহর",
  "prayerNameAsr": "আসর",
  "prayerNameMaghrib": "মাগরিব",
  "prayerNameIsha": "এশা",
  "prayerNameJumuah": "জুমুআ",
  "prayerStatusUpcoming": "আসন্ন",
  "prayerStatusDue": "চলমান",
  "prayerStatusPrayed": "আদায় হয়েছে",
  "prayerStatusMissed": "কাজা হয়েছে",
  "prayerHistoryTitle": "ইতিহাস",
  "prayerQadhaTitle": "কাজা",
  "prayerQadhaCountLabel": "{count}টি বাকি",
  "prayerQadhaMakeupButton": "একটি আদায় হিসেবে চিহ্নিত করুন",
  "prayerQadhaEditButton": "ব্যালেন্স নির্ধারণ করুন",
  "prayerStatsTitle": "নামাজের পরিসংখ্যান",
  "prayerStatsCurrentStreak": "বর্তমান ধারাবাহিকতা: {days} দিন",
  "prayerStatsLongestStreak": "দীর্ঘতম ধারাবাহিকতা: {days} দিন",
  "prayerStatsLast7DaysLabel": "গত ৭ দিনে আদায়কৃত নামাজ",
  "prayerStatsQadhaSummaryLabel": "কাজার সারাংশ",
  "prayerStatsOnTimeLabel": "গত ৩০ দিনে যথাসময়ে আদায়ের হার",
  "prayerSettingsTitle": "নামাজের সেটিংস",
  "prayerSettingsMethodLabel": "গণনা পদ্ধতি",
  "prayerSettingsAsrLabel": "আসরের পদ্ধতি",
  "prayerSettingsAsrStandard": "প্রমিত",
  "prayerSettingsAsrHanafi": "হানাফি",
  "prayerSettingsJumuahLabel": "জুমুআ পর্যবেক্ষণ করুন",
  "prayerSettingsLocationModeLabel": "অবস্থান",
  "prayerSettingsLocationAuto": "স্বয়ংক্রিয় (জিপিএস)",
  "prayerSettingsLocationManual": "ম্যানুয়াল",
  "prayerSettingsCityPickerLabel": "শহর",
  "prayerSettingsManualLocationBanner": "ম্যানুয়াল অবস্থান ব্যবহার করা হচ্ছে",
  "prayerSettingsNotificationsLabel": "নামাজের সময়ের বিজ্ঞপ্তি",
  "prayerSettingsPreReminderLabel": "নামাজের পূর্ব-অনুস্মারক",
  "calcMethodMwl": "মুসলিম ওয়ার্ল্ড লীগ",
  "calcMethodIsna": "ইসলামিক সোসাইটি অব নর্থ আমেরিকা",
  "calcMethodEgyptian": "ইজিপশিয়ান জেনারেল অথরিটি",
  "calcMethodUmmAlQura": "উম্মুল কুরা, মক্কা",
  "calcMethodKarachi": "ইউনিভার্সিটি অব ইসলামিক সায়েন্সেস, করাচি",
  "calcMethodTehran": "ইনস্টিটিউট অব জিওফিজিক্স, তেহরান",
  "calcMethodDubai": "দুবাই",
  "calcMethodKuwait": "কুয়েত",
  "calcMethodQatar": "কাতার",
  "calcMethodSingapore": "মজলিস উগামা ইসলাম সিঙ্গাপুরা, সিঙ্গাপুর",
  "cityDhaka": "ঢাকা",
  "cityChattogram": "চট্টগ্রাম",
  "cityRajshahi": "রাজশাহী",
  "cityKhulna": "খুলনা",
  "cityBarishal": "বরিশাল",
  "citySylhet": "সিলেট",
  "cityRangpur": "রংপুর",
  "cityMymensingh": "ময়মনসিংহ",
  "cityGazipur": "গাজীপুর",
  "cityNarayanganj": "নারায়ণগঞ্জ",
  "cityCumilla": "কুমিল্লা",
  "cityCoxsBazar": "কক্সবাজার",
  "cityBogura": "বগুড়া",
  "cityJashore": "যশোর",
  "cityDinajpur": "দিনাজপুর",
  "cityKushtia": "কুষ্টিয়া",
  "cityPabna": "পাবনা",
  "cityTangail": "টাঙ্গাইল",
  "cityFaridpur": "ফরিদপুর",
  "cityNoakhali": "নোয়াখালী",
  "cityFeni": "ফেনী",
  "cityBrahmanbaria": "ব্রাহ্মণবাড়িয়া",
  "cityNarsingdi": "নরসিংদী",
  "cityManikganj": "মানিকগঞ্জ",
  "cityJamalpur": "জামালপুর",
  "cityNetrokona": "নেত্রকোণা",
  "cityKishoreganj": "কিশোরগঞ্জ",
  "citySatkhira": "সাতক্ষীরা",
  "cityMecca": "মক্কা",
  "cityMedina": "মদিনা",
  "cityJeddah": "জেদ্দা",
  "cityRiyadh": "রিয়াদ",
  "cityDammam": "দাম্মাম",
  "cityCairo": "কায়রো",
  "cityAlexandria": "আলেকজান্দ্রিয়া",
  "cityIstanbul": "ইস্তাম্বুল",
  "cityAnkara": "আঙ্কারা",
  "cityDubai": "দুবাই",
  "cityAbuDhabi": "আবুধাবি",
  "cityDoha": "দোহা",
  "cityKuwaitCity": "কুয়েত সিটি",
  "cityManama": "মানামা",
  "cityMuscat": "মাস্কাট",
  "cityAmman": "আম্মান",
  "cityBeirut": "বৈরুত",
  "cityBaghdad": "বাগদাদ",
  "cityTehran": "তেহরান",
  "cityKarachi": "করাচি",
  "cityLahore": "লাহোর",
  "cityIslamabad": "ইসলামাবাদ",
  "cityDelhi": "দিল্লি",
  "cityMumbai": "মুম্বাই",
  "cityKualaLumpur": "কুয়ালালামপুর",
  "cityJakarta": "জাকার্তা",
  "citySingapore": "সিঙ্গাপুর",
  "cityBangkok": "ব্যাংকক",
  "cityLondon": "লন্ডন",
  "cityManchester": "ম্যানচেস্টার",
  "cityBirmingham": "বার্মিংহাম",
  "cityParis": "প্যারিস",
  "cityBerlin": "বার্লিন",
  "cityToronto": "টরন্টো",
  "cityNewYork": "নিউ ইয়র্ক",
  "cityChicago": "শিকাগো",
  "cityHouston": "হিউস্টন",
  "cityLosAngeles": "লস অ্যাঞ্জেলেস",
  "citySydney": "সিডনি",
  "cityMelbourne": "মেলবোর্ন",
```

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`
Expected: `AppLocalizations` regenerates with every new key, no errors.

- [ ] **Step 4: Write `prayer_city_labels.dart`**

```dart
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Resolves a bundled city's `nameKey`
/// (`assets/data/prayer_cities.json`) to its localized display name —
/// the asset stores a key, never a raw display string, so the same
/// dataset serves both locales.
String cityDisplayName(AppLocalizations l10n, String nameKey) => switch (nameKey) {
  'cityDhaka' => l10n.cityDhaka,
  'cityChattogram' => l10n.cityChattogram,
  'cityRajshahi' => l10n.cityRajshahi,
  'cityKhulna' => l10n.cityKhulna,
  'cityBarishal' => l10n.cityBarishal,
  'citySylhet' => l10n.citySylhet,
  'cityRangpur' => l10n.cityRangpur,
  'cityMymensingh' => l10n.cityMymensingh,
  'cityGazipur' => l10n.cityGazipur,
  'cityNarayanganj' => l10n.cityNarayanganj,
  'cityCumilla' => l10n.cityCumilla,
  'cityCoxsBazar' => l10n.cityCoxsBazar,
  'cityBogura' => l10n.cityBogura,
  'cityJashore' => l10n.cityJashore,
  'cityDinajpur' => l10n.cityDinajpur,
  'cityKushtia' => l10n.cityKushtia,
  'cityPabna' => l10n.cityPabna,
  'cityTangail' => l10n.cityTangail,
  'cityFaridpur' => l10n.cityFaridpur,
  'cityNoakhali' => l10n.cityNoakhali,
  'cityFeni' => l10n.cityFeni,
  'cityBrahmanbaria' => l10n.cityBrahmanbaria,
  'cityNarsingdi' => l10n.cityNarsingdi,
  'cityManikganj' => l10n.cityManikganj,
  'cityJamalpur' => l10n.cityJamalpur,
  'cityNetrokona' => l10n.cityNetrokona,
  'cityKishoreganj' => l10n.cityKishoreganj,
  'citySatkhira' => l10n.citySatkhira,
  'cityMecca' => l10n.cityMecca,
  'cityMedina' => l10n.cityMedina,
  'cityJeddah' => l10n.cityJeddah,
  'cityRiyadh' => l10n.cityRiyadh,
  'cityDammam' => l10n.cityDammam,
  'cityCairo' => l10n.cityCairo,
  'cityAlexandria' => l10n.cityAlexandria,
  'cityIstanbul' => l10n.cityIstanbul,
  'cityAnkara' => l10n.cityAnkara,
  'cityDubai' => l10n.cityDubai,
  'cityAbuDhabi' => l10n.cityAbuDhabi,
  'cityDoha' => l10n.cityDoha,
  'cityKuwaitCity' => l10n.cityKuwaitCity,
  'cityManama' => l10n.cityManama,
  'cityMuscat' => l10n.cityMuscat,
  'cityAmman' => l10n.cityAmman,
  'cityBeirut' => l10n.cityBeirut,
  'cityBaghdad' => l10n.cityBaghdad,
  'cityTehran' => l10n.cityTehran,
  'cityKarachi' => l10n.cityKarachi,
  'cityLahore' => l10n.cityLahore,
  'cityIslamabad' => l10n.cityIslamabad,
  'cityDelhi' => l10n.cityDelhi,
  'cityMumbai' => l10n.cityMumbai,
  'cityKualaLumpur' => l10n.cityKualaLumpur,
  'cityJakarta' => l10n.cityJakarta,
  'citySingapore' => l10n.citySingapore,
  'cityBangkok' => l10n.cityBangkok,
  'cityLondon' => l10n.cityLondon,
  'cityManchester' => l10n.cityManchester,
  'cityBirmingham' => l10n.cityBirmingham,
  'cityParis' => l10n.cityParis,
  'cityBerlin' => l10n.cityBerlin,
  'cityToronto' => l10n.cityToronto,
  'cityNewYork' => l10n.cityNewYork,
  'cityChicago' => l10n.cityChicago,
  'cityHouston' => l10n.cityHouston,
  'cityLosAngeles' => l10n.cityLosAngeles,
  'citySydney' => l10n.citySydney,
  'cityMelbourne' => l10n.cityMelbourne,
  _ => nameKey,
};
```

- [ ] **Step 5: Wire the keys into the screens**

In each of `prayer_home_screen.dart`, `prayer_tile.dart`,
`prayer_history_screen.dart`, `prayer_qadha_screen.dart`,
`prayer_stats_screen.dart`, `prayer_settings_screen.dart` (Tasks 17-21),
replace every hardcoded English string literal used in Step 1's key list
with `AppLocalizations.of(context)!.<matchingKey>` (add the `import
'package:habit_tracker/core/l10n/app_localizations.dart';` import to any
file that doesn't already have it). Each screen/widget's own
`_labelFor(PrayerName)`/`_statusLabel(PrayerStatus)` private helper
becomes a `switch` on `AppLocalizations.of(context)!` using the
`prayerName*`/`prayerStatus*` keys (same pattern as Medicine's
`DoseTile`). `prayer_settings_screen.dart`'s `CalculationMethod` dropdown
items use a similar private `_methodLabel(AppLocalizations, method)`
switch over the ten `calcMethod*` keys. The city dropdown's
`Text(city.nameKey)` becomes
`Text(cityDisplayName(AppLocalizations.of(context)!, city.nameKey))`
(Step 4's new helper).

- [ ] **Step 6: Re-run the widget/module tests**

Run: `flutter test test/features/prayer/`
Expected: PASS — `prayer_home_screen_test.dart`'s string assertions
(`'No prayers scheduled for today'`, `'Fajr'`) still match since the en
arb values are unchanged text, just routed through `AppLocalizations`
now.

- [ ] **Step 7: Commit**

```bash
git add lib/core/l10n/ lib/features/prayer/presentation/
git commit -m "feat(prayer): en/bn localization"
```

---

### Task 23: Final verification pass

**Files:** none created — verification only.

- [ ] **Step 1: Regenerate all codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: clean regeneration, no conflicts.

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full format check**

Run: `dart format --output=none --set-exit-if-changed .`
Expected: no output. If it lists files, run `dart format .` and
re-check.

- [ ] **Step 4: Full test suite**

Run: `flutter test`
Expected: all tests pass, including every `test/features/prayer/**` file
from Tasks 3-22 and the pre-existing Water/Medicine/core suites
(unaffected).

- [ ] **Step 5: Manual smoke pass (per the design spec's DoD)**

Launch the app (`flutter run`), and walk:
1. Complete Prayer setup: pick a calculation method, Asr madhab, and a
   manual city (or grant location permission for auto mode); confirm the
   checklist shows 5 prayers with plausible times.
2. Tap "Prayed" on a prayer; confirm it toggles to Prayed and toggling
   again reverts to Upcoming/Due.
3. Turn on "Observe Jumu'ah," navigate to a Friday in the history
   calendar, and confirm that day's Dhuhr entry displays as "Jumu'ah."
4. Change the calculation method or switch to a different manual city;
   confirm today's/future prayer times recompute immediately (FR-P-01)
   without altering already-`prayed`/`missed` history.
5. Use a schedule with a very short/already-past cutoff (or wait) and
   confirm an unactioned prayer becomes "Missed" and its Qadha counter
   increments by exactly 1 (Qadha screen).
6. Tap "−1" on a Qadha counter and confirm it decrements, floors at 0.
7. Change device timezone (or switch manual location to a different
   timezone) and confirm prayer times recompute correctly on next
   foreground (D-09).
8. Switch the device/app language to Bangla; confirm every new Prayer
   string — including calculation-method names and city names — renders
   translated, no layout overflow.

- [ ] **Step 6: Update `CLAUDE.md`'s "Project state" section**

Add a short paragraph (matching the existing style/tense of that
section) noting Prayer is now a complete module registered in
`module_registry.dart`, mirroring how the Water/Medicine paragraphs are
written — write this by hand at commit time based on what actually
shipped, not copied verbatim from this plan.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(prayer): complete prayer tracking module

Domain (adhan_dart calculation wrapper golden-tested against a published
reference, status derivation, one-shot missed-prayer/Qadha crossing
detector, day-based materialization planner, streak/adherence calc),
data (3 Drift tables, no-DAO repository, bundled city list + GPS/manual
location resolver), presentation (checklist toggle, history calendar,
Qadha screen, stats, settings), and HabitModule/notification wiring —
reusing the Run 08 notification engine's existing triggers for
materialization with no new call sites.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-review notes (writing-plans skill's mandatory pass)

**Spec coverage:** FR-P-01 (Task 11's `updateSettings` future-record
clearing, this plan's refinement #3), FR-P-02 (Task 11's locale-based
Asr default), FR-P-03 (Task 5, Task 6's Friday-still-`dhuhr`
materialization), FR-P-04 (Task 11's `setQadhaBalance`, Task 19), FR-P-05
(Task 4's `cutoffForPrayer`, Task 12's `sweepMissedPrayers`, Task 13's
`markMissedBySkip`, Task 8's `applyQadhaMakeup`), FR-P-06 (Task 14's
`resolveLocation`), FR-P-07 (Task 4's `effectivePrayerStatus`, Task 13's
`markPrayed`/`unmarkPrayed` toggle, Task 17), FR-P-08 (Task 16's
`pendingNotifications`/`onNotificationAction`, the `prayer_settings`
reminder columns from refinement #4), FR-P-09 (Task 7), FR-P-10 (Task 9,
Task 20) — all covered. D-06 (Task 2, Task 11's locale defaults), D-07
(Task 5, refinement #1), D-08 (Task 8, Task 11-12's Qadha bump/clamp),
D-09 (Task 14, Task 21's manual-location banner), D-13 (Task 6, Task 12),
D-14 (entities, Task 12's DB string/local-string split) — all covered.

**Placeholder scan:** no `TODO`/`TBD` left in any step's code. Task 16's
5 screen stubs are explicitly temporary and explicitly replaced by name
in Tasks 17-21 (each tracked as that task's own "Modify" file — same
precedent as Medicine's Task 13). Task 11's step 4 adds temporary
`UnimplementedError()` stub bodies for interface methods Tasks 12-13
haven't reached yet, each explicitly named as "replaced by Task N." The
golden prayer-time test values (Task 3) are real numbers from a live,
cited API call, not placeholders. The 68-entry city list (Task 14) uses
real geographic coordinates and real IANA timezone ids, not sample data;
every one of its `nameKey`s has both an English and a Bangla translation
in Task 22 (no `_ => nameKey` fallback is ever hit for a bundled city in
practice — that fallback exists only as a defensive default for a
malformed/future asset entry).

**Type consistency:** `PrayerTimes` (Task 3), `PrayerRecordView` (Task
15), `PlannedPrayerRecord` (Task 6), `PrayerAdherenceStats` (Task 9),
`PrayerStreakResult` (Task 7), `ResolvedLocation` (Task 2) are each
defined once and referenced by identical name/shape everywhere
downstream — verified by re-reading every consuming task's `Interfaces:`
block against its producing task. `cutoffForPrayer`'s `ianaTimezone`
parameter is consistently `String?` (nullable) from its Task 4 definition
through Task 12's repository usage (always non-null there, a real
resolved location) and Task 15's provider usage (nullable, since
resolution can still be pending/failed) — no signature drift between the
two call sites. `PrayerName` has exactly 5 values everywhere it appears
(entities, DB mapping, streak/adherence calculators, all screens) — no
file anywhere introduces a 6th `jumuah` value, consistent with refinement
#1.
