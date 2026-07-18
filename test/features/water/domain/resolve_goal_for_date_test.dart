import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';

void main() {
  const useCase = ResolveGoalForDateUseCase();

  final goal2000 = WaterGoal(
    id: 'g1',
    goalMl: 2000,
    effectiveFrom: DateTime.utc(2026),
  );
  final goal2500 = WaterGoal(
    id: 'g2',
    goalMl: 2500,
    effectiveFrom: DateTime.utc(2026, 6, 15),
  );
  final goals = [goal2500, goal2000]; // deliberately unsorted

  test('resolves the goal effective as of a date between two changes', () {
    final result = useCase.execute(goals, const LocalDate(2026, 3, 1));
    expect(result, goal2000);
  });

  test('resolves the latest goal once its effective date has passed', () {
    final result = useCase.execute(goals, const LocalDate(2026, 7, 1));
    expect(result, goal2500);
  });

  test('resolves exactly on the effective date itself (inclusive)', () {
    final result = useCase.execute(goals, const LocalDate(2026, 6, 15));
    expect(result, goal2500);
  });

  test(
    'a date before every goal falls back to the earliest goal (FR-W-04: '
    'no goal ever changes what a past day already showed)',
    () {
      final result = useCase.execute(goals, const LocalDate(2020, 1, 1));
      expect(result, goal2000);
    },
  );

  test('a single goal applies to every date', () {
    final result = useCase.execute([goal2000], const LocalDate(2030, 1, 1));
    expect(result, goal2000);
  });
}
