# Adaptive Reminder Timing

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Every module today schedules reminders at fixed, user-chosen times, but real
adherence data (when a user actually taps Done vs. lets a notification sit
until Snooze or Skip) already exists in the notification ledger and goes
unused. Users who habitually respond an hour later than their configured
time are effectively being reminded at the wrong moment every single day,
which is exactly the kind of silent friction that erodes streaks and, over
weeks, causes disengagement. No competitor benchmarked in the atlas does
this well, so it's a genuine differentiator for this app's "just works"
positioning rather than a catch-up feature.

## Goals
- Detect, per reminder slot, a consistent gap between scheduled time and
  actual Done-action timestamp over a rolling window of history.
- Suggest (or, if the user opts in to auto-adjust, silently apply) a nudged
  reminder time that better matches observed behavior.
- Work identically across Water, Medicine, and Prayer reminder slots since
  all three already write to the same notification ledger shape.

## Non-goals / out of scope
- No cross-device sync of learned timing (there is no account/cloud layer).
- No machine-learning model, embeddings, or training pipeline of any kind.
- Not a replacement for user-set schedules — always a suggestion/nudge on
  top of, never a silent override without some visible signal (exact UX,
  e.g. a one-time prompt vs. a settings toggle, is left to the
  implementation round).
- Does not touch Snooze/Skip semantics themselves, only future scheduling.

## Proposed approach (high-level)
The mechanism is pure on-device arithmetic over existing history, not a
model: read recent entries from the notification ledger for a given
module/slot, compute the median (or similar robust statistic) offset
between each notification's scheduled time and the timestamp of the
Done action that eventually closed it out, and if that offset is
consistently large and stable across enough samples, treat it as a signal
worth surfacing. The notification planner already owns the "what time do
we schedule next" logic (the 3-day/64-cap materialization window), so this
becomes an additional input alongside the user's configured time — e.g. a
`suggestedOffsetMinutes` value the planner can fold in, gated behind
whatever consent/opt-in mechanism the implementation round designs. Each
module's own reminder-slot definition (Water's quick-add reminders,
Medicine's dose reminders, Prayer's per-prayer reminders) would need to
expose enough identity for the ledger query to group history correctly.

## Dependencies & prerequisites
- Sufficient notification ledger history to compute a meaningful signal
  (a brand-new install has nothing to learn from).
