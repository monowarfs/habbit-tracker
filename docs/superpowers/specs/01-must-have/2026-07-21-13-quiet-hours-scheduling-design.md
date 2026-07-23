# Quiet-Hours / Do-Not-Disturb-Aware Scheduling

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis (Must Have, inspired by TickTick) flags that
the app has no concept of "don't ring my phone while I'm asleep." Today,
`planNotifications()` (`lib/core/notifications/notification_planner.dart`)
schedules every module's `pendingNotifications()` output uniformly, clipped
only to the 3-day window and the 64-notification iOS cap
(`docs/strategies/notifications.md`). A user with a Water reminder every 2
hours and an overnight interval setting gets buzzed at 2am for water just as
readily as at 2pm — there is no time-of-day suppression at all.

Not every notification should be suppressible the same way, though:

- **Water** (`lib/features/water/water_module.dart:124-164`) only ever emits
  one kind of notification — a periodic "drink water" nudge,
  `sourceType: 'water_reminder'`. It's flexible and re-triggerable: missing
  one slot has no correctness consequence, the next slot fires a couple
  hours later regardless.
- **Medicine** (`lib/features/medicine/medicine_module.dart:130-189`) emits
  two different kinds from the same module: dose reminders
  (`sourceType: 'medicine_dose'`) are time-sensitive — they already have
  their own `grace_window_minutes` denormalization (CLAUDE.md) and a
  `missed`/`upcoming`/`due` state machine keyed off real time — and
  low-stock alerts (`sourceType: 'low_stock'`) which are informational and
  not time-critical at all (FR-M-04's "refill soon" has no deadline).
- **Prayer** (`lib/features/prayer/prayer_module.dart:124-`) emits prayer-time
  reminders, which are inherently time-sensitive by definition (a prayer
  reminder that fires after the prayer window means nothing) — always
  critical, never suppressible.

So the atlas's "non-critical vs critical" split doesn't line up with module
boundaries — it lines up with **individual notification instances**, since
Medicine straddles both categories itself. A blanket global suppression, or
even a per-module flag, would either wrongly suppress a medicine dose
reminder or wrongly fail to suppress a low-stock alert. The signal has to
live on `PendingNotification` itself.

## Design

### 1. `AppSettings` gains a global quiet-hours window

Three new fields on `AppSettings`
(`lib/features/settings/domain/entities/app_settings.dart`), following the
exact `pinEnabled`/`pinLockTimeoutSeconds` precedent the PIN lock spec used
for global toggles — and the `LocalTime`/`"HH:mm"` storage precedent
`WaterSettingsTable.reminderWindowStart`/`reminderWindowEnd`
(`lib/features/water/data/tables/water_settings_table.dart:30-36`) already
establishes for exactly this shape of data:

```dart
required bool quietHoursEnabled,
required LocalTime quietHoursStart,
required LocalTime quietHoursEnd,
```

- `quietHoursEnabled` — `bool`, DB default `false` (opt-in, same posture as
  `screenPrivacyEnabled`).
- `quietHoursStart` / `quietHoursEnd` — `LocalTime`
  (`lib/core/utils/local_date.dart:76`), DB default `22:00` / `07:00` — a
  reasonable sleep-window default, purely a starting point the user edits.

**Why global, not per-module:** the atlas explicitly frames this as one
sleep window ("suppress ... during sleep hours"), not "Water's own quiet
hours." Water already has its own `reminderWindowStart`/`reminderWindowEnd`
(`water_settings` table) for a different purpose — narrowing *when Water's
own reminders are eligible at all*. Quiet hours is orthogonal: a
cross-module suppression the planner applies on top of whatever each module
already decided to emit. One global setting also means Medicine's
low-stock alerts and any future module's non-critical notifications get the
behavior for free, with no new per-module settings screen required.

**DB table** — `AppSettingsTable`
(`lib/core/database/tables/app_settings_table.dart`) gains matching columns,
same style as `biometricEnabled`/`screenPrivacyEnabled`:

```dart
BoolColumn get quietHoursEnabled =>
    boolean().withDefault(const Constant(false))();
TextColumn get quietHoursStart =>
    text().withDefault(const Constant('22:00'))();
TextColumn get quietHoursEnd =>
    text().withDefault(const Constant('07:00'))();
```

**Migration** — `AppDatabase.schemaVersion`
(`lib/core/database/app_database.dart:54`) is currently `3` (the PIN
lock biometric/screen-privacy columns already landed as `if (from < 3)`).
This feature bumps it to `4`, adding a new `if (from < 4)` block per the
`onUpgrade`'s documented seam (`app_database.dart:81-83`):

```dart
if (from < 4) {
  // Quiet-hours-aware notification scheduling.
  await m.addColumn(appSettingsTable, appSettingsTable.quietHoursEnabled);
  await m.addColumn(appSettingsTable, appSettingsTable.quietHoursStart);
  await m.addColumn(appSettingsTable, appSettingsTable.quietHoursEnd);
}
```

**Repository** — `SettingsRepository`
(`lib/features/settings/domain/repositories/settings_repository.dart`)
gains one update method (mirrors `updateBiometricEnabled`'s single-bool
shape, but this needs three fields set together so a partial toggle can
never leave start > end applied without a compatible enabled state):

```dart
Future<Result<void>> updateQuietHours({
  required bool enabled,
  required LocalTime start,
  required LocalTime end,
});
```

`SettingsRepositoryImpl._update`/`_toDomain`
(`lib/features/settings/data/repositories/settings_repository_impl.dart`)
follow the existing `Value(...)`/`LocalTime.parse(row...)` pattern exactly
as `WaterRepositoryImpl` already does for `reminderWindowStart`/`End`
(`lib/features/water/data/repositories/water_repository_impl.dart:286-340`).
`restoreSettings` also needs the three fields added to its `Companion`
write, same as every other field there.

**Backup export/import** — `AppSettings` gains three more `required`
fields, so `export_orchestrator.dart`'s `_appSettingsToJson`
(`lib/core/backup/export_orchestrator.dart:39-47`) and
`import_orchestrator.dart`'s `AppSettings(...)` construction
(`lib/core/backup/import_orchestrator.dart:161-`) both need the three new
keys, with the same `?? false` / `?? '22:00'` / `?? '07:00'` fallback
pattern the PIN lock spec established for importing an older export that
predates these fields.

### 2. `PendingNotification` gains a suppressibility signal

`PendingNotification` (`lib/core/modules/habit_module.dart:37-66`) gains one
new required field, following the exact precedent CLAUDE.md documents for
`sourceType`/`deepLinkRoute` ("Correction (Run 08 implementation)" note on
the same class) and for `onNotificationAction` (added as a new `HabitModule`
capability in Run 08) — an additive field on an existing contract type, not
a new abstract method:

```dart
/// Whether this notification may be suppressed during the user's
/// quiet-hours window (`docs/superpowers/specs/2026-07-21-quiet-hours-
/// scheduling-design.md`). `false` for anything time-sensitive enough
/// that suppressing it would defeat its purpose.
final bool quietHoursSuppressible;
```

Every existing call site that constructs a `PendingNotification` sets it
explicitly (no default — forces each module to make the call per
notification instance, the same way `sourceType` already forces an explicit
choice per instance):

| Module | `sourceType` | `quietHoursSuppressible` |
|---|---|---|
| Water | `water_reminder` | `true` — flexible, re-triggerable |
| Medicine | `medicine_dose` | `false` — grace-window-bound, time-sensitive |
| Medicine | `low_stock` | `true` — informational, no deadline |
| Prayer | prayer reminder | `false` — meaningless once the prayer window passes |

This is deliberately *not* a per-module flag (`HabitModule.get
quietHoursAware` or similar) — Medicine needs both values from the same
`pendingNotifications()` call, so the signal has to travel with each
`PendingNotification`, not the module.

### 3. Where the filter hooks into `planNotifications()`

`planNotifications()` (`notification_planner.dart:35-69`) is pure and
synchronous by design — no DB/plugin dependency — specifically so it stays
unit-testable with zero mocking. The quiet-hours filter is another pure
predicate applied at exactly the same point the window filter already runs
(`notification_planner.dart:44-51`), before sort/cap/diff, so a suppressed
notification never occupies a cap slot a real notification could have used:

```dart
NotificationPlan planNotifications({
  required Map<String, List<PendingNotification>> pendingByModule,
  required List<NotificationLedgerRow> existingPending,
  required DateTime now,
  int windowDays = 3,
  int iosPendingCap = 64,
  QuietHours? quietHours,          // new, optional — null/disabled = no-op
}) {
  final windowEnd = now.add(Duration(days: windowDays));
  final flattened = <ModulePendingNotification>[];
  pendingByModule.forEach((moduleId, list) {
    for (final pending in list) {
      final inWindow = pending.scheduledAt.isAfter(now) &&
          pending.scheduledAt.isBefore(windowEnd);
      if (!inWindow) continue;
      final suppressed = pending.quietHoursSuppressible &&
          (quietHours?.contains(pending.scheduledAt) ?? false);
      if (suppressed) continue;
      flattened.add((moduleId: moduleId, pending: pending));
    }
  });
  // ...sort/cap/diff unchanged below this point.
}
```

`QuietHours` is a small new pure value type (lives next to
`NotificationPlan` in `notification_planner.dart`, no new file needed —
ponytail: one file already owns this pure logic, a second file for a
three-field value type is unjustified split):

```dart
/// A local wall-clock suppression window (`AppSettings.quietHours*`).
/// [start]/[end] may wrap past midnight (`start > end`).
@immutable
class QuietHours {
  const QuietHours({required this.start, required this.end});
  final LocalTime start;
  final LocalTime end;

  /// Whether local wall-clock time [instant] (already device-local —
  /// every module constructs `scheduledAt` via `.toLocal()`, e.g.
  /// `water_module.dart:132`) falls inside this window.
  bool contains(DateTime instant) {
    final t = LocalTime(instant.hour, instant.minute);
    if (start.compareTo(end) <= 0) {
      // Same-day window, e.g. 13:00-15:00.
      return t.compareTo(start) >= 0 && t.compareTo(end) < 0;
    }
    // Crosses midnight, e.g. 22:00-07:00.
    return t.compareTo(start) >= 0 || t.compareTo(end) < 0;
  }
}
```

`planAndApplyNotifications()` (`notification_planner.dart:76-113`) — the
DB/plugin-wiring wrapper — reads `AppSettings` once (it already has `db`,
same place `SettingsRepositoryImpl` is normally constructed from) and
passes `QuietHours(start: ..., end: ...)` when `quietHoursEnabled`, else
`null`:

```dart
final settings = await SettingsRepositoryImpl(db).watchSettings().first;
final plan = planNotifications(
  pendingByModule: pendingByModule,
  existingPending: existingPending,
  now: now ?? clock.now(),
  quietHours: settings.quietHoursEnabled
      ? QuietHours(start: settings.quietHoursStart, end: settings.quietHoursEnd)
      : null,
);
```

### 4. Suppressed notifications leave no ledger trace

Checked `notification_ledger_repository.dart` — `pendingRows()` answers
"what's currently registered with the OS," and today, anything the window
or 64-cap filter drops (`notification_planner.dart:46-55`) already leaves
**no** ledger row at all; it's simply absent from `toSchedule`. A quiet-hours
suppression is the same kind of decision — a would-be notification that
never gets scheduled — so it follows the identical precedent: no new
ledger `action` value, no new column, no schema touch. If a suppressed slot
is still valid once quiet hours end (e.g. a Water slot at 23:00 with quiet
hours until 07:00), the module's own `pendingNotifications()` on the next
re-planning trigger (app resume, WorkManager top-up) naturally re-evaluates
from `now` forward and produces whatever slot is next in its own cadence —
this spec does not add "reschedule the suppressed instance for
quiet-hours-end," since Water's reminder loop already produces a fresh slot
on its own schedule and re-firing the exact suppressed instant later would
contradict "suppress," not "defer," per the atlas's wording.

If suppression ever needs to be debuggable/visible later, `app_logger`
(`lib/core/logging/app_logger.dart`) is the lazy answer — a debug-level log
line in `planAndApplyNotifications()` when the suppressed count is nonzero
— not a ledger schema change. Not added in this pass since nothing has
asked for it yet.

### 5. Edge cases

- **Boundary instant** (`scheduledAt` exactly equal to `quietHoursStart` or
  `quietHoursEnd`): `QuietHours.contains` is `[start, end)` —
  start-inclusive, end-exclusive, matching `LocalTime.compareTo`'s existing
  total order and the same half-open convention `localDayRangeUtc`
  (`lib/core/utils/local_day.dart:37-46`) already uses for day boundaries.
  A dose scheduled exactly at 07:00 with quiet hours ending at 07:00 is
  *not* suppressed (already outside the window) — biased toward not
  suppressing at the boundary, since under-suppressing (occasionally noisy)
  is the safer failure mode than over-suppressing (a genuinely missed
  reminder) for a "Must Have" feature layered on top of critical modules.
- **Window crossing midnight** (e.g. 22:00-07:00, the default): handled by
  the `start.compareTo(end) <= 0` branch in `QuietHours.contains` above —
  the same "is `start <= end`, else treat as wrapping" logic every
  midnight-crossing time-range problem needs; no date arithmetic required
  since it's a pure wall-clock hour/minute comparison, not an instant
  comparison.
- **A window that is zero-width or inverted into a single point**
  (`start == end`): under the same-day branch (`start.compareTo(end) <= 0`
  is true when equal), `t >= start && t < end` can never be true since
  `start == end` — this degenerates to "never suppress," which is a safe,
  unsurprising behavior for a degenerate user-entered value rather than a
  crash or a full-day suppression. No explicit validation is added to
  reject `start == end` in the settings UI for the same ponytail reason:
  the degenerate case is already harmless, so guarding against it is
  solving a problem that doesn't exist.
- **DST transitions during the window:** `QuietHours.contains` deliberately
  never touches `DateTime` arithmetic or a `Location` — it only reads
  `instant.hour`/`instant.minute` off an already-local `DateTime` (every
  module's `scheduledAt` is already `.toLocal()` by construction, e.g.
  `water_module.dart:132`, `medicine_module.dart`'s `dose.scheduledFor`).
  Wall-clock hour/minute comparison is DST-immune by construction — "22:00"
  means 10pm local wall-clock time on both sides of a spring-forward/
  fall-back transition, which is exactly the semantic a sleep-hours setting
  wants (the user's bedtime doesn't shift by an hour because DST changed).
  This mirrors `core/utils/local_day.dart`'s own contrast between the
  cheap `.toLocal()` path (accepted for Water, per that file's docs) and
  the `tz.Location`-aware path (Prayer's precision needs) — quiet hours
  deliberately takes the cheap path on purpose, not by oversight, since a
  purely local wall-clock comparison has no ambiguity for DST to introduce
  in the first place (unlike computing a duration or an elapsed span across
  the transition, which is where DST bugs actually live).

### 6. Settings UI

New "Quiet hours" entry inside the existing **Notifications** section —
`SettingsHomeScreen`'s `/settings/notifications` route currently opens
`NotificationReliabilityScreen`
(`lib/core/notifications/notification_reliability_screen.dart`), a
troubleshooting-only screen per its own doc comment ("full ... instructions
... ship in Run 12; this run establishes the entry point"). Quiet hours is
a distinct concern (a setting, not troubleshooting guidance), so it gets
its own row on `SettingsHomeScreen`
(`lib/features/settings/presentation/screens/settings_home_screen.dart`)
under the same `_SectionHeader(l10n.settingsNotificationReliability)`-style
"Notifications" grouping — a toggle (`quietHoursEnabled`) plus two
`showTimePicker` fields (`quietHoursStart`/`End`), same interaction pattern
`WaterReminderSettingsScreen` (Water's own settings screen) already uses
for `reminderWindowStart`/`End` — no new picker widget needed, reuse
Flutter's built-in `showTimePicker`.

## Out of scope

- Per-module quiet-hours overrides (e.g. "Water respects quiet hours, but
  at a different window than the global one") — not requested by the atlas
  entry, and the global-window design above already gives Medicine's
  low-stock alerts the behavior with zero extra module-level settings.
- A "quiet hours" *display* affordance (e.g. showing a moon icon on
  suppressed dashboard items) — the atlas item is about suppressing the
  notification, not about surfacing suppression state in the UI.
- Any change to Medicine's dose reminders, Prayer's reminders, or the
  grace-window/missed-dose state machine — both stay `quietHoursSuppressible:
  false` and are entirely unaffected by this feature by design.
- A "snooze quiet hours until tomorrow" or per-instance override control —
  not in the atlas entry; the existing Done/Snooze/Skip action set is
  unchanged.
- Reading the OS-level Do-Not-Disturb state (the feature name references
  DND, but the actual ask — confirmed against the atlas entry's own
  wording, "suppress ... reminders during sleep hours" — is an app-defined
  time window, not an OS DND API integration, which would need
  platform-specific permissions this app doesn't otherwise request).

## Global Constraints

- New `AppSettings` fields: `quietHoursEnabled` (`bool`, default `false`),
  `quietHoursStart` (`LocalTime`, default `22:00`), `quietHoursEnd`
  (`LocalTime`, default `07:00`).
- New DB columns on `app_settings`: `quiet_hours_enabled` (bool, default
  `false`), `quiet_hours_start` (text, default `'22:00'`),
  `quiet_hours_end` (text, default `'07:00'`).
- `schemaVersion` → `4`, migrated via `m.addColumn` under `if (from < 4)`.
- `PendingNotification` gains a new required `bool quietHoursSuppressible`
  field — every existing construction site (Water: 1, Medicine: 2, Prayer:
  1+) must set it explicitly; no default value.
- `planNotifications()` gains one new optional parameter (`QuietHours?
  quietHours`, default `null`) — fully backward compatible with existing
  callers/tests that don't pass it.
- Suppressed notifications get no `notification_ledger` row and are not
  retried/rescheduled for after quiet hours end — "suppress," not "defer."
- `QuietHours.contains` is `[start, end)`, wall-clock-only (no
  `DateTime`/`Location` arithmetic), so it is DST-immune by construction.
- Import of an older backup (missing the three new JSON keys) must not
  crash — fallback to the same defaults as a fresh install
  (`false`/`'22:00'`/`'07:00'`).
