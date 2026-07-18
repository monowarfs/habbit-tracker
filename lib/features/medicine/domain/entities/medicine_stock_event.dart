import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine_stock_event.freezed.dart';

/// Why a [MedicineStockEvent] happened.
enum MedicineStockEventReason {
  /// A dose was marked done and stock was decremented.
  doseTaken,

  /// User manually added stock.
  manualRefill,

  /// User manually corrected the count.
  manualAdjustment,

  /// A previously-done dose was un-marked, reversing its decrement.
  doseUndone,
}

/// One append-only stock ledger row (`technical/database-design.md`).
@freezed
sealed class MedicineStockEvent with _$MedicineStockEvent {
  /// Creates a stock event.
  const factory MedicineStockEvent({
    required String id,
    required String medicineId,
    required int delta,
    required MedicineStockEventReason reason,
    required DateTime occurredAt,
    String? doseId,
  }) = _MedicineStockEvent;
}
