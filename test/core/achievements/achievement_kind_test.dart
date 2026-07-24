import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';

void main() {
  // Every real streak-milestone key across all three modules today
  // (`WaterModule`/`MedicineModule`/`PrayerModule.achievementDefinitions`
  // — grepped for the source design doc, re-verified directly against
  // the current `lib/features/*/*.dart` definitions while writing this
  // plan).
  const streakKeys = [
    'water_streak_7',
    'water_streak_30',
    'water_streak_100',
    'medicine_adherence_streak_7',
    'medicine_adherence_streak_30',
    'prayer_streak_7',
    'prayer_streak_30',
    'prayer_streak_100',
  ];

  // Every real non-streak key today.
  const nonStreakKeys = [
    'water_first_log',
    'water_perfect_week',
    'medicine_first_dose',
    'prayer_first_log',
    'prayer_perfect_week',
  ];

  for (final key in streakKeys) {
    test('$key is a streak milestone', () {
      expect(isStreakMilestoneKey(key), isTrue);
    });
  }

  for (final key in nonStreakKeys) {
    test('$key is not a streak milestone', () {
      expect(isStreakMilestoneKey(key), isFalse);
    });
  }

  test('a key with no _streak_ substring at all is never a match', () {
    expect(isStreakMilestoneKey('totally_unrelated_key'), isFalse);
  });
}
