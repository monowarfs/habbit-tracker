import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// One day's five prayer instants, UTC.
typedef PrayerTimes = ({
  DateTime fajr,
  DateTime dhuhr,
  DateTime asr,
  DateTime maghrib,
  DateTime isha,
});

/// Pure wrapper over `adhan_dart` (FR-P-01/02) — no `clock.now()`, the
/// caller supplies [date]. The package's own import is aliased as
/// `adhan.*` throughout this file since its `PrayerTimes` class would
/// otherwise collide with this file's own [PrayerTimes] records typedef
/// (this plan's design carries the design spec's exact typedef name
/// forward; only the import needed disambiguating).
///
/// Requires `ensureTimeZonesInitialized()` (`core/utils/local_day.dart`)
/// to have already run.
PrayerTimes calculatePrayerTimes({
  required LocalDate date,
  required double latitude,
  required double longitude,
  required String ianaTimezone,
  required CalculationMethod method,
  required AsrMethod asrMethod,
}) {
  final location = tz.getLocation(ianaTimezone);
  // Noon (not midnight) local, converted to UTC — `adhan_dart` only needs
  // the calendar date component, and noon avoids any ambiguity a midnight
  // instant could hit right at a DST transition boundary.
  final localNoon = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    12,
  );
  final coordinates = adhan.Coordinates(latitude, longitude);
  final params = _parametersFor(method)
    ..madhab = asrMethod == AsrMethod.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;

  final times = adhan.PrayerTimes(
    coordinates: coordinates,
    date: localNoon.toUtc(),
    calculationParameters: params,
    precision: true,
  );

  return (
    fajr: times.fajr.toUtc(),
    dhuhr: times.dhuhr.toUtc(),
    asr: times.asr.toUtc(),
    maghrib: times.maghrib.toUtc(),
    isha: times.isha.toUtc(),
  );
}

adhan.CalculationParameters _parametersFor(CalculationMethod method) =>
    switch (method) {
      CalculationMethod.mwl =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      CalculationMethod.isna =>
        adhan.CalculationMethodParameters.northAmerica(),
      CalculationMethod.egyptian =>
        adhan.CalculationMethodParameters.egyptian(),
      CalculationMethod.ummAlQura =>
        adhan.CalculationMethodParameters.ummAlQura(),
      CalculationMethod.karachi =>
        adhan.CalculationMethodParameters.karachi(),
      CalculationMethod.tehran =>
        adhan.CalculationMethodParameters.tehran(),
      CalculationMethod.dubai =>
        adhan.CalculationMethodParameters.dubai(),
      CalculationMethod.kuwait =>
        adhan.CalculationMethodParameters.kuwait(),
      CalculationMethod.qatar =>
        adhan.CalculationMethodParameters.qatar(),
      CalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
    };
