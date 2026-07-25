import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/goal_attainment_use_case.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

ModuleDayStatus _s(ModuleDayStatusKind kind) =>
    ModuleDayStatus(kind: kind, value: 0);

void main() {
  final useCase = GoalAttainmentUseCase();

  test('counts complete days against total active days', () {
    final map = {
      const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
      const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.complete),
      const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.missed),
      const LocalDate(2026, 6, 4): _s(ModuleDayStatusKind.partial),
    };
    final result = useCase.calculate(dayStatus: map);
    expect(result.metDays, 2);
    expect(result.totalDays, 4);
    expect(result.rate, 0.5);
  });

  test('excludes no-data days from the denominator', () {
    final map = {
      const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
      const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.none),
      const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.none),
    };
    final result = useCase.calculate(dayStatus: map);
    expect(result.metDays, 1);
    expect(result.totalDays, 1);
    expect(result.rate, 1.0);
  });

  test('excludes paused days from the denominator, same as no-data days', () {
    final map = {
      const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
      const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.missed),
      const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.paused),
      const LocalDate(2026, 6, 4): _s(ModuleDayStatusKind.paused),
    };
    final result = useCase.calculate(dayStatus: map);
    expect(result.metDays, 1);
    expect(result.totalDays, 2);
    expect(result.rate, 0.5);
  });

  test('zero denominator (all no-data, or empty map) yields rate 0', () {
    final allNoData = {
      const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.none),
    };
    expect(useCase.calculate(dayStatus: allNoData).rate, 0);
    expect(useCase.calculate(dayStatus: allNoData).totalDays, 0);

    final result = useCase.calculate(dayStatus: const {});
    expect(result.totalDays, 0);
    expect(result.metDays, 0);
    expect(result.rate, 0);
  });
}
