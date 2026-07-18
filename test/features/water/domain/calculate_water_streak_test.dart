import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(ensureTimeZonesInitialized);

  const useCase = CalculateWaterStreakUseCase();
  final flatGoal = [
    WaterGoal(id: 'g', goalMl: 2000, effectiveFrom: DateTime.utc(2026)),
  ];

  test('all days meeting goal produce a streak spanning the whole window', () {
    final result = useCase.execute(
      dailyTotalsMl: {
        const LocalDate(2026, 6, 1): 2000,
        const LocalDate(2026, 6, 2): 2500,
        const LocalDate(2026, 6, 3): 2000,
      },
      goals: flatGoal,
      earliestDay: const LocalDate(2026, 6, 1),
      today: const LocalDate(2026, 6, 3),
    );
    expect(result, const WaterStreakResult(current: 3, longest: 3));
  });

  test('a day with zero entries breaks the streak at rollover, current '
      'streak restarts from the day after the break', () {
    final result = useCase.execute(
      dailyTotalsMl: {
        const LocalDate(2026, 6, 1): 2000,
        const LocalDate(2026, 6, 2): 2000,
        // 6/3 absent = 0, breaks the streak
        const LocalDate(2026, 6, 4): 2000,
        const LocalDate(2026, 6, 5): 2000,
      },
      goals: flatGoal,
      earliestDay: const LocalDate(2026, 6, 1),
      today: const LocalDate(2026, 6, 5),
    );
    // current streak: 6/4-6/5 = 2. longest: either the first 2-day run or
    // the second, both length 2.
    expect(result, const WaterStreakResult(current: 2, longest: 2));
  });

  test('current streak is 0 when today itself has not met the goal, even '
      'if a long streak preceded it', () {
    final result = useCase.execute(
      dailyTotalsMl: {
        const LocalDate(2026, 6, 1): 2000,
        const LocalDate(2026, 6, 2): 2000,
        const LocalDate(2026, 6, 3): 500, // today, not yet met
      },
      goals: flatGoal,
      earliestDay: const LocalDate(2026, 6, 1),
      today: const LocalDate(2026, 6, 3),
    );
    expect(result.current, 0);
    expect(result.longest, 2);
  });

  test(
    'FR-W-04: a goal change mid-history does not retroactively break a '
    'past day that met the goal active on that day',
    () {
      final goals = [
        WaterGoal(
          id: 'old',
          goalMl: 2000,
          effectiveFrom: DateTime.utc(2026),
        ),
        WaterGoal(
          id: 'new',
          goalMl: 3000,
          effectiveFrom: DateTime.utc(2026, 6, 3),
        ),
      ];
      final result = useCase.execute(
        dailyTotalsMl: {
          // Met the 2000ml goal that was active on 6/1-6/2.
          const LocalDate(2026, 6, 1): 2000,
          const LocalDate(2026, 6, 2): 2200,
          // Goal raised to 3000 on 6/3; met it too.
          const LocalDate(2026, 6, 3): 3000,
        },
        goals: goals,
        earliestDay: const LocalDate(2026, 6, 1),
        today: const LocalDate(2026, 6, 3),
      );
      expect(result, const WaterStreakResult(current: 3, longest: 3));
    },
  );

  test(
    "FR-W-04: raising the goal mid-day does not break yesterday's "
    "already-completed streak day, even though yesterday's total would "
    "not meet today's new goal",
    () {
      final goals = [
        WaterGoal(
          id: 'old',
          goalMl: 2000,
          effectiveFrom: DateTime.utc(2026),
        ),
        WaterGoal(
          id: 'new',
          goalMl: 5000,
          effectiveFrom: DateTime.utc(2026, 6, 2),
        ),
      ];
      final result = useCase.execute(
        dailyTotalsMl: {
          const LocalDate(2026, 6, 1): 2000, // met the old 2000ml goal
          const LocalDate(2026, 6, 2): 1000, // today, new 5000ml goal, not met
        },
        goals: goals,
        earliestDay: const LocalDate(2026, 6, 1),
        today: const LocalDate(2026, 6, 2),
      );
      // Yesterday still counts toward "longest", today breaks "current".
      expect(result.longest, 1);
      expect(result.current, 0);
    },
  );

  test(
    'day-bucketing across a DST spring-forward feeds correctly into the '
    'streak walk: entries either side of the 1-hour skip still land on '
    "the same calendar day and combine into one day's total",
    () {
      final newYork = tz.getLocation('America/New_York');
      // 2026-03-08: US spring-forward (2am -> 3am EDT).
      final beforeJump = DateTime.utc(2026, 3, 8, 6, 30); // 1:30am EST
      final afterJump = DateTime.utc(2026, 3, 8, 7, 30); // 3:30am EDT
      final day = localDayKey(beforeJump, location: newYork);
      expect(localDayKey(afterJump, location: newYork), day);

      final result = useCase.execute(
        dailyTotalsMl: {day: 2000},
        goals: flatGoal,
        earliestDay: day,
        today: day,
      );
      expect(result, const WaterStreakResult(current: 1, longest: 1));
    },
  );
}
