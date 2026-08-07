import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/consistency_score_calculator.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

ModuleDayStatus _s(ModuleDayStatusKind kind) =>
    ModuleDayStatus(kind: kind, value: 0);

void main() {
  test('empty module map yields 0', () {
    expect(ConsistencyScoreCalculator.calculate(moduleStatuses: const {}), 0);
  });

  test('single module reduces to that module\'s own raw percentage', () {
    final complete = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {'water': _s(ModuleDayStatusKind.complete)},
    );
    expect(complete, 100);

    final partial = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {'medicine': _s(ModuleDayStatusKind.partial)},
    );
    expect(partial, 50);

    final missed = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {'prayer': _s(ModuleDayStatusKind.missed)},
    );
    expect(missed, 0);
  });

  test('none and paused both score as 0, same as missed', () {
    expect(
      ConsistencyScoreCalculator.calculate(
        moduleStatuses: {'water': _s(ModuleDayStatusKind.none)},
      ),
      0,
    );
    expect(
      ConsistencyScoreCalculator.calculate(
        moduleStatuses: {'water': _s(ModuleDayStatusKind.paused)},
      ),
      0,
    );
  });

  test('blends multiple modules using the default weights', () {
    // water(1.0)=complete(1.0), medicine(1.5)=complete(1.0),
    // prayer(1.2)=missed(0.0)
    // -> (1.0*1.0 + 1.0*1.5 + 0.0*1.2) / (1.0+1.5+1.2) = 2.5/3.7 = 0.6757
    final score = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {
        'water': _s(ModuleDayStatusKind.complete),
        'medicine': _s(ModuleDayStatusKind.complete),
        'prayer': _s(ModuleDayStatusKind.missed),
      },
    );
    expect(score, 68);
  });

  test('a module id absent from the weights map defaults to weight 1.0', () {
    final score = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {
        'water': _s(ModuleDayStatusKind.complete),
        'sleep': _s(ModuleDayStatusKind.missed),
      },
    );
    // (1.0*1.0 + 0.0*1.0) / 2.0 = 0.5
    expect(score, 50);
  });

  test('custom weights override the built-in defaults entirely', () {
    final score = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {
        'water': _s(ModuleDayStatusKind.complete),
        'medicine': _s(ModuleDayStatusKind.missed),
      },
      weights: {'water': 2.0, 'medicine': 2.0},
    );
    // Equal weights -> plain average -> 50.
    expect(score, 50);
  });

  test('result is always clamped to 0-100', () {
    final score = ConsistencyScoreCalculator.calculate(
      moduleStatuses: {'water': _s(ModuleDayStatusKind.complete)},
    );
    expect(score, inInclusiveRange(0, 100));
  });
}
