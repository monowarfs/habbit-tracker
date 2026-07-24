import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_projection.freezed.dart';

/// A derived (never persisted) projection of when a medicine's stock will
/// run out, computed from its recent consumption rate
/// (`docs/superpowers/plans/ai-powered/
/// 03-predictive-stock-out-date-impl-plan.md`). `null` fields mean the
/// rate couldn't be computed (no consumption data yet).
@freezed
sealed class StockProjection with _$StockProjection {
  /// Creates a [StockProjection].
  const factory StockProjection({
    DateTime? projectedDate,
    int? daysRemaining,
    double? averageRatePerDay,
    required int sampleSize,
    required String confidence,
    required int currentStock,
  }) = _StockProjection;
}
