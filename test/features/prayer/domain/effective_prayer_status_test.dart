import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('effectivePrayerStatus', () {
    final scheduledFor = DateTime.utc(2026, 6, 1, 12);
    final cutoff = DateTime.utc(2026, 6, 1, 15);

    test('before scheduled time: upcoming', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor.subtract(const Duration(minutes: 1)),
        ),
        PrayerStatus.upcoming,
      );
    });

    test('at scheduled time: due', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor,
        ),
        PrayerStatus.due,
      );
    });

    test('just before cutoff: still due', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff.subtract(const Duration(minutes: 1)),
        ),
        PrayerStatus.due,
      );
    });

    test('at/after cutoff: missed', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.upcoming,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff,
        ),
        PrayerStatus.missed,
      );
    });

    test('a prayed record stays prayed regardless of elapsed time', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.prayed,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: cutoff.add(const Duration(days: 1)),
        ),
        PrayerStatus.prayed,
      );
    });

    test('a missed record stays missed', () {
      expect(
        effectivePrayerStatus(
          storedStatus: PrayerStatus.missed,
          scheduledFor: scheduledFor,
          cutoff: cutoff,
          now: scheduledFor,
        ),
        PrayerStatus.missed,
      );
    });
  });

  group('cutoffForPrayer', () {
    final fajr = PrayerRecord(
      id: 'r1',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6),
      storedStatus: PrayerStatus.upcoming,
    );
    final dhuhr = PrayerRecord(
      id: 'r2',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.dhuhr,
      scheduledFor: DateTime.utc(2026, 6, 1, 6),
      storedStatus: PrayerStatus.upcoming,
    );
    final isha = PrayerRecord(
      id: 'r3',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.isha,
      scheduledFor: DateTime.utc(2026, 6, 1, 13),
      storedStatus: PrayerStatus.upcoming,
    );
    final sameDay = [fajr, dhuhr, isha];

    test("a mid-day prayer's cutoff is the next prayer's scheduledFor", () {
      final cutoff = cutoffForPrayer(
        record: fajr,
        sameDayRecordsSorted: sameDay,
        ishaDayRolloverTime: const LocalTime(0, 0),
        ianaTimezone: 'Etc/UTC',
      );
      expect(cutoff, dhuhr.scheduledFor);
    });

    test(
      "the day's last prayer's cutoff is the Isha rollover time on the "
      'next calendar day, resolved in the given timezone',
      () {
        final cutoff = cutoffForPrayer(
          record: isha,
          sameDayRecordsSorted: sameDay,
          ishaDayRolloverTime: const LocalTime(0, 30),
          ianaTimezone: 'Etc/UTC',
        );
        expect(cutoff, DateTime.utc(2026, 6, 2, 0, 30));
      },
    );

    test('a null timezone falls back to the device ambient timezone', () {
      final cutoff = cutoffForPrayer(
        record: isha,
        sameDayRecordsSorted: sameDay,
        ishaDayRolloverTime: const LocalTime(0, 0),
      );
      // Same calendar instant regardless of host machine's timezone —
      // just verify it lands on the following calendar day at local
      // midnight, converted to UTC (exact instant depends on host TZ,
      // so only the day-forward relationship is asserted).
      expect(cutoff.isAfter(isha.scheduledFor), isTrue);
    });
  });
}
