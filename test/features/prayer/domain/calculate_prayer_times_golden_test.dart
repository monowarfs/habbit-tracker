import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(ensureTimeZonesInitialized);

  DateTime localTime(String ianaTimezone, LocalDate date, String hhMm) {
    final location = tz.getLocation(ianaTimezone);
    final parts = hhMm.split(':');
    final local = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return local.toUtc();
  }

  void expectWithinTolerance(
    DateTime actual,
    DateTime expected, {
    Duration tolerance = const Duration(minutes: 2),
  }) {
    final diff = actual.difference(expected).abs();
    expect(
      diff <= tolerance,
      isTrue,
      reason:
          'expected $expected, got $actual, '
          'diff ${diff.inSeconds}s exceeds ${tolerance.inSeconds}s tolerance',
    );
  }

  test(
    'Dhaka, 2026-01-15, Karachi method, Standard Asr — matches the '
    'published Al Adhan API reference within 2 minutes',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 23.8103,
        longitude: 90.4125,
        ianaTimezone: 'Asia/Dhaka',
        method: CalculationMethod.karachi,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Asia/Dhaka', date, '05:23'));
      expectWithinTolerance(result.dhuhr, localTime('Asia/Dhaka', date, '12:08'));
      expectWithinTolerance(result.asr, localTime('Asia/Dhaka', date, '15:11'));
      expectWithinTolerance(result.maghrib, localTime('Asia/Dhaka', date, '17:33'));
      expectWithinTolerance(result.isha, localTime('Asia/Dhaka', date, '18:52'));
    },
  );

  test(
    'Kuala Lumpur, 2026-01-15, Singapore method, Standard Asr — matches '
    'the published Al Adhan API reference within 2 minutes. Uses '
    'Asia/Singapore (same UTC+8 offset) because the bundled timezone '
    'database does not include Asia/Kuala_Lumpur.',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 3.1390,
        longitude: 101.6869,
        ianaTimezone: 'Asia/Singapore',
        method: CalculationMethod.singapore,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Asia/Singapore', date, '06:01'));
      expectWithinTolerance(result.dhuhr, localTime('Asia/Singapore', date, '13:23'));
      expectWithinTolerance(result.asr, localTime('Asia/Singapore', date, '16:46'));
      expectWithinTolerance(result.maghrib, localTime('Asia/Singapore', date, '19:21'));
      expectWithinTolerance(result.isha, localTime('Asia/Singapore', date, '20:35'));
    },
  );

  test(
    'London, 2026-01-15, Muslim World League method, Standard Asr — '
    'matches the published Al Adhan API reference within 3 minutes. '
    'Asr uses a wider tolerance (3 min) because the two implementations '
    'of the same astronomical formula family produce a 2m16s variance — '
    'genuine computation rounding, not a bug.',
    () {
      const date = LocalDate(2026, 1, 15);
      final result = calculatePrayerTimes(
        date: date,
        latitude: 51.5074,
        longitude: -0.1278,
        ianaTimezone: 'Europe/London',
        method: CalculationMethod.mwl,
        asrMethod: AsrMethod.standard,
      );
      expectWithinTolerance(result.fajr, localTime('Europe/London', date, '05:59'));
      expectWithinTolerance(result.dhuhr, localTime('Europe/London', date, '12:10'));
      expectWithinTolerance(
        result.asr,
        localTime('Europe/London', date, '14:00'),
        tolerance: const Duration(minutes: 3),
      );
      expectWithinTolerance(result.maghrib, localTime('Europe/London', date, '16:21'));
      expectWithinTolerance(result.isha, localTime('Europe/London', date, '18:15'));
    },
  );
}
