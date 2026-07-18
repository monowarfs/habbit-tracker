import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/stock_adjustment.dart';

void main() {
  group('calculateDoseTakenAdjustment', () {
    test('normal path: decrements by consumptionPerDose, writes an event', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 10,
        consumptionPerDose: 2,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.newStockCount, 8);
      expect(result.stockDelta, -2);
      expect(result.writesEvent, isTrue);
    });

    test('never goes below zero', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 1,
        consumptionPerDose: 5,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.newStockCount, 0);
    });

    test('"taken from other source": no decrement, no event (FR-M-05)', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 0,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: true,
      );
      expect(result.newStockCount, 0);
      expect(result.stockDelta, 0);
      expect(result.writesEvent, isFalse);
    });

    test('stock tracking disabled: no decrement, no event', () {
      final medicine = Medicine(id: 'm1', name: 'Ibuprofen', stockEnabled: false);
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.stockDelta, 0);
      expect(result.writesEvent, isFalse);
    });
  });

  group('calculateDoseUndoneAdjustment', () {
    test('reverses a prior decrement exactly', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 8,
      );
      final result = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: -2,
      );
      expect(result.newStockCount, 10);
      expect(result.stockDelta, 2);
    });

    test('undoing a "taken from other source" dose (delta 0) is a no-op', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 5,
      );
      final result = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: 0,
      );
      expect(result.newStockCount, 5);
      expect(result.stockDelta, 0);
    });
  });
}
