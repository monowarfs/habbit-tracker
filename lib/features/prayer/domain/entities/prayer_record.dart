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
/// one-shot Qadha side effect (FR-P-05). `prayedLate` is likewise never
/// persisted — the DB always stores `prayed`; `prayedLate` only ever
/// comes out of `effectivePrayerStatus`'s on-time/late derivation
/// (08-analytics/10-prayer-on-time-vs-late) for callers that opt into it.
enum PrayerStatus {
  /// Not yet its scheduled time.
  upcoming,

  /// Past its scheduled time, not yet its cutoff (derived, never stored).
  due,

  /// Marked as prayed by the user, within the on-time grace window.
  prayed,

  /// Marked as prayed, but after the on-time grace window (derived,
  /// never stored — see `effectivePrayerStatus`).
  prayedLate,

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
    String? notes,
  }) = _PrayerRecord;
}
