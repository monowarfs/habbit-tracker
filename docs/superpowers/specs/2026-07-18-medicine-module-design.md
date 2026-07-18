# Medicine module — design

Run: implements FR-M-01..10 (`docs/product/functional-requirements.md`),
D-02..05/D-13/D-14 (`docs/product/decisions.md`), and the `medicines`/
`medicine_schedules`/`medicine_doses`/`medicine_stock_events` schema
(`docs/technical/database-design.md`). Whole module in one pass: domain,
data, presentation, notifications — matching the Run 08 (as-built)/Run 09
divergence note in `docs/engineering/phases-and-dod.md` (numbering there is
still pending reconciliation; this run is the "Medicine complete end to
end" milestone regardless of which number it ends up with).

## Scope decisions (resolved during brainstorming)

- **Repeat types:** `fixed_daily`, `every_n_days`, `weekday_set`, `prn`
  only — matches the committed schema's `frequency_type` enum and FR-M-03
  exactly. Monthly/day-of-month and specific-dates patterns (mentioned in
  the original run-09 task prompt) are **out of scope** — the committed
  schema doesn't define storage for them and no decision doc covers their
  edge-case behavior (31st/Feb clamping etc.). Add as a future run if
  needed, with its own D-xx decision entry first.
- **One run, full slice:** domain → data → presentation → notifications,
  not split across two runs.

## Domain (`lib/features/medicine/domain/entities/`, freezed)

- `Medicine` — id, name, dosageNote (String?), stockEnabled, stockCount
  (int?), stockThreshold (int?), stopWhenStockDepleted, consumptionPerDose
  (default 1), archivedAt (DateTime?)
- `MedicineSchedule` — id, medicineId, `RepeatRule`, startDate (LocalDate),
  endDate (LocalDate?), graceWindowMinutes (default 30)
- `RepeatRule` — freezed sealed union in
  `domain/entities/repeat_rule.dart`:
  - `RepeatRule.fixedDaily(timesOfDay: List<LocalTime>)`
  - `RepeatRule.everyNDays(intervalDays: int, timesOfDay: List<LocalTime>)`
  - `RepeatRule.weekdaySet(weekdaysMask: int, timesOfDay: List<LocalTime>)`
  - `RepeatRule.prn()` — no scheduled instances
- `MedicineDose` — id, medicineId, scheduleId, scheduledFor (DateTime,
  UTC), storedStatus (`MedicineDoseStatus`: `upcoming|done|skipped` —
  **not** `due`/`missed`, those are derived, see below), statusChangedAt
  (DateTime?), stockDeltaApplied (default 0)
- `MedicineStockEvent` — id, medicineId, doseId (String?), delta (int),
  reason (`MedicineStockEventReason`: `doseTaken|manualRefill|
  manualAdjustment|doseUndone`), occurredAt (DateTime)

## Repeat-rule engine (`domain/usecases/expand_repeat_rule.dart`)

Pure function, no `clock.now()` — caller supplies the range:

```dart
List<DateTime> expandRepeatRule({
  required RepeatRule rule,
  required LocalDate anchor,   // schedule.startDate
  required LocalDate rangeStart,
  required LocalDate rangeEnd, // inclusive
});
```

Returns UTC instants (times-of-day resolved against local calendar days
per D-14 — the caller passes the current device timezone implicitly via
`LocalDate`/`LocalTime` → UTC conversion helpers already in
`core/utils/local_date.dart`). `everyNDays` uses `daysSinceStart %
intervalDays == 0` per D-03, anchored to `startDate`, computed on local
calendar days (not a rolling duration) so DST transitions don't drift it.
`prn` always returns `[]`. `endDate` (if set) clips the range.

This is the single most heavily tested unit in the module —
`test/features/medicine/domain/repeat_rule_every_n_days_test.dart` runs a
14-day window that includes a DST transition date (per `testing.md`
suite 3), plus dedicated tests for `fixedDaily`/`weekdaySet`/`prn`.

## Dose status: derived, not scanned

`MedicineDose.storedStatus` only ever transitions via explicit action:
`upcoming` (initial, at materialization) → `done` or `skipped` (user
action, `statusChangedAt` set). Nothing ever writes `due` or `missed` to
the database — no background job scans and flips rows, matching the run
prompt's "evaluated lazily — no background job needed" instruction and
D-13's actual scope (D-13 only commits to *dose-row* materialization on a
rolling window, not status maintenance).

Pure function `domain/usecases/effective_dose_status.dart`:

