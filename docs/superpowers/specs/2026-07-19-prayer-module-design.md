# Prayer module — design

Run: implements FR-P-01..10 (`docs/product/functional-requirements.md`),
D-06..09 (`docs/product/decisions.md`), `docs/strategies/prayer-times.md`,
and the `prayer_settings`/`prayer_records`/`prayer_qadha_counters` schema
(`docs/technical/database-design.md`). Whole module in one pass: domain,
data, presentation, notifications — the same divergence Medicine took from
`docs/engineering/phases-and-dod.md`'s Run 10 (domain & data only) / Run 11
(presentation & notifications) split; that doc's numbering is still
pending reconciliation per its own note.

## Scope decisions (resolved during brainstorming)

- **Status model:** `upcoming | due | prayed | missed`. **No
  `prayed-late`** — an earlier draft of this run's brief listed one, but
  it isn't in FR-P-07, D-08, or the committed `prayer_records.status`
  column, and there's no rule anywhere for what distinguishes "late" from
  "missed." Following the committed spec instead of the brief.
- **Hijri date: out of scope this run**, per `prayer-times.md`'s explicit
  v1.0 scope call. Checklist screen shows Gregorian only. (No schema
  impact if added later — it'd be computed from `prayer_date` at render
  time.)
- **City list size:** small curated bundle — Bangladesh: 8 divisional
  capitals + ~20 major districts (~30 entries). World: ~40 major cities.
  Not the exhaustive 64-district/150+-city version — easy to review and
  translate, extend later if requested.
- **No dedicated high-latitude-rule setting.** No FR asks for one;
  `adhan_dart`'s library default is used as-is. `// ponytail:` marker in
  the calc-engine wrapper noting this as the deferred item, with the
  upgrade path being a `prayer_settings` column + Settings toggle if a
  future run needs it.
- **One run, full slice:** domain → data → presentation → notifications,
  not split across two runs (matches the Medicine precedent above).

## New dependencies (`pubspec.yaml`)

- `adhan_dart` (^2.0.1) — offline prayer-time calculation engine.
  Explicitly not the plain `adhan` package (stale, see `prayer-times.md`).
- `geolocator` — one-shot GPS fix (raw lat/long only, no reverse-geocode).
- `flutter_timezone` — reads the OS's own timezone id (no network).
- `timezone` (^0.11.1) already present — used to resolve the IANA tz id
  for manual-location entries.

## Domain (`lib/features/prayer/domain/entities/`, freezed)

- `PrayerSettings` — id (always `'singleton'`), calculationMethod
  (`CalculationMethod` enum: `mwl|isna|egyptian|ummAlQura|karachi|tehran|
  dubai|kuwait|qatar|singapore`), asrMethod (`AsrMethod`:
  `standard|hanafi`), observesJumuah (bool, default false),
  locationMode (`LocationMode`: `auto|manual`), manualLatitude (double?),
  manualLongitude (double?), manualTimezone (String?, IANA id),
  ishaDayRolloverTime (`LocalTime`, default `00:00`)
- `PrayerRecord` — id, prayerDate (`LocalDate`), prayerName
  (`PrayerName`: `fajr|dhuhr|asr|maghrib|isha|jumuah`), scheduledFor
  (DateTime, UTC), storedStatus (`PrayerStatus`: **only ever**
  `upcoming|prayed|missed` in the DB — `due` is derived, see below),
  statusChangedAt (DateTime?)
- `PrayerQadhaCounter` — id, prayerName (`fajr|dhuhr|asr|maghrib|isha`,
  no `jumuah` row — shares Dhuhr's bucket per D-07/FR-P-03), count (int,
  floors at 0)

## Prayer-time calculation (`domain/usecases/calculate_prayer_times.dart`)

Pure wrapper over `adhan_dart`, no `clock.now()` — caller supplies the date:

