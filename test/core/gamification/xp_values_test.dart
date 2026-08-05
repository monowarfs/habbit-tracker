import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';

void main() {
  test(
    'per-module action/day-complete combinations return expected values',
    () {
      expect(XpValues.forEvent('water', 'action'), XpValues.waterAction);
      expect(
        XpValues.forEvent('water', 'day_complete'),
        XpValues.waterDayComplete,
      );
      expect(XpValues.forEvent('medicine', 'action'), XpValues.medicineAction);
      expect(
        XpValues.forEvent('medicine', 'day_complete'),
        XpValues.medicineDayComplete,
      );
      expect(XpValues.forEvent('prayer', 'action'), XpValues.prayerAction);
      expect(
        XpValues.forEvent('prayer', 'day_complete'),
        XpValues.prayerDayComplete,
      );
    },
  );

  test('cross-module event types ignore moduleId', () {
    for (final moduleId in ['water', 'medicine', 'prayer', 'system']) {
      expect(
        XpValues.forEvent(moduleId, 'streak_milestone'),
        XpValues.streakMilestone,
      );
      expect(
        XpValues.forEvent(moduleId, 'combo_bonus'),
        XpValues.comboBonus,
      );
      expect(
        XpValues.forEvent(moduleId, 'weekly_quest_complete'),
        XpValues.weeklyQuestComplete,
      );
      expect(
        XpValues.forEvent(moduleId, 'boss_cleared'),
        XpValues.bossCleared,
      );
    }
  });

  test('an unrecognized combination is worth 0 XP', () {
    expect(XpValues.forEvent('water', 'nonexistent'), 0);
    expect(XpValues.forEvent('sleep', 'action'), 0);
  });

  test('medicine earns less per action than water (more daily actions)', () {
    expect(XpValues.medicineAction, lessThan(XpValues.waterAction));
  });
}
