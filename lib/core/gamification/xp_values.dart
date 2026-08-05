/// XP awarded per action type per module, designed so all three modules
/// contribute roughly equally over a week (a module logging more actions
/// per day is worth less per action).
class XpValues {
  const XpValues._();

  // Water: ~3 actions/day (quick-add, full log) x 7 = ~21 actions/week.
  /// Per water log entry.
  static const waterAction = 5;

  /// Full day's water goal met.
  static const waterDayComplete = 15;

  // Medicine: ~2-4 doses/day x 7 = 14-28 doses/week.
  /// Per dose marked done.
  static const medicineAction = 3;

  /// All doses taken in a day.
  static const medicineDayComplete = 10;

  // Prayer: 5 prayers/day x 7 = 35 prayers/week.
  /// Per prayer checked off.
  static const prayerAction = 2;

  /// All 5 prayers done in a day.
  static const prayerDayComplete = 10;

  /// Any streak-length achievement unlock, any module.
  static const streakMilestone = 25;

  /// All modules complete the same day (06-gamification/06).
  static const comboBonus = 30;

  /// A weekly quest's reward claimed (06-gamification/04).
  static const weeklyQuestComplete = 50;

  /// A boss challenge's reward claimed (06-gamification/09).
  static const bossCleared = 100;

  /// The XP a [moduleId]/[eventType] combination is worth, or 0 for an
  /// unrecognized combination (never awarded — callers should only ever
  /// pass a pairing this recognizes).
  static int forEvent(String moduleId, String eventType) {
    return switch ((moduleId, eventType)) {
      ('water', 'action') => waterAction,
      ('water', 'day_complete') => waterDayComplete,
      ('medicine', 'action') => medicineAction,
      ('medicine', 'day_complete') => medicineDayComplete,
      ('prayer', 'action') => prayerAction,
      ('prayer', 'day_complete') => prayerDayComplete,
      (_, 'streak_milestone') => streakMilestone,
      (_, 'combo_bonus') => comboBonus,
      (_, 'weekly_quest_complete') => weeklyQuestComplete,
      (_, 'boss_cleared') => bossCleared,
      (_, _) => 0,
    };
  }
}
