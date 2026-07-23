# Smart Qadha Payoff Pace Planner

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Prayer's Qadha screen today shows a raw counter of missed prayers owed as
make-up, with a −1 control to record progress. A raw, possibly large
counter with no sense of trajectory is a classic guilt-without-a-path
problem: it tells the user how far behind they are but nothing about how
long it would realistically take to catch up, which can make the number
feel permanent and discouraging rather than actionable. This is a
novel, Islamic-app-specific feature with no direct competitor precedent
in the atlas — turning a static debt counter into a pace-based plan is a
small computation with an outsized effect on how the feature feels to use.

## Goals
- Given the current Qadha counter and the user's own recent make-up pace
  (prayers cleared per week, observed from their own history), project a
  rough "clear by" date or duration ("at this pace, ~6 months").
- Present this as an encouraging, non-judgmental framing — a plan, not
  another guilt signal.
- Update the projection naturally as the counter and pace change over
  time, with no separate configuration step required from the user.

## Non-goals / out of scope
- No prescriptive goal-setting or forced pace targets — the user isn't
  told they must clear N per week, only shown what their own actual pace
  implies.
- No religious/scholarly guidance on Qadha obligations themselves — this
  is purely a pacing calculation on top of the existing counter mechanic,
  not a feature that interprets fiqh.
- No model or external data — a simple rate calculation over local
  history.

## Proposed approach (high-level)
Pure arithmetic over the existing `prayer_qadha_counters` table and the
user's own make-up log history: compute a recent rate (make-ups recorded
per week over, say, the last several weeks), and if the rate is
non-zero, divide the current outstanding counter by that rate to get a
projected number of weeks/months to clear it. If the user has never
recorded a make-up yet, there's no pace to project from, so the feature
simply doesn't show a projection until there's at least a little history
to compute one from — this is a strictly additive, read-only annotation
on the existing Qadha screen, not a change to how the counter itself is
recorded or decremented.

