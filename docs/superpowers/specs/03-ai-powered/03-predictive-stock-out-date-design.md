# Predictive Stock-Out Date

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Medicine already has a one-shot low-stock crossing detector that fires
once stock drops below a threshold, but that's a reactive alert — it
tells the caregiver persona a problem exists right when it's already
close, not far enough ahead to act. The atlas explicitly calls out
"running out unexpectedly" as a stated failure mode for caregivers
managing someone else's medication, and a forward-looking projection
("At this pace, out of Amlodipine in ~5 days") turns a threshold alert
into a plannable heads-up, giving enough lead time to actually refill
before hitting zero.

## Goals
- Compute a projected stock-out date/day-count from recent consumption
  rate, derived entirely from existing stock ledger entries.
- Surface the projection somewhere a caregiver naturally looks (the
  medicine detail/stats screen, and optionally as an earlier, separate
  notification tier ahead of the existing low-stock crossing).
- Keep the existing one-shot low-stock crossing detector untouched —
  this is an additive, earlier-warning layer, not a replacement.

## Non-goals / out of scope
- No forecasting model, no seasonality/trend detection — a simple
  average-consumption-rate projection is the target, explicitly not a
  more sophisticated statistical model.
- Does not attempt to account for irregular real-world events (e.g. a
  dose being skipped due to travel) beyond what naturally falls out of
  using recent actual consumption rather than the nominal schedule.
- Not a refill-ordering or pharmacy-integration feature — purely an
  informational projection.

## Proposed approach (high-level)
The mechanism is arithmetic over MedicineModule's existing stock ledger:
take a recent window of stock-consuming events (dose-taken deductions),
compute an average consumption-per-day rate, and divide current
remaining stock by that rate to get a projected days-remaining and
calendar date. This sits naturally alongside the existing one-shot
low-stock crossing detector — that detector already watches the stock
ledger for a threshold crossing, so the projection can be computed at
the same read points (e.g. whenever `MedicineModule.pendingNotifications()`
already touches stock state, or whenever the stock ledger changes) without
introducing a new polling mechanism. The projected date is a derived,
non-persisted value recomputed on read, following the same "derive, don't
persist ephemeral status" pattern the module already uses for lazy dose
status (upcoming/due/missed are derived, not stored).

## Dependencies & prerequisites
- Existing stock ledger and MedicineModule's low-stock detector — no new
  tables needed if this stays a derived read-time calculation.
