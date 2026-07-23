# Smart Qadha Payoff Pace Planner — Implementation Plan

**Spec:** [05-smart-qadha-payoff-pace-planner-design.md](05-smart-qadha-payoff-pace-planner-design.md)
**Run:** TBD
**Estimated effort:** S
**Dependencies:** Existing Prayer module (`prayer_qadha_counters`, `prayer_records`, `PrayerRepository`, `prayer_qadha_screen.dart`).

## Pre-requisites

- Prayer module is complete with `prayer_qadha_counters` table, `prayer_records` table, and `PrayerRepository` providing `allQadhaCounters()` and record-range queries.
- `PrayerQadhaScreen` exists and renders the five counter `ListTile`s.
- `flutter gen-l10n` produces valid `AppLocalizations`.
- `build_runner build` runs clean.

## Tasks

### Task 1: Create `QadhaPaceProjection` entity + Freezed class
**Effort:** S
**Files to create:**
- `lib/features/prayer/domain/entities/qadha_pace_projection.dart`

**Files to modify:** (none)
**Description:** Create a `@freezed` `QadhaPaceProjection` entity with fields:
- `totalOutstanding` (int) — sum of all five Qadha counters.
- `currentRatePerWeek` (double) — make-ups recorded per week over the lookback window.
- `weeksRemaining` (double?) — `null` if rate is zero or history insufficient.
- `clearByDate` (DateTime?) — projected clear-by date, `null` if uncomputable.
- `perPrayerOutstanding` (Map<String, int>) — prayer name → outstanding count.
- `hasEnoughHistory` (bool) — whether enough make-up data exists to compute a projection.

Run `build_runner build --delete-conflicting-outputs` to generate `.freezed.dart`.

**Acceptance criteria:**
- Entity compiles after codegen.
- All fields are required (nullable `weeksRemaining` and `clearByDate` handle zero-pace case).

**Test:** `build_runner build` succeeds; entity is immutable.

---

### Task 2: Create `CalculateQadhaPaceUseCase` + unit tests
**Effort:** S
**Files to create:**
- `lib/features/prayer/domain/usecases/calculate_qadha_pace.dart`
- `test/features/prayer/domain/usecases/calculate_qadha_pace_test.dart`

**Files to modify:** (none)
**Description:** Implement the pure use case. Constructor params: `lookbackWeeks` (default 8), `minMakeupsForProjection` (default 2). Method `execute({counters, recentRecords, today})` → `QadhaPaceProjection`.

Logic:
1. Sum all `counters[].count` → `totalOutstanding`. If 0, return with `hasEnoughHistory: true`, `weeksRemaining: null`.
2. Count `recentRecords` where `storedStatus == PrayerStatus.prayed` → `totalMakeups`.
3. `ratePerWeek = totalMakeups / lookbackWeeks`.
4. If `totalMakeups < minMakeupsForProjection`, return with `hasEnoughHistory: false`.
5. `weeksRemaining = totalOutstanding / ratePerWeek`.
6. `clearByDate = today + weeksRemaining weeks` (use `LocalDate.addDays`).
7. Build `perPrayerOutstanding` map from counters.

Write tests:
1. Zero outstanding → `weeksRemaining == null`, `hasEnoughHistory: true`
2. Empty `recentRecords` → `hasEnoughHistory: false`
3. Below minimum make-ups → `hasEnoughHistory: false`
4. Normal pace (4 make-ups / 8 weeks, 16 outstanding) → `weeksRemaining == 32.0`
5. Fast pace (8 make-ups / 8 weeks, 4 outstanding) → `weeksRemaining == 4.0`
6. Partial data (some prayers 0 outstanding) → per-prayer breakdown correct
7. Exactly at minimum → `hasEnoughHistory: true`
8. Single prayer outstanding (only Fajr) → correct
9. `clearByDate` arithmetic is correct

**Acceptance criteria:**
- Use case is pure (no DB, no plugin dependency).
- All 9 test cases pass.
- `clearByDate` uses `LocalDate` arithmetic, not raw `DateTime`.

**Test:** `flutter test test/features/prayer/domain/usecases/calculate_qadha_pace_test.dart`

---

