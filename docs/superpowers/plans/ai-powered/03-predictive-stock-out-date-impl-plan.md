# Predictive Stock-Out Date — Implementation Plan

**Spec:** [Predictive Stock-Out Date Design](./03-predictive-stock-out-date-design.md)
**Run:** TBD
**Estimated effort:** S–M (9 tasks)
**Dependencies:** Medicine module (existing), `medicine_stock_events` table, `StockCard` widget, `medicine_detail_screen.dart`, `MedicineModule.pendingNotifications()`

## Pre-requisites
- Medicine module is complete (domain/data/presentation/notifications, Run 10+)
- `medicine_stock_events` table exists with `delta`, `reason`, `createdAt` columns
- `Medicine` entity has `stockEnabled` and `stockCount` fields
- `MedicineModule.pendingNotifications()` already handles dose notifications
- Freezed + codegen pipeline works
- No new packages required

---

## Tasks

### Task 1: Create `StockProjection` Freezed entity
**Effort:** S
**Files to create:**
- `lib/features/medicine/domain/entities/stock_projection.dart`

**Files to modify:** (none)

**Description:**
Create the `StockProjection` Freezed sealed class:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'stock_projection.freezed.dart';

@freezed
sealed class StockProjection with _$StockProjection {
  const factory StockProjection({
    DateTime? projectedDate,
    int? daysRemaining,
    double? averageRatePerDay,
    required int sampleSize,
    required String confidence,
    required int currentStock,
  }) = _StockProjection;
}
```

Run `dart run build_runner build --delete-conflicting-outputs`.

**Acceptance criteria:**
- `stock_projection.freezed.dart` is generated
- File compiles without errors

**Test:** No dedicated test — verified by compilation and use case tests.

---

### Task 2: Implement `PredictStockOutDateUseCase`
**Effort:** S
**Files to create:**
- `lib/features/medicine/domain/usecases/predict_stock_out_date.dart`

**Files to modify:** (none)

**Description:**
Implement the pure use case that computes projected stock-out date from consumption rate.

**Core algorithm:**
1. Filter `stockEvents` to those within the last `consumptionWindowDays` (default 30) of `now`.
2. Filter further to `reason == MedicineStockEventReason.doseTaken` (exclude refills, adjustments, undos).
3. Compute `sum(delta)` across filtered events (negative deltas). Take absolute value → total units consumed.
4. Compute `daysSpan` = span from earliest to latest event in the window. If all events are on the same day, use 1.
5. `averageRatePerDay = totalConsumed / daysSpan`.
6. If `averageRatePerDay == 0`, return projection with `projectedDate: null`.
7. `daysRemaining = currentStock / averageRatePerDay`.
8. `projectedDate = now.add(Duration(days: daysRemaining.round()))`.
9. Classify confidence: `sampleSize >= 10 && daysSpan >= 7` → `'high'`, `>= 5 || daysSpan >= 3` → `'medium'`, else `'low'`.

**Edge cases handled:**
- `currentStock == 0` → `daysRemaining = 0`, `projectedDate = now`
- Empty events → `sampleSize = 0`, return low-confidence with null rate
- Only refills, no dose-taken → same as empty
- Undo events excluded from consumption calculation

**Acceptance criteria:**
- Consistent consumption → correct projection
- Irregular consumption → average-based projection
- No events → null projectedDate, low confidence
- Zero stock → today's date
- Undo events excluded from rate

**Test:** See Task 3.

---

### Task 3: Write unit tests for projection use case
**Effort:** S
**Files to create:**
- `test/features/medicine/domain/usecases/predict_stock_out_date_test.dart`

**Files to modify:** (none)

**Description:**
Pure unit tests for `PredictStockOutDateUseCase`:

| Scenario | Expected behavior |
|----------|-------------------|
| 10 dose-taken events over 10 days, stock=20 | rate=1/day, daysRemaining=20, projectedDate=now+20 |
| 5 events over 5 days, stock=10 | rate=1/day, projectedDate=now+10, medium confidence |
| No events | sampleSize=0, projectedDate=null, low confidence |
| Only refill events | sampleSize=0, same as no events |
| Zero stock | daysRemaining=0, projectedDate=now |
| Undo event present | excluded from rate calculation |
| Single event on one day | daysSpan=1, edge case handled |
| Window boundary: events outside 30 days excluded | rate computed from only recent events |

**Acceptance criteria:**
- `flutter test test/features/medicine/domain/usecases/predict_stock_out_date_test.dart` passes
- All edge cases covered

**Test:** `flutter test test/features/medicine/domain/usecases/predict_stock_out_date_test.dart`

---

### Task 4: Create `StockProjectionCard` widget
**Effort:** S
**Files to create:**
- `lib/features/medicine/presentation/widgets/stock_projection_card.dart`

**Files to modify:** (none)

**Description:**
A `StatelessWidget` that displays the stock-out projection:
- Shows: "At current pace, out in ~X days (around DATE)"
- Confidence indicator (chip or subtle text)
- When confidence is `'low'`: footnote "Based on limited data — more accurate as you log more doses."
- When `projectedDate` is null: "Not enough data to project"
- When `daysRemaining == 0`: "Stock depleted"

Widget reads the `StockProjection` entity and formats the display.

**Acceptance criteria:**
- High confidence shows projection without footnote
- Low confidence shows footnote
- Null projection shows "not enough data" message
- Zero stock shows "Stock depleted"
- Strings are localized

**Test:** See Task 7.

---

### Task 5: Add `stockProjectionProvider` and wire into detail screen
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/medicine/presentation/providers/medicine_providers.dart`
- `lib/features/medicine/presentation/screens/medicine_detail_screen.dart`