## Dependencies & prerequisites
- Existing `prayer_qadha_counters` table and its make-up recording flow.
- A little make-up history before the projection can compute anything
  meaningful (first-use empty state needs its own simple copy, e.g. "log
  a few make-ups to see your pace").

## Open questions for the implementation round
- What window of history defines "recent pace" — last 4 weeks, last 8,
  all-time average? Recent-weighted seems right for encouragement but
  needs a concrete window chosen.
- How does the projection handle a pace of zero or near-zero (user logged
  Qadha counters but hasn't made any up in a while) without feeling like a
  scolding message?
- Does this projection appear only on the Qadha screen, or also as a
  small note elsewhere (e.g. Prayer's stats screen)?
- Should there be a lightweight, optional "target pace" the user can set
  for themselves, distinct from the passive observed-pace projection, or
  is that scope creep for this pass?

## Effort & sequencing notes
Complexity S — a small, self-contained arithmetic feature on top of a
table and screen that already exist. Effort is almost entirely in getting
the tone/copy right for an encouraging rather than guilt-inducing framing,
not the calculation. Independent of the other items in this category and
safe to sequence any time.

## Implementation Plan (Low-Level)

### Schema changes

**No new Drift tables or columns.** This feature is purely read-only
arithmetic over two existing tables:

- `prayer_qadha_counters` — the outstanding balance per prayer.
- `prayer_records` — the user's historical prayer records, used to
  observe make-up pace (records with `status == 'prayed'` and
  `prayerDate` earlier than the original scheduled date, OR records
  whose `prayerName` matches a prayer that had a Qadha counter
  increment — but the simplest proxy is: any `prayed` record where
  `prayerDate` falls within the lookback window and the corresponding
  Qadha counter is > 0).

**Pace definition:** make-ups recorded per week, computed over the last
8 weeks. A "make-up" is a `prayer_records` row with `status == 'prayed'`
whose `prayerDate` is within the lookback window. The rate is total
make-ups in window / (window length in weeks).

### Domain entities

**File:** `lib/features/prayer/domain/entities/qadha_pace_projection.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'qadha_pace_projection.freezed.dart';

/// A projected Qadha payoff pace based on the user's own history.
@freezed
sealed class QadhaPaceProjection with _$QadhaPaceProjection {
  /// Creates a Qadha pace projection.
  const factory QadhaPaceProjection({
    /// Total outstanding Qadha across all prayers.
    required int totalOutstanding,

    /// Make-ups recorded per week (over the lookback window).
    required double currentRatePerWeek,

    /// Projected weeks remaining to clear the balance at the current rate.
    /// `null` if rate is zero.
    required double? weeksRemaining,

    /// Projected date by which the balance would be cleared.
    /// `null` if rate is zero or too low to project.
    required DateTime? clearByDate,

    /// Per-prayer breakdown: prayer name → outstanding count.
    required Map<String, int> perPrayerOutstanding,

    /// Whether there's enough history to compute a meaningful projection.
    required bool hasEnoughHistory,
  }) = _QadhaPaceProjection;
}
```

### Use case signatures

**File:** `lib/features/prayer/domain/usecases/calculate_qadha_pace.dart`

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/qadha_pace_projection.dart';

/// Calculates the Qadha payoff pace projection from the user's own
/// make-up history.
///
/// Pure — no database dependency. All data is passed in.
class CalculateQadhaPaceUseCase {
  /// Creates the use case.
  const CalculateQadhaPaceUseCase({
    this.lookbackWeeks = 8,
    this.minMakeupsForProjection = 2,
  });

  /// How many weeks of history to observe for pace calculation.
  final int lookbackWeeks;

  /// Minimum number of make-ups in the window before a projection is
  /// shown. Below this, the rate is too noisy to be meaningful.
  final int minMakeupsForProjection;

  /// Computes the pace projection.
  ///
  /// [counters] is the current set of five Qadha counters.
  /// [recentRecords] is the user's prayer records within the lookback
  /// window (already filtered by the caller).
  /// [today] is the current local day.
  QadhaPaceProjection execute({
    required List<PrayerQadhaCounter> counters,
    required List<PrayerRecord> recentRecords,
    required LocalDate today,
  });
}
```

**Key logic:**
1. Sum all `counters[].count` → `totalOutstanding`. If 0, return
   projection with `hasEnoughHistory: true` but `weeksRemaining: null`
   (nothing to clear).
2. Count records in `recentRecords` where `storedStatus ==
   PrayerStatus.prayed` → `totalMakeups`.
3. `ratePerWeek = totalMakeups / lookbackWeeks`.
4. If `totalMakeups < minMakeupsForProjection`, return with
   `hasEnoughHistory: false`.
5. `weeksRemaining = totalOutstanding / ratePerWeek`.
6. `clearByDate = today + weeksRemaining weeks`.
7. Build per-prayer breakdown from `counters`.

### Data layer

No new repository. The use case is called from the presentation layer,
which supplies data from the existing `PrayerRepository`.

**File to modify:** `lib/features/prayer/presentation/providers/prayer_providers.dart`

Add a Riverpod provider that computes the projection:

```dart
/// Qadha pace projection, computed from live data.
@riverpod
Future<QadhaPaceProjection?> qadhaPaceProjection(
  QadhaPaceProjectionRef ref,
) async {
  final repository = ref.watch(prayerRepositoryProvider);
  final counters = await repository.allQadhaCounters();
  final today = localDayKey(clock.now());
  final lookbackStart = today.addDays(-8 * 7); // 8 weeks back
  final records = await repository.recordsInRange(lookbackStart, today);
  return const CalculateQadhaPaceUseCase().execute(
    counters: counters,
    recentRecords: records,
    today: today,
  );
}
```

### Presentation layer

**File to modify:** `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`

Add a projection card above or below the counter list. The card shows:

- **If `hasEnoughHistory == false`** (empty state):
  "Log a few make-ups to see your pace."
- **If `totalOutstanding == 0`**:
  "All caught up — no outstanding Qadha."
- **If `weeksRemaining != null`**:
  "At your current pace (~{rate}/week), you'll clear your Qadha in
  about {weeks} weeks ({date})."
- **If `weeksRemaining == null`** (rate is zero but outstanding > 0):
  "Log a make-up to start building your pace."

The card uses `Card` + `ListTile` or a custom widget matching the
existing screen's visual style. Tone is encouraging, non-judgmental.

**Wire the provider:**

```dart
final projection = ref.watch(qadhaPaceProjectionProvider);
```

Render the projection card conditionally based on the projection state.

### Localization

**Files to modify:**

- `lib/core/l10n/app_en.arb` — add:
  - `qadhaPaceHeader`: "Pace Projection"
  - `qadhaPaceEmptyState`: "Log a few make-ups to see your pace."
  - `qadhaPaceAllCaughtUp`: "All caught up — no outstanding Qadha."
  - `qadhaPaceAtCurrentPace`: "At your current pace (~{rate}/week), you'll clear your Qadha in about {weeks} weeks ({date})."
  - `qadhaPaceNoHistory`: "Log a make-up to start building your pace."
- `lib/core/l10n/app_bn.arb` — Bangla equivalents.

### Testing strategy

**New test file:** `test/features/prayer/domain/usecases/calculate_qadha_pace_test.dart`

Test cases:
1. **Zero outstanding:** counters all zero → `totalOutstanding == 0`,
   `weeksRemaining == null`, no error.
2. **No history:** `recentRecords` empty → `hasEnoughHistory == false`.
3. **Below minimum:** fewer than `minMakeupsForProjection` make-ups →
   `hasEnoughHistory == false`.
4. **Normal pace:** 4 make-ups in 8 weeks, 16 outstanding →
   `weeksRemaining == 32.0`.
5. **Fast pace:** 8 make-ups in 8 weeks, 4 outstanding →
   `weeksRemaining == 4.0`.
6. **Partial data:** some prayers have 0 outstanding, others don't →
   per-prayer breakdown correct.
7. **Edge: exactly at minimum:** exactly `minMakeupsForProjection`
   make-ups → `hasEnoughHistory == true`.
8. **Edge: single prayer outstanding:** only Fajr has Qadha, others 0.
9. **clearByDate calculation:** verify date arithmetic is correct for
   known input.

### File paths

**Create:**

- `lib/features/prayer/domain/entities/qadha_pace_projection.dart`
- `lib/features/prayer/domain/entities/qadha_pace_projection.freezed.dart`
  (generated)
- `lib/features/prayer/domain/usecases/calculate_qadha_pace.dart`
- `test/features/prayer/domain/usecases/calculate_qadha_pace_test.dart`

**Modify:**

- `lib/features/prayer/presentation/providers/prayer_providers.dart` —
  add `qadhaPaceProjectionProvider`
- `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart` —
  add projection card widget
- `lib/core/l10n/app_en.arb` — add localization strings
- `lib/core/l10n/app_bn.arb` — add localization strings

### Sequencing

| # | Task | Depends on | Effort |
|---|------|------------|--------|
| T1 | Create `QadhaPaceProjection` entity + freezed | — | S |
| T2 | Create `CalculateQadhaPaceUseCase` + unit tests | T1 | S |
| T3 | Add `qadhaPaceProjectionProvider` | T2 | S |
| T4 | Update Qadha screen UI with projection card | T3 | S |
| T5 | Add localization strings (en/bn) | — | S |

**Total effort: S** — five small, independent tasks. No schema changes,
no new tables, no notification infrastructure. The hardest part is
getting the encouragement copy right in the l10n strings.
