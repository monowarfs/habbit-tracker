/// True for a key like `water_streak_7`/`medicine_adherence_streak_30` —
/// every streak-milestone achievement across all three modules follows
/// this naming convention (`docs/superpowers/specs/02-delightful/
/// 02-streak-save-celebration-animation-design.md`). A module adding a
/// future streak key must keep using `_streak_` in it, same as today's 8
/// keys already do.
bool isStreakMilestoneKey(String key) => key.contains('_streak_');
