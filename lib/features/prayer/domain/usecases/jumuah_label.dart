import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Whether [prayerName] on [date] should display as "Jumu'ah" instead of
/// "Dhuhr" (D-07/FR-P-03) — a pure render-time label decision; the
/// underlying record is always `prayerName: dhuhr`, sharing Dhuhr's
/// schedule and Qadha bucket (this plan's refinements section, #1).
bool isJumuahDisplay({
  required PrayerName prayerName,
  required LocalDate date,
  required bool observesJumuah,
}) {
  if (prayerName != PrayerName.dhuhr || !observesJumuah) return false;
  return date.toDateTimeUtc().weekday == DateTime.friday;
}
