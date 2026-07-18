import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine.freezed.dart';

/// A medicine record (FR-M-01/04/05/10).
@freezed
sealed class Medicine with _$Medicine {
  /// Creates a medicine.
  const factory Medicine({
    required String id,
    required String name,
    required bool stockEnabled,
    String? dosageNote,
    int? stockCount,
    int? stockThreshold,
    @Default(false) bool stopWhenStockDepleted,
    @Default(1) int consumptionPerDose,

    /// Set the moment stock crosses at/below [stockThreshold] from above
    /// it; cleared once a refill brings it back above threshold — makes
    /// the low-stock notification fire exactly once per crossing
    /// (FR-M-04).
    DateTime? lowStockNotifiedAt,
    DateTime? archivedAt,
  }) = _Medicine;
}
