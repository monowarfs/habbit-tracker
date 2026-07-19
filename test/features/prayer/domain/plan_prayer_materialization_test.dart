import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/plan_prayer_materialization.dart';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.auto,
  );
  const location = (
    latitude: 23.8103,
    longitude: 90.4125,
    ianaTimezone: 'Asia/Dhaka',
  );

  test('generates 5 records per day across the window', () {
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 2),
    );
    expect(planned, hasLength(10)); // 2 days x 5 prayers
    expect(
      planned.map((p) => p.prayerName).toSet(),
      PrayerName.values.toSet(),
    );
  });

  test('never re-plans a slot that already has a record', () {
    final existing = PrayerRecord(
      id: 'r1',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 0),
      storedStatus: PrayerStatus.prayed,
    );
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: [existing],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, hasLength(4)); // 5 minus the already-existing Fajr
    expect(planned.any((p) => p.prayerName == PrayerName.fajr), isFalse);
  });

  test('windowEnd before windowStart returns empty, not an error', () {
    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: const [],
      windowStart: const LocalDate(2026, 6, 10),
      windowEnd: const LocalDate(2026, 6, 5),
    );
    expect(planned, isEmpty);
  });
}
