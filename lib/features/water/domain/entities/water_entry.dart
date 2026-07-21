import 'package:freezed_annotation/freezed_annotation.dart';

part 'water_entry.freezed.dart';

/// How a [WaterEntry] was logged.
enum WaterEntrySource {
  /// Logged via a one-tap quick-add preset (FR-W-03).
  quick,

  /// Logged via the custom-amount entry screen (FR-W-03/FR-W-05).
  custom,
}

/// A single water-intake log row (`technical/data-models.md`).
@freezed
sealed class WaterEntry with _$WaterEntry {
  /// Creates a water entry.
  const factory WaterEntry({
    required String id,
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
    String? notes,
  }) = _WaterEntry;
}