**Description:**
1. Add a new Riverpod provider in `medicine_providers.dart`:
   ```dart
   @riverpod
   Future<StockProjection> stockProjection(
     StockProjectionRef ref,
     String medicineId,
   ) async {
     final medicine = await ref.watch(medicineByIdProvider(medicineId).future);
     if (medicine == null || !medicine.stockEnabled) {
       return const StockProjection(
         projectedDate: null, daysRemaining: null,
         averageRatePerDay: null, sampleSize: 0,
         confidence: 'low', currentStock: 0,
       );
     }
     final events = await ref.watch(medicineRepositoryProvider).allStockEvents();
     final medicineEvents = events.where((e) => e.medicineId == medicineId).toList();
     return PredictStockOutDateUseCase().execute(
       medicine: medicine, stockEvents: medicineEvents, now: clock.now(),
     );
   }
   ```

2. In `medicine_detail_screen.dart`, add `StockProjectionCard` below the existing `StockCard`:
   ```dart
   StockCard(medicine: medicine, onRefill: ...),
   const SizedBox(height: 8),
   if (medicine.stockEnabled && medicine.stockCount != null)
     StockProjectionCard(
       projection: ref.watch(stockProjectionProvider(medicine.id)).valueOrNull ?? ...,
     ),
   ```

**Acceptance criteria:**
- Provider computes projection from real stock events
- Detail screen shows projection card below stock card
- Card only appears when stock tracking is enabled

**Test:** Manual verification: open detail screen for a medicine with stock tracking enabled, verify projection card appears.

---

### Task 6: Add localization strings
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:**
Add ARB keys for all new strings (see Localization Keys below). Run `flutter gen-l10n` after.

**Acceptance criteria:**
- All new keys present in both en and bn
- `flutter gen-l10n` succeeds

**Test:** Compile check after `flutter gen-l10n`.

---

### Task 7: Widget tests for projection card
**Effort:** S
**Files to create:**
- `test/features/medicine/presentation/widgets/stock_projection_card_test.dart`

**Files to modify:** (none)

**Description:**
Widget tests:
- High confidence with valid projection → shows "out in ~X days (around DATE)"
- Low confidence → shows footnote "Based on limited data"
- Null projection → shows "Not enough data to project"
- Zero stock → shows "Stock depleted"

**Acceptance criteria:**
- `flutter test test/features/medicine/presentation/widgets/stock_projection_card_test.dart` passes

