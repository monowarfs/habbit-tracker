import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('isRamadan / ramadanDayNumber', () {
    test('2025-03-05 (day 5 of Ramadan 1446 AH, Umm al-Qura) is Ramadan', () {
      const date = LocalDate(2025, 3, 5);
      expect(isRamadan(date), isTrue);
      expect(ramadanDayNumber(date), 5);
    });

    test(
      '2025-04-01 (a few days after Eid al-Fitr 1446 AH) is not Ramadan',
      () {
        const date = LocalDate(2025, 4, 1);
        expect(isRamadan(date), isFalse);
        expect(ramadanDayNumber(date), isNull);
      },
    );

    test('a date far from Ramadan (mid-year) is not Ramadan', () {
      const date = LocalDate(2025, 8, 15);
      expect(isRamadan(date), isFalse);
      expect(ramadanDayNumber(date), isNull);
    });
  });

  group('resolveRamadanModeActive', () {
    const ramadanDay = LocalDate(2025, 3, 5);
    const nonRamadanDay = LocalDate(2025, 8, 15);

    test('manual override true wins regardless of the calendar date', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: true,
          autoDetectEnabled: true,
          today: nonRamadanDay,
        ),
        isTrue,
      );
    });

    test('manual override false wins even during real Ramadan', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: false,
          autoDetectEnabled: true,
          today: ramadanDay,
        ),
        isFalse,
      );
    });

    test('no override + auto-detect on follows the Hijri calendar', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: true,
          today: ramadanDay,
        ),
        isTrue,
      );
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: true,
          today: nonRamadanDay,
        ),
        isFalse,
      );
    });

    test('no override + auto-detect off is always inactive', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: false,
          today: ramadanDay,
        ),
        isFalse,
      );
    });
  });
}