```dart
typedef PrayerTimes = ({
  DateTime fajr,
  DateTime dhuhr,
  DateTime asr,
  DateTime maghrib,
  DateTime isha,
});

PrayerTimes calculatePrayerTimes({
  required LocalDate date,
  required double latitude,
  required double longitude,
  required String ianaTimezone,
  required CalculationMethod method,
  required AsrMethod asrMethod,
});
```

This is the golden-tested unit. `test/features/prayer/calculate_prayer_
times_golden_test.dart` checks Dhaka/Kuala Lumpur/London on fixed dates
against published reference times (source cited in the test file — pulled
via web search during implementation), ±2 min tolerance; anything beyond
that gets investigated before the test is accepted.

## Status lifecycle & the Qadha side effect

`storedStatus` is only ever `upcoming` or a terminal state
(`prayed`/`missed`) in the database — mirroring Medicine's
`effectiveDoseStatus` precedent, with one deliberate difference:

- **`due` is never persisted** — purely time-derived, same as Medicine:

```dart
PrayerStatus effectivePrayerStatus({
  required PrayerStatus storedStatus,
  required DateTime scheduledFor,
  required DateTime cutoff, // start of next prayer's window (or Isha's
                             // configurable day-rollover instant)
  required DateTime now,
});
```

- **`missed` IS persisted**, unlike Medicine's transient `missed` —
  because crossing into missed has a side effect (Qadha +1, FR-P-05) that
  must fire exactly once. This is the same one-shot-crossing shape as
  Medicine's low-stock detection (FR-M-04), applied to a status
  transition instead of a stock threshold:

```dart
/// Called from the same trigger point as materialization (app-resume /
/// WorkManager, via PrayerModule.pendingNotifications()) — finds records
/// still `upcoming` whose cutoff has passed, persists `missed`, and
/// bumps that prayer's Qadha counter by 1. Idempotent: a record only
/// ever makes this transition once, since storedStatus is no longer
/// `upcoming` afterward.
Future<void> sweepMissedPrayers(DateTime now);
```

## Materialization (`domain/usecases/plan_prayer_materialization.dart`)

Much simpler than Medicine's repeat-rule planner — one settings row, not
N schedules, no collision resolution needed:

```dart
typedef PlannedPrayerRecord = ({
  LocalDate prayerDate,
  PrayerName prayerName,
  DateTime scheduledFor,
});

List<PlannedPrayerRecord> planPrayerMaterialization({
  required PrayerSettings settings,
  required ResolvedLocation location, // lat/long/tz, from auto-GPS or manual
  required List<PrayerRecord> existingRecords,
  required LocalDate windowStart,
  required LocalDate windowEnd,
});
```

For each day in `[windowStart, windowEnd]`, for each of the 5 prayers
(Friday's Dhuhr slot is still `prayerName: dhuhr` — `jumuah` is a display
label applied at render time when `observesJumuah` is on and the day is
Friday, not a separate materialized row, since it shares Dhuhr's schedule
and Qadha bucket per D-07), if `(prayerDate, prayerName)` is missing, add
it via `calculatePrayerTimes`. Rolling 30-day window, same D-13 pattern as
`medicine_doses`.

## Streaks, Qadha makeup, adherence

- `CalculatePrayerStreakUseCase` — same per-module-class shape as
  `CalculateWaterStreakUseCase` (no shared abstraction extracted; three
  similar streak classes across Water/Medicine/Prayer is fine per this
  project's existing convention, not a premature unification). A day
  counts only once it's fully resolved (no `upcoming`/`due` prayers left
  for that day) and every required prayer (4 + Jumu'ah on Fridays when
  `observesJumuah` is on, else 5) is `prayed`. Qadha-relevant prayers are
  excluded from the streak calc per D-08.
