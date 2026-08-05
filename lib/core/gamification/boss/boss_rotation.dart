/// Modules that take a turn in the boss spotlight, in rotation order.
const bossRotationModules = ['water', 'medicine', 'prayer'];

/// Deterministically picks which module gets the boss spotlight for the
/// ISO week identified by [weekKey] — every device computes the same
/// answer for the same week with no shared state. `.hashCode.abs()`
/// (not the raw hash) since `String.hashCode` isn't documented as
/// non-negative.
String bossModuleForWeek(String weekKey) {
  final index = weekKey.hashCode.abs() % bossRotationModules.length;
  return bossRotationModules[index];
}
