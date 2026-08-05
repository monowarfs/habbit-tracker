import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/level_curve.dart';

void main() {
  group('thresholdForLevel', () {
    test('matches the documented level table', () {
      expect(LevelCurve.thresholdForLevel(1), 0);
      expect(LevelCurve.thresholdForLevel(2), 100);
      expect(LevelCurve.thresholdForLevel(3), 300);
      expect(LevelCurve.thresholdForLevel(4), 600);
      expect(LevelCurve.thresholdForLevel(5), 1000);
    });
  });

  group('levelForXp', () {
    test('0 XP is level 1', () {
      expect(LevelCurve.levelForXp(0), 1);
    });

    test('just below a threshold stays at the lower level', () {
      expect(LevelCurve.levelForXp(99), 1);
      expect(LevelCurve.levelForXp(299), 2);
    });

    test('exactly at a threshold reaches that level', () {
      expect(LevelCurve.levelForXp(100), 2);
      expect(LevelCurve.levelForXp(300), 3);
      expect(LevelCurve.levelForXp(600), 4);
      expect(LevelCurve.levelForXp(1000), 5);
    });

    test('handles a large total without excessive iteration', () {
      // 100 * 141 * 140 / 2 = 987,000 <= 1,000,000 < 100*142*141/2.
      expect(LevelCurve.levelForXp(1000000), 141);
    });
  });

  group('xpInCurrentLevel', () {
    test('is 0 right at a level boundary', () {
      expect(LevelCurve.xpInCurrentLevel(100), 0);
    });

    test('accumulates within a level', () {
      expect(LevelCurve.xpInCurrentLevel(150), 50);
      expect(LevelCurve.xpInCurrentLevel(299), 199);
    });
  });

  group('xpToNextLevel', () {
    test('is the full level span right at a boundary', () {
      // Level 2 -> 3 spans 300 - 100 = 200 XP.
      expect(LevelCurve.xpToNextLevel(100), 200);
    });

    test('decreases as XP accumulates within a level', () {
      expect(LevelCurve.xpToNextLevel(150), 150);
      expect(LevelCurve.xpToNextLevel(299), 1);
    });

    test('xpInCurrentLevel + xpToNextLevel spans exactly one level', () {
      for (final xp in [0, 50, 150, 500, 999]) {
        final level = LevelCurve.levelForXp(xp);
        final span =
            LevelCurve.thresholdForLevel(level + 1) -
            LevelCurve.thresholdForLevel(level);
        expect(
          LevelCurve.xpInCurrentLevel(xp) + LevelCurve.xpToNextLevel(xp),
          span,
        );
      }
    });
  });
}
