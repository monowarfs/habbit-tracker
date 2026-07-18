import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'water_settings.freezed.dart';

/// The Water module's own singleton settings row: quick-add presets
/// (FR-W-03) and reminder preferences (FR-W-10, data only this run — the
/// actual OS scheduling lands in a later run).
@freezed
sealed class WaterSettings with _$WaterSettings {
  /// Creates water module settings.
  const factory WaterSettings({
    required List<int> quickAddAmountsMl,
    required bool reminderEnabled,
    required int reminderIntervalMinutes,
    required LocalTime reminderWindowStart,
    required LocalTime reminderWindowEnd,
  }) = _WaterSettings;
}
