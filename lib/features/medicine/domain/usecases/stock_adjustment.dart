import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';

/// Result of marking a dose done: the medicine's new stock count, the
/// delta actually applied (0 if no event should be written), and whether
/// a `MedicineStockEvent` should be persisted (FR-M-04/05).
typedef StockAdjustment = ({
  int newStockCount,
  int stockDelta,
  bool writesEvent,
});

/// Computes the stock effect of marking a dose done. Pure — the caller
/// (the repository) persists `StockAdjustment.stockDelta` as a
/// `MedicineStockEvent(reason: doseTaken)` only when
/// `StockAdjustment.writesEvent` is true, and always writes
/// `StockAdjustment.stockDelta` onto the dose row's `stockDeltaApplied`
/// so [calculateDoseUndoneAdjustment] can reverse it exactly later.
///
/// [fromOtherSource] is FR-M-05's escape hatch for marking a dose done
/// without decrementing stock (e.g. the medicine ran out and the user
/// took it from elsewhere) — never decrements, never writes an event.
StockAdjustment calculateDoseTakenAdjustment({
  required Medicine medicine,
  required bool fromOtherSource,
}) {
  if (!medicine.stockEnabled || fromOtherSource) {
    return (
      newStockCount: medicine.stockCount ?? 0,
      stockDelta: 0,
      writesEvent: false,
    );
  }
  final startCount = medicine.stockCount ?? 0;
  final rawNewCount = startCount - medicine.consumptionPerDose;
  final newCount = rawNewCount < 0 ? 0 : rawNewCount;
  return (
    newStockCount: newCount,
    stockDelta: newCount - startCount,
    writesEvent: true,
  );
}

/// Result of undoing a done dose: the medicine's restored stock count and
/// the (positive) delta to record as a `MedicineStockEvent(reason:
/// doseUndone)`.
typedef UndoAdjustment = ({int newStockCount, int stockDelta});

/// Computes the stock effect of un-marking a done dose, exactly reversing
/// whatever [stockDeltaApplied] (from the dose row) was originally
/// applied — a no-op when that was 0 (a "taken from other source" dose).
UndoAdjustment calculateDoseUndoneAdjustment({
  required Medicine medicine,
  required int stockDeltaApplied,
}) {
  if (stockDeltaApplied == 0) {
    return (newStockCount: medicine.stockCount ?? 0, stockDelta: 0);
  }
  final restore = -stockDeltaApplied;
  return (
    newStockCount: (medicine.stockCount ?? 0) + restore,
    stockDelta: restore,
  );
}
