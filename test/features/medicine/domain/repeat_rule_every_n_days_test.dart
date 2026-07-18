import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';

void main() {
  test(
    'every-other-day anchoring never drifts across a 14-day window that '
    'includes a DST transition date (US spring-forward, 2026-03-08)',
    () {
      // Anchor Monday 2026-03-02: dose days are day 0, 2, 4, ... i.e.
      // 3/2, 3/4, 3/6, 3/8, 3/10, 3/12, 3/14 (7 doses across 14 days).
      const anchor = LocalDate(2026, 3, 2);
      final result = expandRepeatRule(
        rule: const RepeatRule.everyNDays(
          intervalDays: 2,
          timesOfDay: [LocalTime(8, 0)],
        ),
        anchor: anchor,
        rangeStart: anchor,
        rangeEnd: const LocalDate(2026, 3, 15),
      );

      final doseDays = result.map(LocalDate.fromDateTime).toSet();
      expect(doseDays, {
        const LocalDate(2026, 3, 2),
        const LocalDate(2026, 3, 4),
        const LocalDate(2026, 3, 6),
        const LocalDate(2026, 3, 8), // the DST date itself — still a dose day
        const LocalDate(2026, 3, 10),
        const LocalDate(2026, 3, 12),
        const LocalDate(2026, 3, 14),
      });
      // The DST date is a dose day, not skipped/duplicated by the transition.
      const dstDate = LocalDate(2026, 3, 8);
      expect(
        result.where((d) => LocalDate.fromDateTime(d) == dstDate),
        hasLength(1),
      );
    },
  );

  test('intervalDays: 3 lands on every third day, unaffected by DST', () {
    const anchor = LocalDate(2026, 3, 1);
    final result = expandRepeatRule(
      rule: const RepeatRule.everyNDays(
        intervalDays: 3,
        timesOfDay: [LocalTime(7, 30)],
      ),
      anchor: anchor,
      rangeStart: anchor,
      rangeEnd: const LocalDate(2026, 3, 10),
    );
    final doseDays = result.map(LocalDate.fromDateTime).toList();
    expect(doseDays, [
      const LocalDate(2026, 3, 1),
      const LocalDate(2026, 3, 4),
      const LocalDate(2026, 3, 7),
      const LocalDate(2026, 3, 10),
    ]);
  });

  test('editing the anchor (startDate) re-anchors the whole pattern', () {
    const originalAnchor = LocalDate(2026, 3, 2);
    const newAnchor = LocalDate(2026, 3, 3); // shifted by 1 day
    final result = expandRepeatRule(
      rule: const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(8, 0)],
      ),
      anchor: newAnchor,
      rangeStart: newAnchor,
      rangeEnd: const LocalDate(2026, 3, 9),
    );
    final doseDays = result.map(LocalDate.fromDateTime).toSet();
    // Dose days now fall on the *odd* offset from the original pattern.
    expect(doseDays, {
      const LocalDate(2026, 3, 3),
      const LocalDate(2026, 3, 5),
      const LocalDate(2026, 3, 7),
      const LocalDate(2026, 3, 9),
    });
    expect(doseDays.contains(originalAnchor), isFalse);
  });
}
