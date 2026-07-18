import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';

void main() {
  group('fixedDaily', () {
    test('generates both times every day in range', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.fixedDaily(
          timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
        ),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 3),
      );
      expect(result, hasLength(6)); // 3 days x 2 times
      expect(
        result.first,
        DateTime(2026, 6, 1, 8).toUtc(),
      );
      expect(
        result.last,
        DateTime(2026, 6, 3, 20).toUtc(),
      );
    });

    test('never generates before the anchor', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        anchor: const LocalDate(2026, 6, 5),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 5),
      );
      expect(result, hasLength(1));
      expect(result.single, DateTime(2026, 6, 5, 8).toUtc());
    });
  });

  group('weekdaySet', () {
    test('only generates on masked weekdays', () {
      // Mon=1, Wed=4 -> mask 1|4=5. 2026-06-01 is a Monday.
      final result = expandRepeatRule(
        rule: const RepeatRule.weekdaySet(
          weekdaysMask: 5,
          timesOfDay: [LocalTime(9, 0)],
        ),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 7),
      );
      // Mon 6/1 and Wed 6/3 only.
      expect(result, hasLength(2));
      expect(result[0], DateTime(2026, 6, 1, 9).toUtc());
      expect(result[1], DateTime(2026, 6, 3, 9).toUtc());
    });
  });

  group('prn', () {
    test('never generates any instance', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.prn(),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 30),
      );
      expect(result, isEmpty);
    });
  });

  test('rangeEnd before rangeStart returns empty, not an error', () {
    final result = expandRepeatRule(
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      anchor: const LocalDate(2026, 6, 1),
      rangeStart: const LocalDate(2026, 6, 10),
      rangeEnd: const LocalDate(2026, 6, 5),
    );
    expect(result, isEmpty);
  });
}