- `applyQadhaMakeup({required PrayerQadhaCounter counter})` — decrements
  by 1, clamped at 0 (FR-P-05's "−1" control).
- Manual Qadha balance adjustment (FR-P-04) — direct repository
  set-to-value, no dedicated use case (it's a raw onboarding input, not
  derived logic).
- `calculateAdherence` — per-prayer on-time percentage over 7/30/all-time
  windows (FR-P-10), same shape as Medicine's `calculate_adherence.dart`.

## Data layer (`lib/features/prayer/data/`)

Schema already fixed in `database-design.md` — this run implements it:

- `prayer_settings` (singleton, seeded on first read, same pattern as
  `app_settings`)
- `prayer_records` (30-day rolling window, unique index on
  `(prayer_date, prayer_name)`)
- `prayer_qadha_counters` (5 rows, seeded at first setup)
- `PrayerRepositoryImpl` — no DAO, same precedent as Water/Medicine (one
  caller, no join complexity that would benefit from a DAO layer).
- Bundled city list: `assets/data/prayer_cities.json` — 
  `{ nameKey, latitude, longitude, ianaTimezone }[]`, `nameKey` resolved
  through `AppLocalizations` for en/bn display (not raw strings in the
  asset, so the same dataset serves both locales).

## Notifications (`prayer_module.dart`)

Mirrors `MedicineModule` almost exactly:

- `pendingNotifications()`: `sweepMissedPrayers` then
  `materializePrayerRecords` (order matters — sweep before topping up,
  so a freshly-materialized `upcoming` row for today's already-past
  prayer is never possible) — same "runs first thing, no new call site,
  reuses Run 08's app-resume/WorkManager triggers" precedent as Medicine
  — then emits one `PendingNotification` per `upcoming` record in the
  3-day window, plus an optional pre-prayer reminder at a
  user-configured offset (FR-P-08). Id = bare record UUID (same
  shared-namespace precedent/risk already flagged in `CLAUDE.md` for
  Medicine's dose ids).
- `onNotificationAction`: `done` → mark `prayed`; `skip` → mark `missed`
  + Qadha+1 (reuses the same transition `sweepMissedPrayers` would have
  made, just user-triggered instead of time-triggered); `snooze` →
  no-op, same as Water/Medicine.

## Presentation (`lib/features/prayer/presentation/`)

- **Checklist screen** — today's five (or six on Fridays) prayers,
  countdown to next prayer, Gregorian date, tap-to-mark-prayed **toggle**
  (not a multi-state cycle — FR-P-07 only grants the user a one-tap
  "Prayed" action; `missed` is either time-derived or an explicit Skip
  action, never a manual tap target).
- **History calendar** — per-day completion coloring, day drill-down.
- **Qadha screen** — five counters, "−1" make-up control, manual balance
  entry (onboarding + Settings).
- **Stats screen** — reuses `core/widgets/charts/period_bar_chart.dart`
  (built for Water, already reused by Medicine): streak, longest streak,
  per-prayer on-time %, Qadha summary.
- **Settings** — calculation method, Asr madhab, Jumu'ah toggle, location
  (city picker / manual lat-long / one-shot GPS), reminder toggles +
  offsets, Isha day-rollover time, "using manual location" banner (D-09).
- Routes + `PrayerModule` (`HabitModule` impl) mirror `MedicineModule`'s
  shape exactly; registered in `module_registry.dart`, swapped into the
  router the same way Water/Medicine were (replacing the placeholder
  single route currently used for Prayer's tab).

## Localization

Full en/bn for all new strings, including calculation-method/madhab
names and the bundled city list's display names. Any Bangla term the
translator (me, during implementation) is unsure of gets flagged
in-place rather than guessed, per this run's brief.

## Testing / Definition of Done

- Golden prayer-time tests (Dhaka/Kuala Lumpur/London, fixed dates,
  cited source, ±2 min tolerance) green.
- Unit tests: Qadha arithmetic (clamp at 0, manual adjustment, makeup
  decrement), streak logic (Jumu'ah swap, Qadha exclusion), the
  `sweepMissedPrayers` one-shot-crossing behavior, timezone-change
  recomputation (D-09 — foreground + simulated background-midnight
  trigger).
- Manual script: change location (city → manual lat/long → GPS) and
  verify times + scheduled reminders update; full Bangla pass.
- `flutter analyze` clean, `flutter test` green.
- Commit: `feat(prayer): complete prayer tracking module`.
