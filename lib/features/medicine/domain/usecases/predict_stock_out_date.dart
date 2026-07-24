import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/stock_projection.dart';

/// Projects when [Medicine.stockCount] will run out from the recent
/// dose-taken consumption rate (`docs/superpowers/plans/ai-powered/
/// 03-predictive-stock-out-date-impl-plan.md`) — a simple average-rate
/// projection, deliberately not a forecasting model (seasonality/trend
/// detection is out of scope).
class PredictStockOutDateUseCase {
  /// Creates the use case.
  const PredictStockOutDateUseCase({this.consumptionWindowDays = 30});

  /// Rolling lookback window for consumption history.
  final int consumptionWindowDays;

  /// Computes the projection for [medicine] as of [now], from its
  /// [stockEvents] (every event, any medicine — this filters to
  /// [medicine]'s own and to the lookback window internally).
  StockProjection execute({
    required Medicine medicine,
    required List<MedicineStockEvent> stockEvents,
    required DateTime now,
  }) {
    final currentStock = medicine.stockCount ?? 0;
    if (currentStock == 0) {
      return StockProjection(
        projectedDate: now,
        daysRemaining: 0,
        sampleSize: 0,
        confidence: 'low',
        currentStock: 0,
      );
    }

    final since = now.subtract(Duration(days: consumptionWindowDays));
    final doseTakenEvents =
        stockEvents
            .where(
              (e) =>
                  e.medicineId == medicine.id &&
                  e.reason == MedicineStockEventReason.doseTaken &&
                  e.occurredAt.isAfter(since) &&
                  !e.occurredAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    if (doseTakenEvents.isEmpty) {
      return StockProjection(
        sampleSize: 0,
        confidence: 'low',
        currentStock: currentStock,
      );
    }

    final totalConsumed = doseTakenEvents
        .map((e) => e.delta.abs())
        .reduce((a, b) => a + b);
    final daysSpan = doseTakenEvents.last.occurredAt
        .difference(doseTakenEvents.first.occurredAt)
        .inDays
        .clamp(1, consumptionWindowDays);
    final averageRatePerDay = totalConsumed / daysSpan;

    if (averageRatePerDay == 0) {
      return StockProjection(
        averageRatePerDay: 0,
        sampleSize: doseTakenEvents.length,
        confidence: 'low',
        currentStock: currentStock,
      );
    }

    final daysRemaining = (currentStock / averageRatePerDay).round();
    final sampleSize = doseTakenEvents.length;
    final confidence = sampleSize >= 10 && daysSpan >= 7
        ? 'high'
        : (sampleSize >= 5 || daysSpan >= 3)
        ? 'medium'
        : 'low';

    return StockProjection(
      projectedDate: now.add(Duration(days: daysRemaining)),
      daysRemaining: daysRemaining,
      averageRatePerDay: averageRatePerDay,
      sampleSize: sampleSize,
      confidence: confidence,
      currentStock: currentStock,
    );
  }
}
