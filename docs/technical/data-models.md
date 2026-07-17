# Data Models

Domain model (Freezed, zero Flutter imports per `architecture.md`'s
dependency rule) ↔ DB row (`database-design.md`) ↔ JSON export shape, for
every entity. JSON export uses ISO-8601 strings for all timestamps (not raw
epoch millis) — export is meant to be human-readable and portable to a
future backup/sync format, where epoch millis would be a needless decoding
step for no benefit. Soft-deleted rows (`deletedAt != null`) ARE included in
export — a future merge/restore needs to know a row was deleted, not just
silently omit it (this is the entire point of soft-delete existing, see
`offline-strategy.md`).

Where domain model shape differs meaningfully from the DB row, the
difference is called out explicitly — most of this app's real domain
complexity lives in `MedicineSchedule`'s repeat-rule modeling.

---

## Common

### `AppSettings`

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| locale | `AppLocale` (enum: en, bn) | no | `locale` | `locale` |
| themeMode | `ThemeMode` (Flutter enum, mapped at the repository boundary) | no | `theme_mode` | `themeMode` |
| waterUnit | `WaterUnit` (enum: ml, flOz) | no | `water_unit` | `waterUnit` |
| pinEnabled | `bool` | no | `pin_enabled` | `pinEnabled` |
| pinHash | `String` | yes | `pin_hash` | *(excluded from export — never leaves the device, even in a backup file)* |
| pinLockTimeoutSeconds | `int` | no | `pin_lock_timeout_seconds` | `pinLockTimeoutSeconds` |
| onboardingCompletedAt | `DateTime` (UTC) | yes | `onboarding_completed_at` | `onboardingCompletedAt` (ISO-8601) |

**Divergence:** `pinHash` is deliberately dropped from the JSON export
shape — a backup file is not a secrets store, and re-entering a PIN on
restore is a smaller cost than the risk of a hash leaking through an
exported file shared to cloud storage.

### `ModuleState`

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| id | `ModuleId` (enum: water, medicine, prayer) | no | `id` | `id` |
| enabled | `bool` | no | `enabled` | `enabled` |
| position | `int` | no | `position` | `position` |
| setupCompletedAt | `DateTime` (UTC) | yes | `setup_completed_at` | `setupCompletedAt` |

### `NotificationLedgerEntry`

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| id | `String` (UUID) | no | `id` | `id` |
| moduleId | `ModuleId` | no | `module_id` | `moduleId` |
| sourceType | `NotificationSourceType` (enum) | no | `source_type` | `sourceType` |
| sourceId | `String` | no | `source_id` | `sourceId` |
| scheduledFor | `DateTime` (UTC) | no | `scheduled_for` | `scheduledFor` |
| firedAt | `DateTime` (UTC) | yes | `fired_at` | `firedAt` |
| action | `NotificationAction?` (enum: done, snooze, skip) | yes | `action` | `action` |
| actionAt | `DateTime` (UTC) | yes | `action_at` | `actionAt` |
| snoozeCount | `int` | no | `snooze_count` | `snoozeCount` |
| deepLinkRoute | `String` | no | `deep_link_route` | `deepLinkRoute` |

**Divergence:** none structural — this table's domain model is a near-direct
mirror of its row, since it's an audit ledger, not something the UI shapes
differently from storage.

### `Achievement`

Direct row mirror, same reasoning as above — omitted for brevity, fields
match `database-design.md` 1:1 with standard type mapping (`TEXT`→`String`/
enum, `INTEGER` epoch→`DateTime`, bool-as-int→`bool`).

---

## Water

### `WaterGoal` (current value) vs. `WaterGoalHistory` (domain concept)

**Divergence:** the DB is an append-only history table (`water_goals`); the
domain layer exposes two different shapes because the UI never wants "all
goal rows," it wants either "the current goal" or "the goal that applied on
date X":

- `WaterGoal` (what the UI binds to): `{ goalMl: int, effectiveFrom: DateTime }`
  — always "the current one," resolved by the repository as the latest row.
- The repository additionally exposes `Future<WaterGoal> goalOn(LocalDate day)`
  for historical resolution (FR-W-04/FR-W-07 streak evaluation), which is a
  **use case**, not a field on the domain model itself — there's no
  "WaterGoalHistory" Freezed class, because the history is a query pattern,
  not a value the UI ever renders as a list.

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| id | `String` (UUID) | no | `id` | `id` |
| goalMl | `int` | no | `goal_ml` | `goalMl` |
| effectiveFrom | `DateTime` (UTC) | no | `effective_from` | `effectiveFrom` |

### `WaterEntry`

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| id | `String` (UUID) | no | `id` | `id` |
| amountMl | `int` | no | `amount_ml` | `amountMl` |
| loggedAt | `DateTime` (UTC) | no | `logged_at` | `loggedAt` |

**Divergence:** the domain model exposes `amountMl` always in ml (canonical,
D-01); a separate presentation-layer extension/formatter converts to fl oz
for display per the `waterUnit` setting — this conversion never touches the
domain model or the DB, it's a pure view-layer function, so the domain
model has exactly one unit, never two.