**Test:** `flutter test test/features/medicine/presentation/widgets/stock_projection_card_test.dart`

---

### Task 8: (Optional) Add stock warning notification tier in MedicineModule
**Effort:** M
**Files to create:** (none)
**Files to modify:**
- `lib/features/medicine/medicine_module.dart`
- `lib/core/notifications/notification_service.dart` (if adding a new channel)

**Description:**
For a "2 weeks out" early warning:
1. In `MedicineModule.pendingNotifications()`, after existing dose notifications, compute the stock projection for each medicine with stock tracking enabled.
2. If `daysRemaining <= 14` and `confidence != 'low'`, append a synthetic `PendingNotification` with `sourceType: 'stock_warning'` and content like "At current pace, out of {medicineName} in ~{days} days".
3. Optionally add a dedicated notification channel or reuse `medicine_reminders`.

**Acceptance criteria:**
- Notification fires when stock is projected to run out within 14 days
- Notification does NOT fire when confidence is low
- Notification does NOT fire when stock tracking is disabled
- Existing dose notifications are unaffected

**Test:** Manual verification: set up a medicine with low stock, trigger `pendingNotifications()`, verify stock warning notification is included.

---

### Task 9: Manual testing / integration verification
**Effort:** S
**Files to create:** (none)
**Files to modify:** (none)

**Description:**
Manual verification checklist:
1. Open medicine detail screen for a medicine with stock tracking
2. Verify projection card shows correct "out in ~X days" based on actual stock events
3. Add a few dose-taken stock events, verify projection updates
4. Verify projection card does NOT appear for medicines without stock tracking
5. Verify low-confidence footnote shows for medicines with few events
6. (If T8 done) Verify stock warning notification fires when stock is low
7. Verify no regression: existing stock card and dose notifications unaffected

**Acceptance criteria:**
- All checklist items pass
- No crashes or regressions

**Test:** Manual QA — no automated test file.

---

## Schema Migration

**None.** The stock-out projection is a derived, non-persisted value computed at read time from the existing `medicine_stock_events` table. Same pattern as lazy dose status (upcoming/due/missed are never stored, only computed).

---

## Localization Keys

| Key | en | bn |
|-----|----|----|
| `stockProjectionTitle` | Stock Projection | স্টক প্রজেকশন |
| `stockProjectionBody` | At current pace, out in ~{days} days (around {date}) | বর্তমান গতিতে, ~{days} দিনের মধ্যে শেষ (প্রায় {date}) |
| `stockProjectionNoData` | Not enough data to project | প্রজেকশন করার জন্য পর্যাপ্ত তথ্য নেই |
| `stockProjectionLowConfidence` | Based on limited data — more accurate as you log more doses | সীমিত তথ্যের ভিত্তিতে — আরও ডোজ লগ করলে আরও সঠিক হবে |
| `stockProjectionAlreadyOut` | Stock depleted | স্টক শেষ |

---

## Risk Notes

- **No new packages.** This is arithmetic over existing stock ledger data.
- **No forecasting model.** A simple average-consumption-rate projection is the target — explicitly not a more sophisticated statistical model. Seasonality/trend detection is out of scope.
- **Undo events.** The use case excludes `MedicineStockEventReason.undo` from consumption calculation since the stock count is already corrected by the undo. This prevents double-counting.
- **Consumption window.** Default 30-day rolling lookback. This balances responsiveness to recent behavior against sensitivity to short irregular stretches. If the user skips doses during travel, the rate naturally reflects that.
- **Notification tier (optional).** T8 is explicitly optional for the first pass. The on-screen projection card alone is a valuable feature. The notification tier can be added in a follow-up if the UX team decides it's warranted.
- **Provider invalidation.** The `stockProjectionProvider` depends on stock events — it will recompute when stock events change, which is correct behavior.
- **Edge: only refills, no consumption.** If a user has only logged refills (no dose-taken events), the rate is zero and `projectedDate` is null. This is correct — there's no consumption to measure.
