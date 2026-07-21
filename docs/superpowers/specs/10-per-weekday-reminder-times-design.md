# Custom Per-Day-of-Week Reminder Times

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Every module's reminder configuration today is a single flat schedule
applied identically to all seven days:

- **Water** (`lib/features/water/domain/entities/water_settings.dart`):
  one `reminderEnabled` + one `reminderIntervalMinutes` + one
  `[reminderWindowStart, reminderWindowEnd]` pair. `WaterModule
  .pendingNotifications()` (`lib/features/water/water_module.dart`)
  walks `_lookaheadDays` (3) days ahead and, for *every* day, steps from
  `reminderWindowStart` to `reminderWindowEnd` in
  `reminderIntervalMinutes` increments — same window, same cadence,
  Monday through Sunday.
- **Medicine**: doses come from `RepeatRule.weekdaySet` (`lib/features/
  medicine/domain/entities/repeat_rule.dart`), which already selects
  *which* weekdays a dose occurs on via `weekdaysMask`, but applies the
  same `timesOfDay` list to every selected weekday — there's no way to
  say "8am on weekdays, 10am on weekends" for the same schedule.
- **Prayer**: prayer *times* already vary every single day (they're
  recomputed daily by `adhan_dart` from location + calculation method),
  but the reminder *policy* on top of them
  (`notificationsEnabled`/`preReminderEnabled`/
  `preReminderOffsetMinutes` in `lib/features/prayer/domain/entities/
  prayer_settings.dart`) is a single global on/off + offset, not per
  prayer and not per weekday.

The Feature Atlas gap: TickTick lets a user set "remind me at 6pm on
weekdays, 9am on weekends" for a single recurring task. Nothing in this
app's reminder model can express "later Asr reminder on meeting-heavy
weekdays" or "different water cadence on weekends" without maintaining
two separate manually-toggled schedules.

## Scope decision: Water only

This spec implements per-weekday reminder windows **for Water only**.
Medicine and Prayer are analyzed below and explicitly **not** changed by
this spec — forcing the same shape onto them would fight their existing,
better-fitting models rather than extend them.

### Why Water fits

Water's reminder is exactly the TickTick shape: one recurring daily
policy (a window + interval), no other structure attached. Swapping a
single window for "the window that applies today, chosen by weekday" is
a pure widening of an existing concept — no new entity, no new use case,
same `pendingNotifications()` call site.

### Why Medicine doesn't need this

Medicine's `RepeatRule.weekdaySet` already solves the *weekday selection*
half of this problem (D-03), and a real "different time on different
selected weekdays" need is already expressible **today** by creating two
`MedicineSchedule` rows against the same `Medicine` — one
`weekdaySet(weekdaysMask: <Mon-Fri bits>, timesOfDay: [08:00])`, one
`weekdaySet(weekdaysMask: <Sat-Sun bits>, timesOfDay: [10:00])`. Multiple
schedules per medicine are already a supported shape (`medicine_schedules`
is a one-to-many table, `dosesInRange`/`materializeDoses` already fan out
across every schedule for a medicine). Adding a `Map<weekday, List
<LocalTime>>` to a *single* `RepeatRule.weekdaySet` would duplicate a
capability the schema already has via row multiplicity, at the cost of a
schema migration, `expandRepeatRule` rewrite (currently the module's most
heavily-tested unit, per `CLAUDE.md`), and D-02 collision-resolution
retest. Not worth it — out of scope.

### Why Prayer doesn't need this (in this shape)

Prayer's five reminder times are already maximally "per-day" — recomputed
from astronomy every single day, not a static time a user picks. There is
no "9am on weekdays, 11am on weekends" to express because there's no
static time to begin with; "a later Asr reminder on meeting-heavy
weekdays" for Prayer doesn't mean shifting the prayer time (that would be
religiously incorrect — Asr's actual time doesn't move for anyone's
calendar), it means either (a) a **per-weekday pre-reminder offset**
(e.g. `preReminderOffsetMinutes` of 30 on weekdays vs. 10 on weekends,
so the *heads-up* comes earlier without touching the on-time
notification), or (b) **per-prayer notification toggles**, letting a
user mute just Zuhr's on-time ping on Fridays because Jumu'ah already
covers it. Both are real, plausible asks — but they're a different
feature (per-prayer, not per-weekday-time) with their own settings-UI
and data-model shape. Flagged as a candidate follow-up, explicitly out
of scope here so this spec doesn't force Water's "pick a time" model
onto a module where there's no time to pick.