---

## Medicine

### `Medicine`

Direct row mirror — `id`, `name`, `dosageNote`, `stockEnabled`,
`stockCount`, `stockThreshold`, `stopWhenStockDepleted`,
`consumptionPerDose`, `archivedAt`. Standard type mapping.

### `MedicineSchedule` — the biggest domain/DB divergence in the app

**DB row:** flat columns (`frequency_type` + nullable `interval_days` /
`weekdays_mask` / `times_of_day` JSON string).

**Domain model:** a proper Freezed **sealed union**, `RepeatRule`:

```dart
sealed class RepeatRule {
  const factory RepeatRule.fixedDaily({required List<LocalTime> times}) = FixedDaily;
  const factory RepeatRule.everyNDays({
    required int interval,
    required LocalDate startDate,
    required List<LocalTime> times,
  }) = EveryNDays;
  const factory RepeatRule.weekdaySet({
    required Set<Weekday> weekdays,
    required List<LocalTime> times,
  }) = WeekdaySet;
  const factory RepeatRule.prn() = Prn;
}
```

`MedicineSchedule` itself is `{ id, medicineId, repeatRule: RepeatRule,
startDate, endDate, graceWindowMinutes }`.

**Why the divergence is worth it:** SQL has no native union/sum type, so the
row necessarily stores "one column per possible variant's data, mostly
null." Forcing the domain layer to work with that same flat, mostly-null
shape would push `if (frequencyType == 'every_n_days')` branching into every
use case that touches a schedule. The sealed class moves that branching to
exactly one place — the repository's row↔domain mapping function — and
every use case above it (dose generation, UI display, edit forms) works
with exhaustive `switch` over a closed set of cases instead of nullable-field
checks. This is the direct Dart analogue of a Laravel `MedicineSchedule`
Eloquent model exposing a "resolved" value object rather than making every
caller inspect a raw `type` column and matching nullable columns by hand.

JSON export mirrors the DB's flat shape (not the sealed class) — export
format stability matters more than domain ergonomics, and a flat
`{frequencyType, intervalDays, weekdaysMask, timesOfDay}` shape is what a
future import routine reconstructs the sealed class from anyway.

### `MedicineDose`

Direct row mirror — `id`, `medicineId`, `scheduleId`, `scheduledFor`,
`status: DoseStatus` (enum: upcoming, due, done, missed, skipped),
`statusChangedAt`, `stockDeltaApplied`.

### `MedicineStockEvent`

Direct row mirror — `id`, `medicineId`, `doseId?`, `delta`,
`reason: StockEventReason` (enum), `occurredAt`.

---

## Prayer

### `PrayerSettings`

Direct row mirror — `calculationMethod: CalculationMethod` (enum),
`asrMethod: AsrMethod` (enum: standard, hanafi), `observesJumuah: bool`,
`locationMode: LocationMode` (enum: auto, manual), `manualLatitude?`,
`manualLongitude?`, `manualTimezone?`, `ishaDayRolloverTime: LocalTime`.

### `PrayerRecord`

| Domain field | Type | Null? | DB column | JSON key |
|---|---|---|---|---|
| id | `String` (UUID) | no | `id` | `id` |
| prayerDate | `LocalDate` (value type, not `DateTime` — no time component, no timezone attached) | no | `prayer_date` | `prayerDate` (ISO date, e.g. `"2026-07-17"`) |
| prayerName | `PrayerName` (enum: fajr, dhuhr, asr, maghrib, isha, jumuah) | no | `prayer_name` | `prayerName` |
| scheduledFor | `DateTime` (UTC) | no | `scheduled_for` | `scheduledFor` |
| status | `PrayerStatus` (enum: upcoming, due, prayed, missed) | no | `status` | `status` |
| statusChangedAt | `DateTime` (UTC) | yes | `status_changed_at` | `statusChangedAt` |

**Divergence:** `prayerDate` is modeled as a dedicated `LocalDate` value type
(year/month/day only), not `DateTime`, specifically so nothing in the domain
layer can accidentally attach a timezone or time-of-day to what is
semantically a calendar-day bucket key (D-14) — a `DateTime` field here
would invite exactly the kind of "what timezone is this in" bug the
UTC-vs-local split in `database-design.md` exists to prevent.

### `PrayerQadhaCounter`

Direct row mirror — `id`, `prayerName: PrayerName` (excludes jumuah, D-07),
`count: int`, `updatedAt`.

---

## Type-mapping conventions (apply across all entities above)

| DB storage | Domain type |
|---|---|
| `INTEGER` epoch millis | `DateTime` (always constructed as UTC, converted to local only at the presentation layer) |
| `TEXT` local `"HH:mm"` | `LocalTime` value type |
| `TEXT` local `"YYYY-MM-DD"` | `LocalDate` value type |
| `INTEGER` 0/1 | `bool` |
| `TEXT` enum-like string | Dart `enum`, mapped via a small `fromDb`/`toDb` extension per enum, not `EnumName.values.byName` directly (so a stored string never silently breaks if an enum is reordered — mapping is by explicit string literal, not ordinal position) |
