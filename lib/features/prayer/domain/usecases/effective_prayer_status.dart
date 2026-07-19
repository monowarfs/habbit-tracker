import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:timezone/timezone.dart' as tz;

/// Derives a prayer record's live status (FR-P-07). [storedStatus] is
/// only ever `upcoming`/`prayed`/`missed` in the database — `due` is
/// computed here, at read time, mirroring Medicine's
/// `effectiveDoseStatus` precedent.
PrayerStatus effectivePrayerStatus({
  required PrayerStatus storedStatus,
  required DateTime scheduledFor,
  required DateTime cutoff,
  required DateTime now,
}) {
  if (storedStatus != PrayerStatus.upcoming) return storedStatus;
  if (now.isBefore(scheduledFor)) return PrayerStatus.upcoming;
  if (now.isBefore(cutoff)) return PrayerStatus.due;
  return PrayerStatus.missed;
}

/// The cutoff instant (FR-P-05) for [record] — the next-in-day prayer's
/// `scheduledFor` among [sameDayRecordsSorted] (every record for the same
/// `prayerDate`, sorted by `scheduledFor` ascending), or — for the day's
/// last prayer (Isha) — [ishaDayRolloverTime] resolved to the *next*
/// calendar day in [ianaTimezone].
///
/// A `null` [ianaTimezone] falls back to the device's own ambient
/// timezone — same "accepted edge case" precedent as
/// `core/utils/local_day.dart`'s no-location overload of `localDayKey`.
/// Requires `ensureTimeZonesInitialized()` to have already run when
/// [ianaTimezone] is non-null.
DateTime cutoffForPrayer({
  required PrayerRecord record,
  required List<PrayerRecord> sameDayRecordsSorted,
  required LocalTime ishaDayRolloverTime,
  String? ianaTimezone,
}) {
  final index = sameDayRecordsSorted.indexWhere((r) => r.id == record.id);
  if (index != -1 && index < sameDayRecordsSorted.length - 1) {
    return sameDayRecordsSorted[index + 1].scheduledFor;
  }
  final rolloverDay = record.prayerDate.addDays(1);
  if (ianaTimezone == null) {
    final local = DateTime(
      rolloverDay.year,
      rolloverDay.month,
      rolloverDay.day,
      ishaDayRolloverTime.hour,
      ishaDayRolloverTime.minute,
    );
    return local.toUtc();
  }
  final location = tz.getLocation(ianaTimezone);
  final rollover = tz.TZDateTime(
    location,
    rolloverDay.year,
    rolloverDay.month,
    rolloverDay.day,
    ishaDayRolloverTime.hour,
    ishaDayRolloverTime.minute,
  );
  return rollover.toUtc();
}
