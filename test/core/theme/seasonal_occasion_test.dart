import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('activeSeasonalOccasion', () {
    test('13 April is inside the Pohela Boishakh window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 13)),
        SeasonalOccasion.pohelaBoishakh,
      );
    });

    test('14 April (the day itself) is inside the window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 14)),
        SeasonalOccasion.pohelaBoishakh,
      );
    });

    test('15 April is inside the window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 15)),
        SeasonalOccasion.pohelaBoishakh,
      );
    });

    test('12 April is outside the window', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 4, 12)), isNull);
    });

    test('16 April is outside the window', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 4, 16)), isNull);
    });

    test('a date in an unrelated month returns null', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 7, 23)), isNull);
    });

    test(
      'Eid is never detected — permanently a documented no-op until a '
      'Hijri date source exists (shared prerequisite with Ramadan mode)',
      () {
        // Sweep every day of a full year: activeSeasonalOccasion must
        // never return SeasonalOccasion.eid, regardless of date.
        var day = const LocalDate(2026, 1, 1);
        for (var i = 0; i < 365; i++) {
          expect(activeSeasonalOccasion(day), isNot(SeasonalOccasion.eid));
          day = day.addDays(1);
        }
      },
    );
  });
}
