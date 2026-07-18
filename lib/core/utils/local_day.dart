import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

/// Loads the IANA timezone database `localDayKey`'s `location` parameter
/// needs. Idempotent — safe to call from every entry point (app startup,
/// each test file) without guarding it yourself.
void ensureTimeZonesInitialized() {
  if (_initialized) return;
  tz_data.initializeTimeZones();
  _initialized = true;
}

/// The local calendar day [utcInstant] falls on (D-14,
/// `../technical/database-design.md`'s local-day bucketing rule).
///
/// With [location] given, the instant is resolved against that IANA
/// timezone (DST-correct, deterministic regardless of the host machine's
/// own timezone) — call [ensureTimeZonesInitialized] first. Without it,
/// falls back to the device's current ambient timezone
/// (`DateTime.toLocal()`) — the cheap, "accepted edge case" bucketing
/// `database-design.md` specifies for water logs, where a mid-flight
/// timezone change is rare and low-stakes.
LocalDate localDayKey(DateTime utcInstant, {tz.Location? location}) {
  final resolved = location != null
      ? tz.TZDateTime.from(utcInstant, location)
      : utcInstant.toLocal();
  return LocalDate.fromDateTime(resolved);
}