```dart
MedicineDoseStatus effectiveDoseStatus({
  required MedicineDose dose,
  required DateTime now,
  required int graceWindowMinutes,
});
// storedStatus == done/skipped -> returned as-is
// storedStatus == upcoming:
//   now < scheduledFor                          -> upcoming
//   scheduledFor <= now <= scheduledFor+grace    -> due
//   now > scheduledFor+grace                     -> missed
```

`MedicineDoseStatus` (the widened enum used everywhere outside the raw DB
column) is `upcoming|due|done|missed|skipped`. Callers (dose timeline,
adherence stats) always go through `effectiveDoseStatus`, never read
`storedStatus` directly. Covered by
`test/features/medicine/domain/mark_dose_done_test.dart` (state machine
across the grace-window boundary, D-05) — this is the suite named in
`testing.md` #4.

## Materialization — reuses existing triggers, no new job

`domain/usecases/materialize_doses.dart`: `MaterializeDosesUseCase`, given
`clock.now()`, ensures `medicine_doses` rows exist for every active
schedule (not archived, not past `endDate`) across a 30-day rolling window
ahead of today (D-13's committed window), calling `expandRepeatRule` per
schedule and upserting rows keyed on `(medicineId, scheduledFor)` —
implementing the D-02/FR-M-02 collision rule (most-recently-created
schedule wins) by having the repository skip inserting a dose if one
already exists for that medicine+timestamp from a newer schedule, and
otherwise replace an older schedule's row.

D-13 says this window is "topped up on app foreground and via a daily
background refresh" — which are exactly the two triggers
`core/notifications` already has wired (`main.dart`'s
`WidgetsBindingObserver.didChangeAppLifecycleState` resume handler calls
`planAndApplyNotifications()`; the Android `notification_workmanager.dart`
periodic top-up calls the same). `MaterializeDosesUseCase.call()` is added
as one more step at both of those call sites, immediately before
`planAndApplyNotifications()` runs (notifications need doses to exist
first). No new lifecycle hook, no new WorkManager task.

## Stock

`domain/usecases/mark_dose_done.dart` / `mark_dose_skipped.dart` /
`undo_dose.dart`:
- Done, normal path: if `medicine.stockEnabled` and `stockCount >=
  consumptionPerDose`, decrement by `consumptionPerDose`, write a
  `MedicineStockEvent(reason: doseTaken, delta: -consumptionPerDose)`,
  set `stockDeltaApplied` on the dose, set `storedStatus = done`.
- Done, out-of-stock path (FR-M-05): if `stockEnabled` and `stockCount <
  consumptionPerDose`, the UI blocks the normal "Done" action and offers
  "Taken from other source" instead — marks `storedStatus = done` with
  `stockDeltaApplied = 0`, no stock event. `stopWhenStockDepleted` (D-04)
  only affects whether the *schedule* keeps generating future doses once
  stock hits 0, never whether a single dose can be marked done.
- If `stockEnabled` is false, Done always follows the no-stock-event path.
- Undo (un-marking a done dose): reverses via
  `MedicineStockEvent(reason: doseUndone, delta: +stockDeltaApplied)`,
  resets dose to `upcoming`.
- Skip: `storedStatus = skipped`, no stock event.
- Low stock: after any stock decrement, if `stockCount <=
  stockThreshold` and it wasn't already at/below threshold before this
  decrement (one-shot per crossing, FR-M-04), enqueue a
  `PendingNotification` with `sourceType: 'low_stock'` the next time
  `pendingNotifications()` runs.

`test/features/medicine/domain/medicine_stock_events_test.dart` (suite 5)
covers decrement/reversal/reconciliation exhaustively.

## Data (`lib/features/medicine/data/`)

- `tables/medicines_table.dart`, `medicine_schedules_table.dart`,
  `medicine_doses_table.dart`, `medicine_stock_events_table.dart` — column
  sets exactly as `database-design.md`'s Medicine module section.
- `repositories/medicine_repository_impl.dart` — no DAO (same precedent
  as Water, single caller). Soft-delete filtering (`deleted_at IS NULL`)
  on every read. Methods: CRUD for medicines/schedules, dose queries
  (today's flattened list, date-range for previews/history, per-medicine
  adherence aggregates), stock event insert, archive/restore.
- Registered in `app_database.dart`'s `@DriftDatabase(tables: [...])`
  list (4 new lines) and `schemaVersion` stays 1 since this is still
  pre-release (`onCreate: (m) => m.createAll()` covers it — no migration
  needed yet per the existing seam comment).
- `test/features/medicine/data/medicine_repository_impl_test.dart` (suite
  9) — temp/in-memory Drift DB, soft-delete filtering, UUID round-trip.

## Presentation (`lib/features/medicine/presentation/`)

- `screens/medicine_home_screen.dart` — today's dose timeline grouped by
  time-of-day, tap to take/skip, overdue (`missed`/`due`) visually
  distinct. This is testing.md suite 10's "Medicine dose list" widget
  test (empty/loading/populated/error states).
- `screens/medicine_list_screen.dart` — active/archived tabs.
- `screens/medicine_form_screen.dart` — multi-step add/edit (details →
  dosage/stock → schedule), one schedule created inline on first save;
  additional schedules added from the detail screen (D-02 supports
  multiple concurrent schedules per medicine).
- `screens/medicine_detail_screen.dart` — 7-day schedule preview (calls
  `expandRepeatRule` directly against all active schedules, not a DB
  read — matches how Water's stats avoid re-deriving through the
  materialized table when a pure computation is cheaper), stock card +
  refill action, history + adherence %.
- `screens/medicine_stats_screen.dart` — adherence chart reusing
  `core/widgets/charts/period_bar_chart.dart`, missed-doses list.
- `providers/medicine_providers.dart` + `medicine_controller.dart` —
  Riverpod codegen, mirrors `water_providers.dart`/`water_controller.dart`.
- `widgets/` — dose_tile, stock_card, schedule_summary_chip (small,
  single-purpose, same granularity as Water's widgets/ directory).

## `medicine_module.dart` (`HabitModule` registration)

Mirrors `water_module.dart` structure exactly:
- `id => 'medicine'`, `metadata` (icon, `ModuleAccents.medicine`)
- `routes` — `/medicine`, `/medicine/new`, `/medicine/:id`,
  `/medicine/:id/edit`, `/medicine/stats`
- `dashboardSummary` — next upcoming/due dose today, or "all done" state
- `pendingNotifications()` — calls `MaterializeDosesUseCase` is **not**
  here (that's the app-lifecycle/WorkManager hook, see above); this method
  just queries already-materialized doses in the engine's 3-day window
  (`_lookaheadDays = 3`, same constant/reasoning as `WaterModule`) plus
  any pending low-stock notification, maps to `PendingNotification` with
  `sourceType: 'medicine_dose'` / `'low_stock'` and
  `deepLinkRoute: '/medicine/dose/:id'` per `database-design.md`'s example.
- `onNotificationAction` — Done → `MarkDoseDoneUseCase` (decrements
  stock); Skip → `MarkDoseSkippedUseCase`; Snooze → no-op (streak-neutral,
  same precedent as Water; the 3-snooze cap is enforced by the existing
  ledger logic from Run 08, not duplicated here).
- `exportData`/`importData` — JSON payload of medicines + schedules +
  doses + stock events, mirroring `WaterModule`'s `_goalToJson`/
  `_entryToJson` pattern.

## Localization

`medicineHome*`, `medicineList*`, `medicineForm*`, `medicineDetail*`,
`medicineStats*` keys added to `lib/core/l10n/app_en.arb` and
`app_bn.arb`, same key-naming convention as the `water*` keys.

## Testing plan (mapped to `docs/strategies/testing.md`'s numbered suites)

1. `repeat_rule_every_n_days_test.dart` — suite 3, DST window, most
   dedicated attention.
2. `mark_dose_done_test.dart` — suite 4, full status state machine +
   D-04 stock-exhaustion behavior.
3. `medicine_stock_events_test.dart` — suite 5, decrement/undo/
   reconciliation.
4. `medicine_repository_impl_test.dart` — suite 9, temp Drift DB.
5. Widget test for the dose timeline (`medicine_home_screen_test.dart`)
   — suite 10, empty/loading/populated/error.
6. Plus: `expand_repeat_rule_test.dart` for `fixedDaily`/`weekdaySet`/
   `prn` (not just every-N-days), `medicine_module_test.dart` mirroring
   `water_module_test.dart`'s coverage of `pendingNotifications`/
   `onNotificationAction`.
7. The existing integration smoke test
   (fresh install → onboarding → log water → **mark a medicine dose
   done** → mark a prayer done → relaunch → verify persisted) gets its
   medicine step filled in once Prayer also exists; this run only needs
   its own piece to be correct in isolation (Prayer doesn't exist yet).

## Out of scope this run

- Monthly/specific-dates repeat patterns (see Scope decisions above).
- Prayer module (unrelated, separate run).
- PIN lock (`/lock` redirect stays a stub).
- Real cross-module notification-window tuning
  (`phases-and-dod.md` defers this to a later hardening run).
