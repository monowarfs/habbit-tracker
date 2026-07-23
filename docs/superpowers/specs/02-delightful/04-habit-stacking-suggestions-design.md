# Habit-Stacking Suggestions

**Date:** 2026-07-23
**Status:** Draft — pending review

## Problem

The atlas names a real, unexploited asset: this app already persists
per-event timestamps for all three modules on the same device, with no
cross-module correlation ever computed from them. Concretely:

- **Water** — `water_logs.loggedAt` (`lib/features/water/data/tables/water_logs_table.dart:22`),
  UTC millis, **may be backdated** (FR-W-05) — a caveat this design has to
  account for, not just a raw "when was this row inserted."
- **Medicine** — `medicine_doses.statusChangedAt`
  (`lib/features/medicine/data/tables/medicine_doses_table.dart:39`), UTC
  millis, non-null exactly when `status` moved to `'done'`/`'skipped'` —
  this is the real "when did the user act" timestamp, immune to
  backdating since doses are materialized ahead of time and marked in
  real time.
- **Prayer** — `prayer_records.statusChangedAt`
  (`lib/features/prayer/data/tables/prayer_records_table.dart:31`), same
  shape as Medicine's.

Read access already exists for all three: `WaterRepositoryImpl.allEntries()`,
`MedicineRepositoryImpl.dosesInRange(start, end)` (used today by
`medicine_module.dart:352`'s `medicine_first_dose` achievement), and
`PrayerRepositoryImpl.recordsInRange(start, end)` (`prayer_module.dart:335`).
No new raw-data plumbing is needed — only a new read-only query shape over
data that already exists.

**Nothing computes a cross-module correlation today.** `module_registry
.dart`'s `buildHabitModules` always instantiates all three modules — there
is no per-user "enabled modules" concept yet, so "users with 2+ modules
enabled" (the atlas's open question) reduces in the current codebase to
"users who have logged activity in 2+ modules," which the correlation
query itself already has to check (a module with zero rows in the window
simply produces no candidate).

**The one existing reminder-adjustment lever this can drive** is Water's:
`water_settings` (`lib/features/water/data/tables/water_settings_table.dart`)
already has `reminderWindowStart`/`reminderWindowEnd` plus a **per-weekday**
`reminderWindowOverrides` JSON map, and `WaterModule.pendingNotifications()`
(`lib/features/water/water_module.dart:124-169`) already starts each day's
first reminder slot exactly at `windowStart` (or that weekday's override),
then walks forward by `reminderIntervalMinutes`. `WaterRepositoryImpl
.updateReminderSettings(...)` (`water_repository_impl.dart:290`) already
takes a `Map<int, ({LocalTime start, LocalTime end})> windowOverrides` —
this is a pre-built, per-weekday nudge mechanism with an existing write
path; Medicine's and Prayer's reminders have no equivalent "movable window"
concept (Medicine's are schedule-rule-driven, Prayer's are solar-time-driven)
so accepting a suggestion is only actionable end-to-end for **Water as the
target habit** in v1 — see Out of scope.

## Design

### 1. Correlation heuristic (pure, no DB access)

New file `lib/core/stacking/habit_stack_correlation_usecase.dart`:

```dart
/// One correlation candidate: [sourceModuleId]'s (medicine/prayer)
/// completed-action time reliably precedes Water's logged time by a
/// short, consistent gap.
@immutable
class StackCorrelationResult {
  const StackCorrelationResult({
    required this.qualifyingDays,
    required this.totalDaysWithSource,
    required this.medianGapMinutes,
    required this.typicalSourceTime,
  });

  /// Days where a Water log followed the source action within [maxGap].
  final int qualifyingDays;

  /// Days in the window the source module had any completed action at all
  /// (the correlation's denominator — a module used on only 2 of 14 days
  /// can't produce "a real pattern" regardless of how tight the gap is).
  final int totalDaysWithSource;

  /// Median gap, source-action -> water-log, across qualifying days.
  final int medianGapMinutes;

  /// Median source-action wall-clock time, e.g. `08:15` — the anchor time
  /// an accepted suggestion nudges Water's reminder window to.
  final LocalTime typicalSourceTime;
}

/// Pure heuristic — explainable, not a model. [sourceByDay] is one
/// timestamp per day (the source module's first `done`/`prayed` action
/// that day); [targetByDay] is every Water `loggedAt` that day. A day
/// "qualifies" if any target timestamp falls in
/// `(source, source + maxGap]`. Returns `null` below [minQualifyingDays]
/// or below a 70% qualifying-day rate — both guard against "coincidence,
/// not a pattern."
StackCorrelationResult? findStackCorrelation({
  required Map<LocalDate, DateTime> sourceByDay,
  required Map<LocalDate, List<DateTime>> targetByDay,
  int windowDays = 14,
  int minQualifyingDays = 5,
  Duration maxGap = const Duration(minutes: 90),
});
```

Rule, spelled out: over the trailing `windowDays` (14) local days, for each
day the source module has a `done`/`prayed` timestamp, check whether any
Water `loggedAt` that same local day falls within `maxGap` (90 min) after
it. If at least `minQualifyingDays` (5) days qualify **and** qualifying
days are ≥70% of `totalDaysWithSource`, it's a real pattern. This is a
single pass over two small in-memory lists (at most 14 entries each) — no
new query complexity, no ML.

### 2. Where it runs

Piggybacks on the **existing app-resume trigger**, the same precedent
Medicine's `materializeDoses` already established (per `medicine_module
.dart`'s "no new call site" note) — `main.dart:91` (cold start) and
`main.dart:183` (`didChangeAppLifecycleState` → `resumed`) already call
`planAndApplyNotifications(db: db)`. Add one sibling call right next to
each: `unawaited(evaluateStackSuggestions(db: db))`
(`lib/core/stacking/habit_stack_suggestion_evaluator.dart`, new). No new
timer, no new WorkManager task — reuses the same two trigger points.

Cheap early-exit: the evaluator first checks each tracked pair's
`lastEvaluatedAt` (stored on the same row, see below) and skips
re-querying if it ran within the last 24h, so a user resuming the app
five times a day doesn't re-run the correlation query five times.

### 3. Suggestion/dismissal state — new table, not a settings blob

`app_settings`/`water_settings` are true **singleton** rows (CLAUDE.md's
established pattern) — this needs one row **per source-module pair**, with
its own lifecycle (`pending` → `accepted`/`dismissed`, with a cooldown
before a dismissed one can resurface). That's a multi-row, independently-
queryable shape, so it follows `achievements_table.dart`'s and
`notification_ledger_table.dart`'s precedent — a small dedicated Drift
table, not a JSON blob crammed into `app_settings`.

New `lib/core/database/tables/habit_stack_suggestions_table.dart`:

```dart
@DataClassName('HabitStackSuggestionRow')
class HabitStackSuggestionsTable extends Table {
  @override
  String get tableName => 'habit_stack_suggestions';

  /// Deterministic: `'{sourceModuleId}_{targetModuleId}'`, e.g.
  /// `'medicine_water'` — at most 2 rows exist in v1 (see Out of scope).
  TextColumn get id => text()();
  TextColumn get sourceModuleId => text()();
  TextColumn get targetModuleId => text()(); // always 'water' in v1
  /// `'pending'` | `'accepted'` | `'dismissed'`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get qualifyingDays => integer()();
  IntColumn get medianGapMinutes => integer()();
  /// `"HH:mm"`.
  TextColumn get typicalSourceTime => text()();
  IntColumn get lastEvaluatedAt => integer()();
  IntColumn get respondedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `AppDatabase`'s `@DriftDatabase(tables: [...])` list
(`lib/core/database/app_database.dart`) — the one central touchpoint every
new table needs per the class's own doc comment.

`lib/core/stacking/habit_stack_suggestion_repository.dart` — Drift CRUD,
same shape as `AchievementRepository`: `pendingSuggestion()` (stream, the
one row with `status == 'pending'`, if any — dashboard card's source),
`upsertEvaluation(...)` (writes the correlation result, only ever moves a
row **into** `pending` from nothing or from an expired `dismissed`
cooldown — never overwrites `accepted`), `accept(id)`, `dismiss(id)`.

**Cooldown rule:** a `dismissed` row is not re-evaluated back to `pending`
until 30 days after `respondedAt`, even if the pattern still holds — this
is the "doesn't nag repeatedly" requirement. An `accepted` row is never
re-evaluated again (the reminder is already adjusted; re-suggesting the
same stack is noise).

### 4. UI surface

New `lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart` —
a `Card` (not a snackbar: this needs to stay visible and hold two actions,
which a snackbar's single action slot can't do), inserted into
`dashboard_screen.dart`'s `ListView` between `_UpcomingStrip` and
`_QuickActionsRow` (`dashboard_screen.dart:69-71`), shown only when
`pendingSuggestion()` emits a non-null row:

```
"You usually log water shortly after your morning dose — want your
water reminder nudged to follow it?"
[ Nudge my reminder ]   [ Not now ]
```

`Nudge my reminder` → `repository.accept(id)` **and** applies it:
`ref.read(waterRepositoryProvider).updateReminderSettings(..., windowOverrides:
{...existing overrides, weekday: (start: typicalSourceTime, end: existing
windowEnd for that day)})` for whichever weekdays contributed a qualifying
day — reusing the exact existing per-weekday override mechanism, not a new
kind of reminder object. `Not now` → `repository.dismiss(id)`.

### l10n keys (both `app_en.arb`/`app_bn.arb`)

- `habitStackSuggestionMedicineToWater` — "You usually log water shortly
  after your morning dose — want your water reminder nudged to follow it?"
- `habitStackSuggestionPrayerToWater` — "You usually log water shortly
  after {prayer} — want your water reminder nudged to follow it?"
  (placeholder `prayer`, `String`)
- `habitStackSuggestionAccept` — "Nudge my reminder"
- `habitStackSuggestionDismiss` — "Not now"

## Out of scope

- **Medicine/Prayer as the retimed target.** Neither has a "movable
  reminder window" concept today (Medicine's reminders derive from
  `RepeatRule`, Prayer's from solar prayer times) — nudging either would
  need new reminder-scheduling machinery, not reuse of an existing one.
  v1 only ever retimes Water's reminder.
- **More than 2 tracked pairs.** Only `medicine → water` and
  `prayer → water` are evaluated (Water as source, or Medicine↔Prayer
  pairs, are not — no third module has a nudgeable target).
- **Suggestions spanning more than two habits** (explicitly out per the
  original draft) — unchanged.
- **A settings toggle to disable this feature entirely** — the per-
  suggestion dismiss + 30-day cooldown is judged sufficient friction
  control for a v1; add a global opt-out later if user feedback says
  otherwise.
- **Real-time/streaming correlation.** Runs only at the two existing
  app-resume trigger points, same cadence as notification re-planning.

## Global Constraints

- New files: `lib/core/stacking/habit_stack_correlation_usecase.dart`
  (pure), `habit_stack_suggestion_evaluator.dart` (DB-driven wiring, mirrors
  `notification_planner.dart`'s pure-logic/DB-wiring split), `habit_stack_
  suggestion_repository.dart`, `lib/core/database/tables/habit_stack_
  suggestions_table.dart`, `lib/features/dashboard/presentation/widgets/
  habit_stack_suggestion_card.dart`.
- **New table** `habit_stack_suggestions` — must be added to
  `AppDatabase`'s `@DriftDatabase(tables: [...])` list and to
  `docs/technical/database-design.md`, per that file's own convention.
- No new dependency — pure Dart correlation logic + existing Drift/Riverpod.
- No modification to `notification_planner.dart` or the notification
  engine itself; the accepted action only ever calls the Water module's
  own existing `updateReminderSettings`.
- Water's `loggedAt` may be backdated (FR-W-05) — the correlation query
  must use it as-is (it's the only timestamp Water stores) but this means
  a user who habitually backdates entries will never qualify; documented
  here as a known, accepted precision limit, not a bug to fix in this spec.
