import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';

/// A prayer record still to be inserted — the repository assigns its id
/// at insert time (ids are never generated in pure domain code).
typedef PlannedPrayerRecord = ({
  LocalDate prayerDate,
  PrayerName prayerName,
  DateTime scheduledFor,
});

/// Plans which new [PrayerRecord] rows need to exist for
/// `[windowStart, windowEnd]` (D-13's 30-day rolling window). Much
/// simpler than Medicine's repeat-rule planner — one settings row, not N
/// schedules, no collision resolution needed. For each day, for each of
/// the 5 prayers (Friday's Dhuhr slot is still `prayerName: dhuhr` —
/// Jumu'ah is a display label, not a separate row, per D-07), if
/// `(prayerDate, prayerName)` is missing from [existingRecords], plans it
/// via [calculatePrayerTimes].
List<PlannedPrayerRecord> planPrayerMaterialization({
  required PrayerSettings settings,
  required ResolvedLocation location,
  required List<PrayerRecord> existingRecords,
  required LocalDate windowStart,
  required LocalDate windowEnd,
}) {
  if (windowEnd.compareTo(windowStart) < 0) return [];
  final existingSlots = {
    for (final r in existingRecords) (r.prayerDate, r.prayerName),
  };
  final planned = <PlannedPrayerRecord>[];
  var day = windowStart;
  while (day.compareTo(windowEnd) <= 0) {
    final times = calculatePrayerTimes(
      date: day,
      latitude: location.latitude,
      longitude: location.longitude,
      ianaTimezone: location.ianaTimezone,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
    );
    for (final slot in _slotsFor(times)) {
      final key = (day, slot.name);
      if (existingSlots.contains(key)) continue;
      planned.add((
        prayerDate: day,
        prayerName: slot.name,
        scheduledFor: slot.time,
      ));
    }
    day = day.addDays(1);
  }
  return planned;
}

List<({PrayerName name, DateTime time})> _slotsFor(PrayerTimes times) => [
  (name: PrayerName.fajr, time: times.fajr),
  (name: PrayerName.dhuhr, time: times.dhuhr),
  (name: PrayerName.asr, time: times.asr),
  (name: PrayerName.maghrib, time: times.maghrib),
  (name: PrayerName.isha, time: times.isha),
];