### Task 3: Add `qadhaPaceProjectionProvider`
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/prayer/presentation/providers/prayer_providers.dart`

**Description:** Add a `@riverpod` provider that:
1. Watches `prayerRepositoryProvider`.
2. Fetches `allQadhaCounters()`.
3. Fetches `prayer_records` within the 8-week lookback window (use `recordsInRange(lookbackStart, today)` or equivalent method on the repository).
4. Calls `CalculateQadhaPaceUseCase().execute(...)` with the data.
5. Returns `QadhaPaceProjection?` (nullable for loading/error states handled by `AsyncValue`).

**Acceptance criteria:**
- Provider compiles after codegen.
- Returns a valid `QadhaPaceProjection` when data exists.
- Returns null or `hasEnoughHistory: false` when no make-up history exists.

**Test:** `flutter analyze` passes; existing prayer provider tests still pass.

---

### Task 4: Update Qadha screen UI with projection card
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`

**Description:** Add a projection `Card` above the counter `ListView` in `PrayerQadhaScreen.build()`. The card renders conditionally based on `ref.watch(qadhaPaceProjectionProvider)`:

- **Loading:** `CircularProgressIndicator` or `SizedBox.shrink()`.
- **`hasEnoughHistory == false`:** "Log a few make-ups to see your pace." (empty state, low emphasis).
- **`totalOutstanding == 0`:** "All caught up — no outstanding Qadha."
- **`weeksRemaining != null`:** "At your current pace (~{rate}/week), you'll clear your Qadha in about {weeks} weeks ({date})."
- **`weeksRemaining == null` (rate zero, outstanding > 0):** "Log a make-up to start building your pace."

Use `Card` + `ListTile` or a simple `Padding` + `Text` widget matching the existing screen's visual style. Tone is encouraging, non-judgmental.

**Acceptance criteria:**
- Card renders at the top of the Qadha screen.
- All four states (empty, caught-up, projected, no-history) display correctly.
- Card doesn't disrupt existing counter list layout.

**Test:** `flutter analyze` passes; visual inspection in emulator.

---

### Task 5: Add localization strings (en/bn)
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:** Add the following ARB keys:

### `app_en.arb`
| Key | Value |
|-----|-------|
| `qadhaPaceHeader` | `"Pace Projection"` |
| `qadhaPaceEmptyState` | `"Log a few make-ups to see your pace."` |
| `qadhaPaceAllCaughtUp` | `"All caught up — no outstanding Qadha."` |
| `qadhaPaceAtCurrentPace` | `"At your current pace (~{rate}/week), you'll clear your Qadha in about {weeks} weeks ({date})."` |
| `qadhaPaceNoHistory` | `"Log a make-up to start building your pace."` |

### `app_bn.arb`
Bangla equivalents for all keys above.

Run `flutter gen-l10n` after editing.

**Acceptance criteria:**
- `flutter gen-l10n` produces valid output with no missing keys.
- All keys have both en and bn translations.
- `{rate}`, `{weeks}`, `{date}` placeholders are present in `qadhaPaceAtCurrentPace`.

**Test:** `flutter gen-l10n` succeeds; `flutter analyze` passes.

---

## Schema Migration

**No schema changes.** This feature is purely read-only arithmetic over existing `prayer_qadha_counters` and `prayer_records` tables.

## Localization Keys

See Task 5 above for the full list.

## Risk Notes

- **Zero-pace sensitivity:** A user who has never recorded a make-up gets a neutral "Log a make-ups to start building your pace" message, not a guilt-inducing "you haven't made up any Qadha" warning. The tone is critical — review copy with someone sensitive to religious-app UX.
- **Lookback window choice:** 8 weeks is a balance between enough data for a meaningful rate and recency for encouragement. If a user's pace changed recently (e.g. they started making up more consistently), the 8-week average will lag behind. This is acceptable for v1.
- **`prayer_records` scope:** The use case counts any `prayed` record in the lookback window, not just records explicitly tagged as "make-up". A more precise filter would check if the prayer date is earlier than the original scheduled date, but the simpler approach works because any `prayed` record in a window where Qadha counters are > 0 implies make-up activity.
- **Provider reactivity:** The provider recomputes on counter changes (make-up logged), which naturally updates the projection in real time. No polling needed.
