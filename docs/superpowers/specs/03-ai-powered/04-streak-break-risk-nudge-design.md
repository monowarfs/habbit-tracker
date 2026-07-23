# Streak-Break Risk Nudge

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Streaks are one of this app's core retention mechanics (per the existing
`day_status_streaks` reporting logic and each module's own streak
calculators), but today a user only finds out they broke a streak after
midnight, when it's too late to do anything about it. Duolingo's
streak-freeze nudge pattern shows that a single, well-timed late-day
reminder — "you haven't logged today, and yesterday you had by this
time" — meaningfully reduces accidental streak breaks caused by simply
forgetting, as opposed to a deliberate lapse. This is a targeted,
low-noise addition: one extra nudge, only when genuinely at risk.

## Goals
- Detect, for a given user/module/day, that historical behavior suggests
  a log/action should have already happened by this point in the day but
  hasn't yet.
- Send at most one additional, gentle nudge per day per module when that
  condition is met, distinct from the module's regular scheduled
  reminders.
- Avoid nagging: only fire when an active streak is actually at risk, not
  every day regardless of streak state.

## Non-goals / out of scope
- No prediction model — this is a same-time-yesterday (or same-time-median-
  of-recent-days) comparison, not a trained classifier.
- Does not modify the existing streak calculation logic itself, only adds
  a notification trigger informed by it.
- Not a per-module bespoke feature — the goal is one shared mechanism all
  three modules can plug into via their own log-history data, though each
  module's "did the relevant thing happen today" check is necessarily
  module-specific (a Water log vs. a Medicine dose vs. a Prayer record).

## Proposed approach (high-level)
Pure local pattern detection, no model: for each module, look at the
current local day, find the typical time-of-day by which the user has
historically already logged/completed today's expected action (e.g. the
median completion time over recent days with an active streak), and if
that time has passed today with no corresponding action yet, and an
active streak would break if the day ends without one, schedule a single
extra local notification before midnight. This reuses each module's own
existing streak-calculation use case (Water's `CalculateWaterStreakUseCase`
and its Medicine/Prayer equivalents) to determine "is a streak actually at
risk", and rides the same `core/notifications` scheduling/ledger
infrastructure every other reminder already uses — this is a new
*trigger condition* for the existing engine, not a new engine.

## Dependencies & prerequisites
- Each module's existing streak calculators and log/dose/record history.
- The existing notification scheduling and ledger infrastructure (this
  nudge is just another notification content type flowing through it).
- A decision on how "historically logs by roughly this time" is defined
  robustly enough to avoid false positives for irregular users.

## Open questions for the implementation round
- Where does the "is it late enough in the day to worry" check run —
  piggybacking on the existing app-resume/WorkManager top-up triggers, or
  does it need its own scheduled check point?
- How many days of history are needed before the app trusts a "typical
  time" pattern enough to nudge on it (a brand-new streak has nothing to
  compare against)?
- Should the user be able to opt out of this nudge type specifically,
  separate from disabling a module's reminders entirely?
- Does this apply per-module independently, or is there value in a single
  combined "you're at risk of breaking N streaks today" nudge?

## Effort & sequencing notes
Complexity M — the detection logic is straightforward arithmetic over
existing streak/history data, but getting the "at risk" threshold right
without becoming an annoying false-positive machine needs real tuning and
probably a period of dogfooding before it's trustworthy. Reasonable to
sequence after adaptive reminder timing (item 01), since both read from
similar historical-behavior data and might share some groundwork.

## Implementation Plan (Low-Level)

### Schema changes

**No new Drift tables.** This feature reads existing tables only:

- `app_settings` — add one boolean column for per-module opt-out (see
  below).
- `prayer_records` — read-only for Prayer's completion-time history.
- `prayer_qadha_counters` — read-only for streak state.
- `water_logs` / `water_goals` — read-only for Water's completion-time
  history.
- `medicine_doses` / `medicines` — read-only for Medicine's
  completion-time history.
- `notification_ledger` — to check if today's nudge was already sent.

**New column on `app_settings`:**

```sql
-- Drift table class addition in core/database/tables/app_settings_table.dart
streakBreakNudgeEnabled INTEGER NOT NULL DEFAULT 1  -- boolean, per-module
```

Actually, per-module opt-out is better handled as a `Set<String>` of
disabled module ids stored as a JSON text column, since a single boolean
cannot represent "Water off, Medicine on, Prayer on":

```dart
// In core/database/tables/app_settings_table.dart — new column
TextColumn get streakBreakNudgeDisabledModules =>
    text().withDefault(const Constant('[]'))();
```

Stored as a JSON array of module id strings, e.g. `["water"]`. Parsed
into `Set<String>` at the domain boundary. This avoids a new table for
a three-value config.