## Design (Water)

### Data model

Replace `WaterSettings`'s single `reminderWindowStart`/`reminderWindowEnd`
pair with **one override map, keyed by weekday, falling back to the
existing default pair when a day has no override**. This is additive and
minimizes blast radius — the existing two fields keep meaning "the
default window," so 6 of 7 days typically need zero configuration.

`lib/features/water/domain/entities/water_settings.dart`:

```dart
@freezed
sealed class WaterSettings with _$WaterSettings {
  const factory WaterSettings({
    required List<int> quickAddAmountsMl,
    required bool reminderEnabled,
    required int reminderIntervalMinutes,
    required LocalTime reminderWindowStart,
    required LocalTime reminderWindowEnd,

    /// Per-weekday overrides for the default reminder window above.
    /// Keyed by `DateTime.weekday` (1=Monday..7=Sunday, matching
    /// `RepeatRule.weekdaySet`'s bitmask convention elsewhere in the
    /// app). A day with no entry uses [reminderWindowStart]/
    /// [reminderWindowEnd]. `reminderIntervalMinutes` is NOT
    /// overridden per-day (see "What's not overridden" below).
    @Default({})
    Map<int, ({LocalTime start, LocalTime end})> reminderWindowOverrides,
  }) = _WaterSettings;
}
```

Freezed's default `Map` equality/copy semantics already handle this
value type fine (no custom `==` needed); the record type `({LocalTime
start, LocalTime end})` avoids inventing a one-off `WaterReminderWindow`
class for two fields.

**What's not overridden.** Only the window (start/end), not
`reminderIntervalMinutes` — TickTick's own per-weekday feature is
"different time on different days," not "different cadence." A
weekend-only cadence change is a real but separate ask (it would need
its own override map); keeping scope to the window matches exactly what
the Atlas entry describes ("a later Asr reminder," "different reminder
cadence on weekends" — the cadence example is int minutes but the spec
text's own emphasis, and the concrete worked example, is a shifted
*time*). If per-day cadence turns out to matter, widen the record to
`({LocalTime start, LocalTime end, int intervalMinutes})` later — same
map shape, no migration shape change, just a wider value.

**Storage — one column, not seven.** `water_settings` (`lib/features/
water/data/tables/water_settings_table.dart`) already stores
`quickAddAmountsMl` as a JSON-encoded `TextColumn` (see line 19-20 of
that file: `'JSON array of ml amounts, e.g. "[250,500,750]"'`). Follow
that exact precedent rather than adding 7×2 = 14 new columns:

```dart
/// JSON object mapping weekday (1=Mon..7=Sun, string keys — JSON object
/// keys are always strings) to `{"start": "HH:mm", "end": "HH:mm"}`.
/// Absent days fall back to [reminderWindowStart]/[reminderWindowEnd].
/// Empty object `"{}"` by default (no overrides).
TextColumn get reminderWindowOverrides =>
    text().withDefault(const Constant('{}'))();
```

A 7-column schema (`mondayStart`, `mondayEnd`, ...) was considered and
rejected: it's 14 nullable columns for a feature most users will touch
on 0-2 days, doesn't match the JSON-blob precedent this exact table
already set one field above, and every one of those 14 columns still
needs the same "null → fall back to default" logic the map gives for
free with one column.

### Migration

`schemaVersion` → `4` (next available, following the
`2026-07-21-pin-lock-toggles-fix-design.md` migration that took it to
`3`). New `if (from < 4)` block in `app_database.dart`'s `onUpgrade`:

```dart
if (from < 4) {
  // Per-weekday water reminder window overrides.
  await m.addColumn(
    waterSettingsTable,
    waterSettingsTable.reminderWindowOverrides,
  );
}
```

`m.addColumn` applies the table's `withDefault('{}')`, so existing rows
get `'{}'` (no overrides, identical behavior to today) with no backfill
code needed.

### Repository

