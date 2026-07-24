import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/predict_stock_out_date.dart';

void main() {
  const useCase = PredictStockOutDateUseCase();
  final now = DateTime.utc(2026, 6, 30);
  const medicineId = 'm1';

  Medicine medicine({required int? stockCount}) => Medicine(
    id: medicineId,
    name: 'Test',
    stockEnabled: true,
    stockCount: stockCount,
  );

  MedicineStockEvent event({
    required int delta,
    required DateTime occurredAt,
    MedicineStockEventReason reason = MedicineStockEventReason.doseTaken,
  }) => MedicineStockEvent(
    id: 'e-${occurredAt.millisecondsSinceEpoch}-$delta',
    medicineId: medicineId,
    delta: delta,
    reason: reason,
    occurredAt: occurredAt,
  );

  test(
    '10 dose-taken events over a 9-day span -> correct rate and '
    'high confidence',
    () {
      final events = [
        for (var i = 0; i < 10; i++)
          event(
            delta: -9,
            occurredAt: DateTime.utc(2026, 6).add(Duration(days: i)),
          ),
      ];
      final result = useCase.execute(
        medicine: medicine(stockCount: 200),
        stockEvents: events,
        now: now,
      );

      expect(result.sampleSize, 10);
      expect(result.averageRatePerDay, 10.0);
      expect(result.daysRemaining, 20);
      expect(result.projectedDate, now.add(const Duration(days: 20)));
      expect(result.confidence, 'high');
    },
  );

  test('5 events over a 4-day span -> medium confidence', () {
    final events = [
      for (var i = 0; i < 5; i++)
        event(
          delta: -2,
          occurredAt: DateTime.utc(2026, 6).add(Duration(days: i)),
        ),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 25),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 5);
    expect(result.averageRatePerDay, 2.5);
    expect(result.daysRemaining, 10);
    expect(result.confidence, 'medium');
  });

  test('no events -> sampleSize 0, null projection, low confidence', () {
    final result = useCase.execute(
      medicine: medicine(stockCount: 30),
      stockEvents: const [],
      now: now,
    );

    expect(result.sampleSize, 0);
    expect(result.projectedDate, isNull);
    expect(result.daysRemaining, isNull);
    expect(result.confidence, 'low');
  });

  test('only refill events -> same as no events', () {
    final events = [
      event(
        delta: 30,
        reason: MedicineStockEventReason.manualRefill,
        occurredAt: now.subtract(const Duration(days: 5)),
      ),
      event(
        delta: 5,
        reason: MedicineStockEventReason.manualAdjustment,
        occurredAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 30),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 0);
    expect(result.projectedDate, isNull);
    expect(result.confidence, 'low');
  });

  test('zero stock -> daysRemaining 0, projectedDate is now', () {
    final result = useCase.execute(
      medicine: medicine(stockCount: 0),
      stockEvents: const [],
      now: now,
    );

    expect(result.daysRemaining, 0);
    expect(result.projectedDate, now);
  });

  test('an undo event is excluded from the consumption rate', () {
    final events = [
      for (var i = 0; i < 10; i++)
        event(
          delta: -9,
          occurredAt: DateTime.utc(2026, 6).add(Duration(days: i)),
        ),
      // A large undo that would badly skew the rate if it weren't
      // excluded — it reverses a dose-taken decrement, not a consumption.
      event(
        delta: 900,
        reason: MedicineStockEventReason.doseUndone,
        occurredAt: DateTime.utc(2026, 6, 5),
      ),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 200),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 10);
    expect(result.averageRatePerDay, 10.0);
  });

  test('a single event on one day -> daysSpan clamps to 1', () {
    final events = [
      event(delta: -5, occurredAt: now.subtract(const Duration(hours: 2))),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 50),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 1);
    expect(result.averageRatePerDay, 5.0);
    expect(result.daysRemaining, 10);
  });

  test('events outside the 30-day window are excluded from the rate', () {
    final events = [
      // Well outside the window — must not count.
      event(delta: -100, occurredAt: now.subtract(const Duration(days: 60))),
      // Inside the window.
      for (var i = 0; i < 5; i++)
        event(
          delta: -2,
          occurredAt: now.subtract(Duration(days: 10 - i * 2)),
        ),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 50),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 5);
  });

  test('events for a different medicine are ignored', () {
    final events = [
      event(
        delta: -9,
        occurredAt: now.subtract(const Duration(days: 1)),
      ).copyWith(medicineId: 'other-medicine'),
    ];
    final result = useCase.execute(
      medicine: medicine(stockCount: 50),
      stockEvents: events,
      now: now,
    );

    expect(result.sampleSize, 0);
  });

  test('null stockCount is treated as zero stock', () {
    final result = useCase.execute(
      medicine: medicine(stockCount: null),
      stockEvents: const [],
      now: now,
    );

    expect(result.currentStock, 0);
    expect(result.daysRemaining, 0);
  });
}
