/// Quadratic level curve: each level requires more XP than the last.
/// Level 1 = 0 XP, Level 2 = 100 XP, Level 3 = 300 XP, Level 4 = 600 XP,
/// Level 5 = 1,000 XP, ... `threshold(L) = 100 * L * (L - 1) / 2`.
class LevelCurve {
  const LevelCurve._();

  /// The XP threshold at which [level] is reached. Levels start at 1.
  static int thresholdForLevel(int level) => 100 * level * (level - 1) ~/ 2;

  /// The level [totalXp] currently sits at — the largest level whose
  /// threshold [totalXp] has reached or passed. Walks upward from level 1
  /// rather than solving the quadratic directly: levels grow quadratically,
  /// so even a very large [totalXp] only takes a small number of steps
  /// (e.g. ~140 steps for 1,000,000 XP), and this avoids floating-point
  /// rounding at a level boundary that a closed-form sqrt solution risks.
  static int levelForXp(int totalXp) {
    var level = 1;
    while (thresholdForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  /// XP earned within the current level, `[0, thresholdForLevel(level +
  /// 1) - thresholdForLevel(level))`.
  static int xpInCurrentLevel(int totalXp) {
    return totalXp - thresholdForLevel(levelForXp(totalXp));
  }

  /// XP still needed to reach the next level.
  static int xpToNextLevel(int totalXp) {
    final level = levelForXp(totalXp);
    return thresholdForLevel(level + 1) - totalXp;
  }
}
