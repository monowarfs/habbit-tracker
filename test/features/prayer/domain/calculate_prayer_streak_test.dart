import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';

void main() {
  List<PrayerRecord> allPrayed(LocalDate date) => [
    for (final name in PrayerName.values)
      PrayerRecord(
        id: '${date.toIso()}_${name.name}',
        prayerDate: date,
        prayerName: name,
        scheduledFor: date.toDateTimeUtc(),
        storedStatus: PrayerStatus.prayed,
      ),
  ];

  List<PrayerRecord> oneMissed(LocalDate date) => [
    for (final name in PrayerName.values)
      PrayerRecord(
        id: '${date.toIso()}_${name.name}',
        prayerDate: date,
        prayerName: name,
        scheduledFor: date.toDateTimeUtc(),
        storedStatus: name == PrayerName.fajr
            ? PrayerStatus.missed
            : PrayerStatus.prayed,
      ),
  ];

  test('3 consecutive fully-prayed days: current and longest both 3', () {
    const day1 = LocalDate(2026, 6, 1);
    const day2 = LocalDate(2026, 6, 2);
    const day3 = LocalDate(2026, 6, 3);
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: {
        day1: allPrayed(day1),
        day2: allPrayed(day2),
        day3: allPrayed(day3),
      },
      earliestDay: day1,
      today: day3,
    );
    expect(result.current, 3);
    expect(result.longest, 3);
  });

  test('a day missing one prayer breaks the running streak', () {
    const day1 = LocalDate(2026, 6, 1);
    const day2 = LocalDate(2026, 6, 2);
    const day3 = LocalDate(2026, 6, 3);
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: {
        day1: allPrayed(day1),
        day2: oneMissed(day2),
        day3: allPrayed(day3),
      },
      earliestDay: day1,
      today: day3,
    );
    expect(result.current, 1); // just day3
    expect(result.longest, 1); // day1 alone, before the break
  });

  test(
    'today still in progress (an upcoming record) is skipped, not '
    'counted and not broken — current reflects the last fully-resolved day',
    () {
      const day1 = LocalDate(2026, 6, 1);
      const today = LocalDate(2026, 6, 2);
      final inProgress = [
        for (final name in PrayerName.values)
          PrayerRecord(
            id: 'today_${name.name}',
            prayerDate: today,
            prayerName: name,
            scheduledFor: today.toDateTimeUtc(),
            storedStatus: name == PrayerName.isha
                ? PrayerStatus.upcoming
                : PrayerStatus.prayed,
          ),
      ];
      final result = const CalculatePrayerStreakUseCase().execute(
        recordsByDay: {day1: allPrayed(day1), today: inProgress},
        earliestDay: day1,
        today: today,
      );
      expect(result.current, 1);
    },
  );

  test('earliestDay after today returns a zero result', () {
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: const {},
      earliestDay: const LocalDate(2026, 6, 10),
      today: const LocalDate(2026, 6, 1),
    );
    expect(result.current, 0);
    expect(result.longest, 0);
  });
}
