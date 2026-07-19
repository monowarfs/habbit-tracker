import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

part 'prayer_qadha_counter.freezed.dart';

/// One prayer's running Qadha (missed-prayer make-up) balance (D-08).
/// Exactly five rows exist, one per [PrayerName] — Jumu'ah shares Dhuhr's
/// bucket (D-07/FR-P-03), so there is no sixth row.
@freezed
sealed class PrayerQadhaCounter with _$PrayerQadhaCounter {
  /// Creates a Qadha counter.
  const factory PrayerQadhaCounter({
    required String id,
    required PrayerName prayerName,
    required int count,
    required DateTime updatedAt,
  }) = _PrayerQadhaCounter;
}