**DDL (migration note):**

```sql
ALTER TABLE app_settings ADD COLUMN streak_break_nudge_disabled_modules TEXT NOT NULL DEFAULT '[]';
```

### Domain entities

**File:** `lib/features/core/streak_break/domain/entities/streak_break_risk.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_break_risk.freezed.dart';

/// Risk level for an active streak that hasn't been logged yet today.
enum StreakBreakRiskLevel {
  /// User is past the median completion time — high risk.
  high,

  /// User is approaching the median completion time — moderate risk.
  moderate,

  /// Not enough history to determine risk, or streak isn't at risk.
  none,
}

/// Detected streak-break risk for one module on a given day.
@freezed
sealed class StreakBreakRisk with _$StreakBreakRisk {
  /// Creates a streak break risk.
  const factory StreakBreakRisk({
    required String moduleId,
    required StreakBreakRiskLevel riskLevel,
    required int currentStreak,
    required Duration typicalCompletionTime,
    required bool hasLoggedToday,
    required bool isActive,
  }) = _StreakBreakRisk;
}
```

### Use case signatures

**File:** `lib/features/core/streak_break/domain/usecases/detect_streak_break_risk.dart`

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/core/streak_break/domain/entities/streak_break_risk.dart';

/// Completion record for a single day — the time-of-day the user
/// completed their action.
class CompletionRecord {
  /// Creates a completion record.
  const CompletionRecord({
    required this.day,
    required this.completedAt,
  });

  /// The local day.
  final LocalDate day;

  /// The wall-clock time the user completed the action (today's action).
  final DateTime completedAt;
}

/// Detects whether a module's active streak is at risk of breaking
/// today, based on historical completion timing.
///
/// Pure — no database or plugin dependency. Receives all data as
/// arguments.
class DetectStreakBreakRiskUseCase {
  /// Creates the use case.
  const DetectStreakBreakRiskUseCase({
    this.minDaysOfHistory = 3,
  });

  /// Minimum days of completion history needed before the detector
  /// trusts a "typical time" pattern enough to nudge.
  final int minDaysOfHistory;

