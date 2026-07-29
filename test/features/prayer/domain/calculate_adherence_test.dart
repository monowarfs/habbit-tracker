import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_adherence.dart';

void main() {
  final scheduledFor = DateTime.utc(2026, 6, 1, 8);

  PrayerRecord record({
    required PrayerName name,
    required PrayerStatus status,
    DateTime? statusChangedAt,
  }) => PrayerRecord(
    id: '${name.name}_${status.name}_${statusChangedAt ?? ''}',
    prayerDate: const LocalDate(2026, 6, 1),
    prayerName: name,
    scheduledFor: scheduledFor,
    storedStatus: status,
    statusChangedAt: statusChangedAt,
  );

  test('classifies prayed/missed per prayer, excludes upcoming/due', () {
    final stats = calculateAdherence(
      records: [
        record(name: PrayerName.fajr, status: PrayerStatus.prayed),
        record(name: PrayerName.fajr, status: PrayerStatus.missed),
        record(name: PrayerName.dhuhr, status: PrayerStatus.prayed),
        record(name: PrayerName.dhuhr, status: PrayerStatus.upcoming),
      ],
    );
    expect(stats[PrayerName.fajr]!.prayed, 1);
    expect(stats[PrayerName.fajr]!.missed, 1);
    expect(stats[PrayerName.fajr]!.total, 2);
    expect(stats[PrayerName.dhuhr]!.prayed, 1);
    expect(stats[PrayerName.dhuhr]!.total, 1); // upcoming excluded
    expect(stats[PrayerName.asr]!.total, 0); // no records at all
  });

  test('splits prayed records into on-time vs late', () {
    final stats = calculateAdherence(
      records: [
        record(
          name: PrayerName.fajr,
          status: PrayerStatus.prayed,
          statusChangedAt: scheduledFor.add(const Duration(minutes: 5)),
        ),
        record(
          name: PrayerName.fajr,
          status: PrayerStatus.prayed,
          statusChangedAt: scheduledFor.add(const Duration(minutes: 30)),
        ),
        record(name: PrayerName.fajr, status: PrayerStatus.missed),
      ],
    );
    expect(stats[PrayerName.fajr]!.prayed, 1);
    expect(stats[PrayerName.fajr]!.prayedLate, 1);
    expect(stats[PrayerName.fajr]!.missed, 1);
    expect(stats[PrayerName.fajr]!.total, 3);
  });

  test('a prayed record with no statusChangedAt counts as on time', () {
    final stats = calculateAdherence(
      records: [record(name: PrayerName.fajr, status: PrayerStatus.prayed)],
    );
    expect(stats[PrayerName.fajr]!.prayed, 1);
    expect(stats[PrayerName.fajr]!.prayedLate, 0);
  });
}
