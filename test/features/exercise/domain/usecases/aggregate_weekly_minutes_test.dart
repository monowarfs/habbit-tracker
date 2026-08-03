import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/usecases/aggregate_weekly_minutes.dart';

void main() {
  const useCase = AggregateWeeklyMinutesUseCase();

  ExerciseLog logAt(DateTime loggedAt, int minutes) => ExerciseLog(
    id: 'x',
    exerciseType: 'Running',
    durationMinutes: minutes,
    loggedAt: loggedAt,
  );

  test('buckets logs into their Monday-start week', () {
    final result = useCase.execute(
      logs: [
        // Monday 2026-06-15.
        logAt(DateTime.utc(2026, 6, 15, 8), 30),
        // Sunday 2026-06-21, same week.
        logAt(DateTime.utc(2026, 6, 21, 8), 20),
        // Monday 2026-06-22, next week.
        logAt(DateTime.utc(2026, 6, 22, 8), 45),
      ],
      start: const LocalDate(2026, 6, 15),
      end: const LocalDate(2026, 6, 22),
    );

    expect(result, hasLength(2));
    expect(result[0].weekStart, const LocalDate(2026, 6, 15));
    expect(result[0].totalMinutes, 50);
    expect(result[1].weekStart, const LocalDate(2026, 6, 22));
    expect(result[1].totalMinutes, 45);
  });

  test('a week with no logged workouts still gets a zero-minute point', () {
    final result = useCase.execute(
      logs: [logAt(DateTime.utc(2026, 6, 15, 8), 30)],
      start: const LocalDate(2026, 6, 15),
      end: const LocalDate(2026, 6, 22),
    );

    expect(result, hasLength(2));
    expect(result[1].totalMinutes, 0);
  });

  test('ignores logs outside the requested range', () {
    final result = useCase.execute(
      logs: [logAt(DateTime.utc(2026, 5, 1, 8), 999)],
      start: const LocalDate(2026, 6, 15),
      end: const LocalDate(2026, 6, 15),
    );

    expect(result, hasLength(1));
    expect(result.first.totalMinutes, 0);
  });
}