  /// Evaluates streak-break risk for [moduleId].
  ///
  /// [completionHistory] is the list of days the user completed the
  /// action, with the time-of-day they completed it.
  /// [today] is the current local day.
  /// [now] is the current wall-clock time.
  /// [currentStreak] is the current streak length (0 = no active streak).
  StreakBreakRisk execute({
    required String moduleId,
    required List<CompletionRecord> completionHistory,
    required LocalDate today,
    required DateTime now,
    required int currentStreak,
  });
}
```

**Key logic:**
1. If `currentStreak == 0`, return `StreakBreakRiskLevel.none` (no
   streak to protect).
2. If `completionHistory.length < minDaysOfHistory`, return `none`
   (not enough data to trust a pattern).
3. Compute the median completion time-of-day from the history (sorted
   by time-of-day, pick the middle value).
4. If today's time-of-day is past the median, and no completion has
   been logged today, return `high` risk.
5. If today is within 30 minutes before the median, return `moderate`.
6. Otherwise `none`.

### Data layer

No new repository is needed. The use case is pure and receives data
from each module's existing repository methods. The integration wiring
lives in the notification re-planning trigger.

**File to modify:** `lib/core/notifications/notification_planner.dart`

Add streak-break nudge detection to `planAndApplyNotifications`:

```dart
// After the existing per-module pendingNotifications() loop,
// add streak-break nudge detection:
for (final module in modules) {
  final risk = await detectStreakBreakRisk(module, db, now);
  if (risk != null && risk.riskLevel != StreakBreakRiskLevel.none) {
    // Add a single PendingNotification with sourceType 'streak_break_nudge'
    // ID: 'streak_nudge_${module.id}_${today.year}${today.month}${today.day}'
    // This naturally deduplicates across re-planning passes.
  }
}
```

Each module needs a method to supply completion-time history. Add to
`HabitModule`:

```dart
// Optional override — default returns null (no streak nudge).
Future<List<CompletionRecord>?> streakBreakHistory() async => null;
```

Water, Medicine, and Prayer each implement this by querying their
respective repositories for historical completion times.

### Presentation layer

**No new screens.** The feature is notification-only.

**Files to modify:**

- `lib/features/settings/presentation/screens/settings_screen.dart` —
  add a "Streak-break nudge" toggle with per-module chips (Water /
  Medicine / Prayer) beneath the existing notification settings section.
- `lib/core/l10n/app_en.arb` — add localized strings:
  - `streakBreakNudgeTitle`: "Streak-break nudge"
  - `streakBreakNudgeDescription`: "Gentle reminder when a streak is at risk"
  - `streakBreakNudgeBody`: "You haven't logged {module} today, and your streak is at risk."
- `lib/core/l10n/app_bn.arb` — Bangla equivalents.

**Notification content:**
- Title: "Streak at risk" (localized)
- Body: Module-specific gentle nudge, e.g. "You haven't logged Water
  today — your {N}-day streak is at risk."
- `sourceType`: `'streak_break_nudge'`
- `deepLinkRoute`: module's home route (`/water`, `/medicine`, `/prayer`)
- `quietHoursSuppressible`: `true` (gentle, not time-critical)

### Settings integration

**Files to modify:**

- `lib/features/settings/domain/entities/app_settings.dart` — add
  `Set<String> streakBreakNudgeDisabledModules` field.
- `lib/features/settings/domain/repositories/settings_repository.dart` —
  add `updateStreakBreakNudgeDisabledModules(Set<String> modules)`.
- `lib/features/settings/data/repositories/settings_repository_impl.dart` —
  implement the new method, serialize/deserialize the JSON array.

### Notification dedup

The nudge ID is `streak_nudge_{moduleId}_{YYYYMMDD}` — one per module
per day, naturally deduplicated by the existing `notification_ledger`
dedup logic (same `pending.id` is not re-scheduled if already present).

### Testing strategy

**New test files:**

1. `test/features/core/streak_break/domain/usecases/detect_streak_break_risk_test.dart`
   - Case: `currentStreak == 0` → riskLevel none
   - Case: fewer than `minDaysOfHistory` records → riskLevel none
   - Case: past median, no log today → riskLevel high
   - Case: within 30 min of median → riskLevel moderate
   - Case: well before median → riskLevel none
   - Case: already logged today → `hasLoggedToday == true`, riskLevel none
   - Edge case: exactly at median time
   - Edge case: history with all same time-of-day
   - Edge case: DST transition day (median may be ambiguous)

2. `test/core/notifications/streak_break_nudge_integration_test.dart`
   - Verify nudge PendingNotification has correct id, sourceType,
     deepLinkRoute, quietHoursSuppressible
   - Verify dedup: same module same day → only one nudge even after
     multiple re-planning passes
   - Verify opt-out: disabled module produces no nudge

### File paths

**Create:**

- `lib/features/core/streak_break/domain/entities/streak_break_risk.dart`
- `lib/features/core/streak_break/domain/entities/streak_break_risk.freezed.dart`
  (generated)
- `lib/features/core/streak_break/domain/usecases/detect_streak_break_risk.dart`
- `test/features/core/streak_break/domain/usecases/detect_streak_break_risk_test.dart`
- `test/core/notifications/streak_break_nudge_integration_test.dart`

**Modify:**

- `lib/core/modules/habit_module.dart` — add optional
  `streakBreakHistory()` method
- `lib/core/notifications/notification_planner.dart` — add streak-break
  nudge detection in `planAndApplyNotifications`
- `lib/features/water/water_module.dart` — implement `streakBreakHistory()`
- `lib/features/medicine/medicine_module.dart` — implement
  `streakBreakHistory()`
- `lib/features/prayer/prayer_module.dart` — implement
  `streakBreakHistory()`
- `lib/core/database/tables/app_settings_table.dart` — add
  `streakBreakNudgeDisabledModules` column
- `lib/features/settings/domain/entities/app_settings.dart` — add
  disabled modules field
- `lib/features/settings/domain/repositories/settings_repository.dart` —
  add update method
- `lib/features/settings/data/repositories/settings_repository_impl.dart` —
  implement update
- `lib/features/settings/presentation/screens/settings_screen.dart` —
  add toggle UI
- `lib/core/l10n/app_en.arb` — add strings
- `lib/core/l10n/app_bn.arb` — add strings

### Sequencing

| # | Task | Depends on | Effort |
|---|------|------------|--------|
| T1 | Create `StreakBreakRisk` entity + freezed | — | S |
| T2 | Create `DetectStreakBreakRiskUseCase` + unit tests | T1 | M |
| T3 | Add `streakBreakHistory()` to `HabitModule` contract | — | S |
| T4 | Implement `streakBreakHistory()` in Water module | T3 | S |
| T5 | Implement `streakBreakHistory()` in Medicine module | T3 | S |
| T6 | Implement `streakBreakHistory()` in Prayer module | T3 | S |
| T7 | Add `streakBreakNudgeDisabledModules` column + migration | — | S |
| T8 | Update `AppSettings` entity + repository | T7 | S |
| T9 | Wire nudge detection into `planAndApplyNotifications` | T2, T4–T8 | M |
| T10 | Add settings UI toggle + localization | T8 | S |
| T11 | Integration tests for nudge dedup + opt-out | T9 | M |

**Total effort: M** (the detection logic is small but the wiring across
modules and the settings integration add volume).
