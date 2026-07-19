import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'prayer_record.freezed.dart';

/// One of the five daily obligatory prayers. Exactly five values —
/// Jumu'ah is a Friday-only *display label* applied over `dhuhr`
/// (D-07/FR-P-03), never its own materialized value (this plan's
/// refinements section, #1).
enum PrayerName {
  /// Fajr (dawn) prayer.
  fajr,

  /// Dhuhr (midday) prayer.
  dhuhr,

  /// Asr (afternoon) prayer.
  asr,

  /// Maghrib (sunset) prayer.
  maghrib,

  /// Isha (night) prayer.
  isha,
}

/// A prayer record's status. `due` is never persisted — computed at read
/// time (`effective_prayer_status.dart`). `missed` IS persisted, unlike
/// Medicine's transient `missed`, because crossing into it has a
/// one-shot Qadha side effect (FR-P-05).
enum PrayerStatus {
  /// Not yet its scheduled time.
  upcoming,

  /// Past its scheduled time, not yet its cutoff (derived, never stored).
  due,

  /// Marked as prayed by the user.
  prayed,

  /// Past its cutoff without being prayed (persisted).
  missed,
}

/// A materialized prayer record (D-13), one per prayer per local day,
/// rolling 30-day window (`technical/database-design.md`).
@freezed
sealed class PrayerRecord with _$PrayerRecord {
  /// Creates a prayer record.
  const factory PrayerRecord({
    required String id,
    required LocalDate prayerDate,
    required PrayerName prayerName,
    required DateTime scheduledFor,
    required PrayerStatus storedStatus,
    DateTime? statusChangedAt,
  }) = _PrayerRecord;
}
