import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('localDayKey with an explicit location (deterministic, DST-safe)', () {
    late tz.Location newYork;

    setUp(() {
      newYork = tz.getLocation('America/New_York');
    });

    test('spring-forward: 2026-03-08 02:30 EST does not exist, but the '
        'surrounding instants still bucket to the correct calendar day', () {
      // 2026-03-08 06:59:59 UTC = 2026-03-08 01:59:59 EST (just before the
      // 2am->3am jump).
      final justBeforeJump = DateTime.utc(2026, 3, 8, 6, 59, 59);
      expect(
        localDayKey(justBeforeJump, location: newYork),
        const LocalDate(2026, 3, 8),
      );

      // 2026-03-08 07:00:01 UTC = 2026-03-08 03:00:01 EDT (just after the
      // jump) — still the same calendar day, despite the 1-hour clock skip.
      final justAfterJump = DateTime.utc(2026, 3, 8, 7, 0, 1);
      expect(
        localDayKey(justAfterJump, location: newYork),
        const LocalDate(2026, 3, 8),
      );
    });

    test('fall-back: 2026-11-01 01:30 occurs twice (EDT then EST), both '
        'instants still bucket to the same calendar day', () {
      // First 1:30am EDT (before the fall-back).
      final firstOneThirty = DateTime.utc(2026, 11, 1, 5, 30);
      expect(
        localDayKey(firstOneThirty, location: newYork),
        const LocalDate(2026, 11, 1),
      );

      // Second 1:30am EST (after the fall-back, 1 hour later in UTC).
      final secondOneThirty = DateTime.utc(2026, 11, 1, 6, 30);
      expect(
        localDayKey(secondOneThirty, location: newYork),
        const LocalDate(2026, 11, 1),
      );
    });

    test('a positive-offset timezone shifts the calendar day relative to '
        'UTC, independent of DST', () {
      final dhaka = tz.getLocation('Asia/Dhaka'); // UTC+6, no DST
      // 2026-07-17 23:30 UTC is already 2026-07-18 05:30 in Dhaka.
      final lateUtc = DateTime.utc(2026, 7, 17, 23, 30);
      expect(
        localDayKey(lateUtc, location: dhaka),
        const LocalDate(2026, 7, 18),
      );
      expect(
        localDayKey(lateUtc, location: newYork),
        const LocalDate(2026, 7, 17),
      );
    });
  });

  test('localDayKey without a location falls back to ambient device time '
      'without throwing', () {
    expect(() => localDayKey(DateTime.utc(2026)), returnsNormally);
  });
}
