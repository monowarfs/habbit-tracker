import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'water_settings.freezed.dart';

/// The Water module's own singleton settings row: quick-add presets
/// (FR-W-03) and reminder preferences (FR-W-10) — scheduled as real OS
/// notifications by `core/notifications` (Run 08).
@freezed
sealed class WaterSettings with _$WaterSettings {
  /// Creates water module settings.
  const factory WaterSettings({
    required List<int> quickAddAmountsMl,
    required bool reminderEnabled,
    required int reminderIntervalMinutes,
    required LocalTime reminderWindowStart,
    required LocalTime reminderWindowEnd,
    @Default({})
    Map<int, ({LocalTime start, LocalTime end})> reminderWindowOverrides,
  }) = _WaterSettings;
}