`lib/features/water/data/repositories/water_repository_impl.dart`'s
`updateReminderSettings` gains one parameter and its JSON-codec
counterpart, mirroring the exact `jsonEncode`/`jsonDecode` pattern
already used for `quickAddAmountsMl` (`_settingsFromRow`, line ~334-341):

```dart
Future<Result<void>> updateReminderSettings({
  required bool enabled,
  required int intervalMinutes,
  required LocalTime windowStart,
  required LocalTime windowEnd,
  required Map<int, ({LocalTime start, LocalTime end})> windowOverrides,
}) async {
  ...
  reminderWindowOverrides: Value(jsonEncode({
    for (final entry in windowOverrides.entries)
      '${entry.key}': {
        'start': entry.value.start.format(),
        'end': entry.value.end.format(),
      },
  })),
  ...
}
```

`_settingsFromRow` decodes the same shape back:

```dart
reminderWindowOverrides: {
  for (final entry
      in (jsonDecode(row.reminderWindowOverrides) as Map<String, dynamic>)
          .entries)
    int.parse(entry.key): (
      start: LocalTime.parse((entry.value as Map)['start'] as String),
      end: LocalTime.parse((entry.value as Map)['end'] as String),
    ),
},
```

`WaterRepository`'s abstract `updateReminderSettings` signature (`lib/
features/water/domain/repositories/water_repository.dart:60`) and
`WaterController.updateReminderSettings` (`lib/features/water/
presentation/providers/water_controller.dart:89`) both gain the same
new required parameter, threaded straight through — no new controller
method, this is the same update call with one more field, matching how
`windowStart`/`windowEnd` were added originally.

### `notification_planner.dart` / `pendingNotifications()` consumption

**No change to `notification_planner.dart` itself.** `planNotifications()`
is generic over `PendingNotification` slots any module hands it — it has
no idea Water's slots come from a fixed window today or a per-weekday one
tomorrow, and that stays true. All the logic change is inside
`WaterModule.pendingNotifications()`, which already loops one day at a
time (`for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++)`)
— the per-day window lookup slots into that existing loop with one
change: resolve `windowStart`/`windowEnd` from `day`'s weekday before
generating slots for that day, instead of using the settings-level
constants directly:

```dart
for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++) {
  final day = localDayKey(now).addDays(dayOffset);
  final weekday = day.toDateTimeUtc().weekday; // 1=Mon..7=Sun
  final override = settings.reminderWindowOverrides[weekday];
  final windowStartTime = override?.start ?? settings.reminderWindowStart;
  final windowEndTime = override?.end ?? settings.reminderWindowEnd;

  var slot = day.toDateTimeUtc().toLocal().add(
    Duration(hours: windowStartTime.hour, minutes: windowStartTime.minute),
  );
  final windowEnd = day.toDateTimeUtc().toLocal().add(
    Duration(hours: windowEndTime.hour, minutes: windowEndTime.minute),
  );
  while (slot.isBefore(windowEnd) || slot.isAtSameMomentAs(windowEnd)) {
    if (slot.isAfter(now)) {
      notifications.add(
        PendingNotification(
          id: 'water_reminder_${day.year}...${slot.hour}_${slot.minute}',
          ...
        ),
      );
    }
    slot = slot.add(Duration(minutes: settings.reminderIntervalMinutes));
  }
}
```

`day.toDateTimeUtc().weekday` reuses `LocalDate`'s existing
`toDateTimeUtc()` (`lib/core/utils/local_date.dart`) rather than adding a
`weekday` getter to `LocalDate` — `DateTime.weekday` is already exactly
the 1-7 Mon-Sun int this needs, and going through the conversion that
already exists avoids introducing a second definition of "which day of
the week is this" to keep in sync. (If a later feature wants `LocalDate
.weekday` as a first-class getter, this is a one-line addition then —
not needed to ship this one.)

Existing notification ids (`water_reminder_YYYYMMDD_HH_MM`) are
unaffected — the id already embeds the actual computed hour/minute, so a
Tuesday slot at a different time than Monday's naturally gets a distinct
id with zero id-scheme change, and the diff/cap logic in
`planNotifications()` (dedup by `pending.id`, `existingIds.contains`)
keeps working exactly as it does today when a slot's time changes: old
id falls out of `cappedIds`/gets cancelled next plan pass, new id gets
scheduled. No special-case "the time changed for this weekday" handling
needed anywhere — this falls entirely out of the existing plan/diff
mechanism for free.

### UI

`lib/features/water/presentation/screens/water_settings_screen.dart`,
inside the existing `if (settings.reminderEnabled) ...` block, after the
current default-window `Row` of two `_TimeField`s:

- A new subsection, collapsed by default behind an `ExpansionTile` (or
  equivalent) titled something like *"Different times on some days"* —
  keeps the common case (no overrides) visually identical to today.
- Seven rows, one per weekday (Mon-Sun, localized weekday labels — reuse
  whatever this app's existing localized-weekday source is for the
  history calendar, `l10n`'s date symbols, rather than hardcoding
  English day names), each with:
  - A checkbox/switch: "override this day."
  - When checked, two `_TimeField`s (the same widget already used for
    the default window) bound to that weekday's start/end.
  - Unchecked days simply have no entry in `reminderWindowOverrides`
    (removed from the map on uncheck, not stored-but-disabled) — keeps
    the "absent = default" contract exact and the JSON blob minimal.
- Each edit calls the same `controller.updateReminderSettings(...)` with
  the full updated map (read-modify-write on the in-memory `Map`, same
  pattern the screen already uses for `quickAddAmountsMl`'s per-index
  update at line ~50-58 of the current file).

No new screen/route — this lives inside the existing reminder section of
`WaterSettingsScreen`.

### Export/import

`WaterModule._settingsToJson`/`importData` (`lib/features/water/
water_module.dart`) gain the same field, JSON-object-of-JSON-objects,
consistent with how the rest of that method already round-trips
`LocalTime` via `.format()`/`LocalTime.parse(...)`:

```dart
'reminderWindowOverrides': {
  for (final entry in settings.reminderWindowOverrides.entries)
    '${entry.key}': {
      'start': entry.value.start.format(),
      'end': entry.value.end.format(),
    },
},
```

Import reads it with a `?? const {}` fallback so restoring an older
export (missing the key) doesn't crash — same defensive pattern as the
PIN-lock spec's settings-import fallback.

## Out of scope

- Medicine: per-weekday times within a single `RepeatRule.weekdaySet`
  (already achievable today via two schedule rows on the same medicine
  — see "Why Medicine doesn't need this" above).
- Prayer: per-weekday pre-reminder offsets or per-prayer notification
  toggles — a real, different feature (shape: per-prayer × per-weekday
  boolean/offset grid, not a single time window), flagged as a
  candidate follow-up, not designed here.
- Per-weekday `reminderIntervalMinutes` override (cadence, not just
  window) — the value-record shape leaves room to add this later
  without a further migration; not built now because the concrete ask
  is a shifted *time*, not a different *cadence*.
- A first-class `LocalDate.weekday` getter on the shared util — this
  spec's one call site goes through the existing `toDateTimeUtc()`
  conversion instead; promote to a getter if a second caller needs it.
- `WaterSettingsScreen` UI polish beyond "seven rows behind a
  collapsed section" (e.g. a visual weekly grid/calendar picker) —
  functional parity with TickTick's *capability*, not its exact widget.

## Global Constraints

- New column: `water_settings.reminder_window_overrides` (`TextColumn`,
  JSON object, default `'{}'`).
- `schemaVersion` → `4`, migrated via `m.addColumn` with the table's own
  default backfilling existing rows to "no overrides."
- Map key convention: `DateTime.weekday` ints, 1=Monday..7=Sunday —
  matches `RepeatRule.weekdaySet`'s bitmask day-ordering elsewhere in the
  codebase (not zero-indexed, not Sunday-first).
- Absent day = falls back to `reminderWindowStart`/`reminderWindowEnd`;
  never store a day's entry equal to the default (UI removes the
  override entirely on uncheck, keeping "override present" and
  "different from default" the same thing).
- `notification_planner.dart` itself is untouched — all new logic is
  inside `WaterModule.pendingNotifications()`, one weekday-keyed lookup
  per day of its existing per-day loop.
- Import of an older backup (missing `reminderWindowOverrides` in its
  JSON) must not crash — fallback to `{}`, identical to a fresh
  install/today's behavior.