- A decision on UX for surfacing/confirming the adjustment (silent
  auto-shift vs. an explicit "we noticed you usually respond around X,
  want to move this reminder?" prompt).
- No new packages — this is arithmetic over data already being persisted.

## Open questions for the implementation round
- What's the minimum sample size and window length before a suggestion is
  considered statistically meaningful enough to act on?
- Should this be per-slot (e.g. one Medicine dose time) or per-module
  (an overall shift applied to all of a module's reminders)?
- How does this interact with a user who deliberately keeps irregular
  hours (e.g. shift workers) — is there a way to detect "too noisy to
  learn from" and simply not suggest anything?
- Does the suggestion get its own row/flag in the notification ledger or
  a new lightweight table for storing the learned offset?

## Effort & sequencing notes
Complexity M — the arithmetic itself is simple, but wiring a new input
into the existing notification planner touches a well-tested pure
function and needs care not to regress its existing window/cap/diff
logic. Reasonable to sequence after any other notification-planner
changes settle, so this isn't competing with unrelated edits to the same
file.

---

## Implementation Plan (Low-Level)

### Schema Changes

**No new Drift tables or columns required.** The adaptive offset is a derived, non-persisted value computed at read time from the existing `notification_ledger` table — same pattern as dose status in Medicine. The user's per-module opt-in toggle is stored in the existing `AppSettings` table via new columns.

**New columns on `app_settings` table** (DDL):
```sql
ALTER TABLE app_settings ADD COLUMN adaptive_reminder_enabled INTEGER NOT NULL DEFAULT 0;
```

This single boolean column gates the feature globally. Per-module granularity is enforced in the use-case logic (the use case only returns offsets for modules whose entries exist in the ledger), not in the schema. The toggle is a single on/off because the "nudge UX" prompt is the per-module surface — the user sees suggestions module-by-module.

**Add to `app_settings_table.dart`:**
```dart
BoolColumn get adaptiveReminderEnabled =>
    boolean().withDefault(const Constant(false))();
```

**Migration:** Add to `onUpgrade` in `app_database.dart`:
```dart
if (from < 8) {
  await m.addColumn(appSettingsTable, appSettingsTable.adaptiveReminderEnabled);
}
```
Bump `schemaVersion` to `8`.

### Domain Entities

**File:** `lib/core/notifications/entities/reminder_adjustment.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_adjustment.freezed.dart';

/// A computed reminder-time adjustment for one module/slot pair, derived
/// from notification ledger history.
@freezed
sealed class ReminderAdjustment with _$ReminderAdjustment {
  /// Creates a reminder adjustment.
  const factory ReminderAdjustment({
    /// The module this adjustment applies to (e.g. 'water', 'medicine').
    required String moduleId,

    /// The notification source type (e.g. 'water_reminder', 'medicine_dose').
    /// null means a module-wide adjustment (all slots shifted equally).
    String? sourceType,

    /// Signed offset in minutes from the originally-scheduled time.
    /// Positive = user consistently responds late (shift reminder later).
    /// Negative = user consistently responds early (shift reminder earlier).
    required int offsetMinutes,

    /// Number of ledger entries used to compute this offset.
    required int sampleCount,

    /// Confidence level: 'high' (>=20 samples), 'medium' (>=10), 'low'
    /// (<10). Only 'high' is acted on by the planner; others are surfaced
    /// as suggestions only.
    required String confidence,

    /// Rolling window in days used for sample collection.
    required int windowDays,
  }) = _ReminderAdjustment;
}
```

### Use Case Signatures

**File:** `lib/core/notifications/usecases/calculate_adaptive_offset_use_case.dart`

```dart
import 'package:habit_tracker/core/notifications/entities/reminder_adjustment.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';

/// Computes median time offsets between scheduled notification time and
/// Done-action timestamp per module/slot from notification ledger history.
///
/// Pure over the repository — no DB writes, no side effects. The planner
/// consumes the returned list to apply optional time nudges.
class CalculateAdaptiveOffsetUseCase {
  const CalculateAdaptiveOffsetUseCase(this._ledger);

  final NotificationLedgerRepository _ledger;

  /// Returns one [ReminderAdjustment] per (moduleId, sourceType) pair
  /// that has enough samples to be meaningful.
  ///
  /// [windowDays] defaults to 30 (rolling lookback).
  /// [minSamples] defaults to 10 (below this, returns nothing).
  /// [maxOffsetMinutes] defaults to 120 (clamp: never shift more than 2h).
  Future<List<ReminderAdjustment>> execute({
    int windowDays = 30,
    int minSamples = 10,
    int maxOffsetMinutes = 120,
  }) async { ... }
}
```

**Core algorithm (inside `execute`):**
1. Query `notification_ledger` for rows where `action == 'done'` AND `actionAt IS NOT NULL` AND `scheduledFor` is within the rolling window.
2. Group by `(moduleId, sourceType)`.
3. For each group, compute `actionAt - scheduledFor` for every row → list of offset-millis.
4. Compute the **median** (not mean — robust to outliers like overnight Snooze chains).
5. Convert median to minutes, clamp to `[-maxOffsetMinutes, maxOffsetMinutes]`.
6. Classify confidence: `sampleCount >= 20` → `'high'`, `>= 10` → `'medium'`, else skip entirely (below `minSamples`).
7. Return one `ReminderAdjustment` per group.

### Data Layer

**Modify:** `lib/core/notifications/notification_ledger_repository.dart`

Add one query method:
```dart
/// All actioned 'done' rows within [windowDays] of [now], grouped ready
/// for offset computation. Returns raw rows — the use case does the
/// math.
Future<List<NotificationLedgerRow>> actionedDoneRows({
  required int windowDays,
  required DateTime now,
}) async {
  final since = now.subtract(Duration(days: windowDays));
  return (_db.select(
    _db.notificationLedgerTable,
  )..where(
    (t) =>
        t.deletedAt.isNull() &
        t.action.equals('done') &
        t.actionAt.isNotNull() &
        t.scheduledFor.isBiggerOrEqualValue(
          since.toUtc().millisecondsSinceEpoch,
        ),
  ))
      .get();
}
```

**Modify:** `lib/features/settings/domain/entities/app_settings.dart`

Add `adaptiveReminderEnabled` field to the `AppSettings` Freezed class.

**Modify:** `lib/features/settings/data/repositories/settings_repository_impl.dart`

Update `_settingsFromRow` and `updateSettings` to include the new column.

**Modify:** `lib/features/settings/presentation/providers/` — expose `adaptiveReminderEnabled` toggle.

### Presentation Layer

**Modify:** `lib/core/notifications/notification_planner.dart`

The `planNotifications` pure function gains an optional parameter:
```dart
NotificationPlan planNotifications({
  required Map<String, List<PendingNotification>> pendingByModule,
  required List<NotificationLedgerRow> existingPending,
  required DateTime now,
  int windowDays = 3,
  int iosPendingCap = 64,
  QuietHours? quietHours,
  // NEW: optional per-module offset overrides
  Map<String, int>? moduleOffsetsMinutes,
}) { ... }
```

Inside the function, when `moduleOffsetsMinutes` is provided and contains an entry for the current module, adjust `pending.scheduledAt` by adding the offset:
```dart
final adjustedScheduledAt = pending.scheduledAt.add(
  Duration(minutes: moduleOffsetsMinutes?[moduleId] ?? 0),
);
// Use adjustedScheduledAt for window filtering and for the final
// scheduledAt passed to NotificationService.schedule()
```

**Modify:** `planAndApplyNotifications` wiring in the same file — before calling `planNotifications`, check the settings toggle and, if enabled, run `CalculateAdaptiveOffsetUseCase` against the ledger to build the `moduleOffsetsMinutes` map.

**Modify:** `lib/features/settings/presentation/screens/` — add an "Adaptive Reminders" toggle in the existing Settings screen, with a brief explainer text.

### Localization

**Modify:** `lib/core/l10n/app_en.arb` and `app_bn.arb` — add keys for:
- `adaptiveReminderTitle` / `adaptiveReminderDescription`
- `adaptiveReminderToggleLabel`
- `adaptiveReminderConfidenceHigh` / `adaptiveReminderConfidenceMedium`
- `adaptiveReminderSuggestionBody`

### Testing Strategy

| Test file | What it covers |
|-----------|---------------|
| `test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart` | Pure unit tests: offset computation with known ledger snapshots, median calculation, min-sample gating, max-offset clamping, edge cases (all same time = 0 offset, alternating offsets = median detection), empty ledger returns empty list. |
| `test/core/notifications/notification_planner_test.dart` (extend existing) | Test the new `moduleOffsetsMinutes` parameter: offset shifts `scheduledAt`, offset of 0 is identity, absent module key is no-op, combined with quiet hours. |
| `test/features/settings/...settings_repository_test.dart` (extend existing) | `adaptiveReminderEnabled` round-trips through DB write/read. |

### File Paths

**Create:**
- `lib/core/notifications/entities/reminder_adjustment.dart`
- `lib/core/notifications/entities/reminder_adjustment.freezed.dart` (generated)
- `lib/core/notifications/usecases/calculate_adaptive_offset_use_case.dart`
- `test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart`

**Modify:**
- `lib/core/database/tables/app_settings_table.dart` — add `adaptiveReminderEnabled` column
- `lib/core/database/app_database.dart` — bump schemaVersion to 8, add migration
- `lib/core/notifications/notification_ledger_repository.dart` — add `actionedDoneRows()` query
- `lib/core/notifications/notification_planner.dart` — add `moduleOffsetsMinutes` param, adjust scheduling logic
- `lib/features/settings/domain/entities/app_settings.dart` — add field
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — read/write new field
- `lib/core/l10n/app_en.arb` — new strings
- `lib/core/l10n/app_bn.arb` — new strings

### Sequencing

| Task | Depends on | Effort |
|------|-----------|--------|
| T1: Add `adaptiveReminderEnabled` column + migration + entity field | None | S |
| T2: Create `ReminderAdjustment` Freezed entity | None | S |
| T3: Add `actionedDoneRows()` to ledger repository | None | S |
| T4: Implement `CalculateAdaptiveOffsetUseCase` | T2, T3 | M |
| T5: Add `moduleOffsetsMinutes` to `planNotifications` and wiring | T1, T4 | M |
| T6: Settings toggle UI + localization | T1 | S |
| T7: Unit tests for use case + planner changes | T4, T5 | M |
| T8: Integration test / manual verification | T5, T6, T7 | S |

**Critical path:** T1 → T4 → T5 → T7