- A decision on whether the projection also drives an earlier notification
  tier (e.g. "2 weeks out" vs. today's single low-stock threshold) or
  stays purely a passive on-screen figure.

## Open questions for the implementation round
- What window of consumption history is used for the rate — all-time
  average, last-N-doses, last-N-days? Each has different sensitivity to
  a recent irregular stretch (e.g. a vacation where doses were skipped).
- Does a schedule change (dose frequency edited) reset or blend into the
  projection, given the rate is empirical rather than schedule-derived?
- Should the projection appear only when stock is already getting low, or
  always (so a caregiver builds trust in the number before it matters)?
- Is a new notification tier in scope for this pass, or is "show it on
  screen only" the right-sized first cut?

## Effort & sequencing notes
Complexity S — this is a small arithmetic addition riding on data and
detection logic that already exists; the bulk of the effort is UI
placement and deciding the notification-tier question above, not the
calculation itself. A good candidate for an early, low-risk win in this
category.

---

## Implementation Plan (Low-Level)

### Schema Changes

**None.** The stock-out projection is a derived, non-persisted value computed at read time from the existing `medicine_stock_events` table — following the same "derive, don't persist ephemeral status" pattern Medicine already uses for lazy dose status (upcoming/due/medication are never stored, only computed).

### Domain Entities

**File:** `lib/features/medicine/domain/entities/stock_projection.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_projection.freezed.dart';

/// A derived stock-out projection for a medicine, computed from recent
/// consumption rate and current stock. Non-persisted.
@freezed
sealed class StockProjection with _$StockProjection {
  /// Creates a stock projection.
  const factory StockProjection({
    /// Projected date the medicine runs out, or null if consumption rate
    /// is zero (no deductions) or stock is already zero.
    DateTime? projectedDate,

    /// Estimated days remaining from today, or null if uncomputable.
    int? daysRemaining,

    /// Average consumption per day (units/day), derived from the
    /// consumption window. null if no consumption events exist.
    double? averageRatePerDay,

    /// Number of consumption events (dose-taken deductions) used to
    /// compute the rate. Important for confidence signaling.
    required int sampleSize,

    /// 'high' (>=10 events, >7 days of data), 'medium' (>=5 events or
    /// >=3 days), 'low' (<5 events and <3 days — display but don't
    /// notify).
    required String confidence,

    /// Current remaining stock count at computation time.
    required int currentStock,
  }) = _StockProjection;
}
```

### Use Case Signatures

**File:** `lib/features/medicine/domain/usecases/predict_stock_out_date.dart`

```dart
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/stock_projection.dart';

/// Computes a projected stock-out date from recent consumption rate,
/// derived entirely from existing stock ledger entries.
///
/// Pure over inputs — no DB access, no side effects. The caller
/// (presentation layer) provides the current stock and the stock events.
class PredictStockOutDateUseCase {
  const PredictStockOutDateUseCase();

  /// Projects the stock-out date for [medicine] given [stockEvents].
  ///
  /// [now] is injected for testability.
  /// [consumptionWindowDays] defaults to 30 (rolling lookback).
  StockProjection execute({
    required Medicine medicine,
    required List<MedicineStockEvent> stockEvents,
    required DateTime now,
    int consumptionWindowDays = 30,
  }) { ... }
}
```

**Core algorithm (inside `execute`):**
1. Filter `stockEvents` to those within the last `consumptionWindowDays` of `now`.
2. Filter further to `reason == MedicineStockEventReason.doseTaken` (actual consumption) — exclude refills, adjustments, undos.
3. Compute `sum(delta)` across filtered events (these are negative deltas, so the sum is a negative total consumption). Take absolute value for total units consumed.
4. Compute `daysSpan` = span from earliest to latest event in the window. If all events are on the same day, use 1.
5. `averageRatePerDay = totalConsumed / daysSpan`.
6. If `averageRatePerDay == 0`, return a projection with `projectedDate: null` (no recent consumption — user may have stopped taking it).
7. `daysRemaining = currentStock / averageRatePerDay`.
8. `projectedDate = now.add(Duration(days: daysRemaining.round()))`.
9. Classify confidence: `sampleSize >= 10 && daysSpan >= 7` → `'high'`, `sampleSize >= 5 || daysSpan >= 3` → `'medium'`, else `'low'`.

**Edge cases handled:**
- `currentStock == 0` → `daysRemaining = 0`, `projectedDate = now`.
- `stockEvents` empty → `sampleSize = 0`, return low-confidence projection with null rate.
- Only refills, no dose-taken events → same as empty (no consumption to measure).
- Undo events that reversed a deduction — the stock count is already corrected; the undo event is excluded from consumption calculation since it doesn't represent actual consumption.

### Data Layer

**Modify:** `lib/features/medicine/domain/repositories/medicine_repository.dart` — no change needed; `allStockEvents()` already exists.

**Modify:** `lib/features/medicine/data/repositories/medicine_repository_impl.dart` — add a targeted query method:
```dart
/// Stock events for a specific medicine within a date range, optimized
/// for the projection use case.
Future<List<MedicineStockEvent>> stockEventsInRange(
  String medicineId, {
  required DateTime since,
}) async { ... }
```

This is an optional optimization over `allStockEvents()` — the use case can work with the full list since it filters in-memory, but a targeted query avoids loading the entire ledger for apps with many medicines.

### Presentation Layer

**New file:** `lib/features/medicine/presentation/widgets/stock_projection_card.dart`

```dart
/// Displays the stock-out projection alongside the existing StockCard.
///
/// Shows: "At current pace, out in ~X days (around DATE)" with a
/// confidence indicator (chip or subtle text). When confidence is 'low',
/// adds a footnote: "Based on limited data — more accurate as you log
/// more doses."
class StockProjectionCard extends StatelessWidget {
  const StockProjectionCard({required this.projection, super.key});

  final StockProjection projection;

  @override
  Widget build(BuildContext context) { ... }
}
```

**Modify:** `lib/features/medicine/presentation/screens/medicine_detail_screen.dart`

Add `StockProjectionCard` below the existing `StockCard` in the `ListView.children`:
```dart
StockCard(medicine: medicine, onRefill: ...),
const SizedBox(height: 8),
if (medicine.stockEnabled && medicine.stockCount != null)
  StockProjectionCard(
    projection: PredictStockOutDateUseCase().execute(
      medicine: medicine,
      stockEvents: stockEvents, // from provider
      now: clock.now(),
    ),
  ),
```

**New provider** in `lib/features/medicine/presentation/providers/medicine_providers.dart`:
```dart
@riverpod
Future<StockProjection> stockProjection(
  StockProjectionRef ref,
  String medicineId,
) async {
  final medicine = await ref.watch(medicineByIdProvider(medicineId).future);
  if (medicine == null || !medicine.stockEnabled) {
    return const StockProjection(
      projectedDate: null,
      daysRemaining: null,
      averageRatePerDay: null,
      sampleSize: 0,
      confidence: 'low',
      currentStock: 0,
    );
  }
  final events = await ref.watch(medicineRepositoryProvider).allStockEvents();
  final medicineEvents = events.where((e) => e.medicineId == medicineId).toList();
  return PredictStockOutDateUseCase().execute(
    medicine: medicine,
    stockEvents: medicineEvents,
    now: clock.now(),
  );
}
```

### Optional: Notification Tier

For a "2 weeks out" warning, add a method to `MedicineModule.pendingNotifications()` that checks the projection and synthesizes a notification:

**Modify:** `lib/features/medicine/medicine_module.dart`

In `pendingNotifications()`, after existing dose notifications, check if `daysRemaining <= 14` and `confidence != 'low'`, and if so, append a synthetic `PendingNotification` with `sourceType: 'stock_warning'`. This reuses the existing notification infrastructure — no new engine code.

**Modify:** `lib/core/notifications/notification_service.dart` — add a `stock_warning` channel or reuse `medicine_reminders`.

### Localization

**Modify:** `lib/core/l10n/app_en.arb` and `app_bn.arb` — add keys for:
- `stockProjectionTitle` — "Stock Projection"
- `stockProjectionBody` — "At current pace, out in ~{days} days (around {date})"
- `stockProjectionNoData` — "Not enough data to project"
- `stockProjectionLowConfidence` — "Based on limited data"
- `stockProjectionAlreadyOut` — "Stock depleted"

### Testing Strategy

| Test file | What it covers |
|-----------|---------------|
| `test/features/medicine/domain/usecases/predict_stock_out_date_test.dart` | Pure unit tests: consistent consumption → correct projection, irregular consumption → average-based projection, no events → null projection, single event → edge case, only refills → null, zero stock → today, stock above threshold → projection shown, window boundary behavior, undo events excluded from rate. |
| `test/features/medicine/presentation/widgets/stock_projection_card_test.dart` | Widget tests: high confidence shows projection, low confidence shows footnote, null projection shows "not enough data" message. |

### File Paths

**Create:**
- `lib/features/medicine/domain/entities/stock_projection.dart`
- `lib/features/medicine/domain/entities/stock_projection.freezed.dart` (generated)
- `lib/features/medicine/domain/usecases/predict_stock_out_date.dart`
- `lib/features/medicine/presentation/widgets/stock_projection_card.dart`
- `test/features/medicine/domain/usecases/predict_stock_out_date_test.dart`
- `test/features/medicine/presentation/widgets/stock_projection_card_test.dart`

**Modify:**
- `lib/features/medicine/data/repositories/medicine_repository_impl.dart` — add `stockEventsInRange()` (optional optimization)
- `lib/features/medicine/presentation/screens/medicine_detail_screen.dart` — add `StockProjectionCard` below `StockCard`
- `lib/features/medicine/presentation/providers/medicine_providers.dart` — add `stockProjectionProvider`
- `lib/features/medicine/medicine_module.dart` — (optional) add stock warning notification in `pendingNotifications()`
- `lib/core/l10n/app_en.arb` — new strings
- `lib/core/l10n/app_bn.arb` — new strings

### Sequencing

| Task | Depends on | Effort |
|------|-----------|--------|
| T1: Create `StockProjection` Freezed entity | None | S |
| T2: Implement `PredictStockOutDateUseCase` | T1 | S |
| T3: Write unit tests for projection use case | T2 | S |
| T4: Create `StockProjectionCard` widget | T1 | S |
| T5: Add `stockProjectionProvider` and wire into detail screen | T2, T4 | S |
| T6: Add localization strings | None | S |
| T7: Widget tests for projection card | T4, T5 | S |
| T8: (Optional) Add stock warning notification tier in MedicineModule | T2 | M |
| T9: Manual testing / integration verification | T5, T6, T7, T8 | S |

**Critical path:** T1 → T2 → T5 → T9
