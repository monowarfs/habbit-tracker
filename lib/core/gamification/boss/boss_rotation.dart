/// Modules that take a turn in the boss spotlight, in rotation order.
const bossRotationModules = ['water', 'medicine', 'prayer'];

/// Deterministically picks which module gets the boss spotlight for the
/// ISO week identified by [weekKey] (`'YYYY-Www'`, `week_utils.dart`'s
/// `weekKeyForDate` format) — every device/platform computes the same
/// answer for the same week with no shared state. Parses the week number
/// out of [weekKey] rather than hashing the string: `String.hashCode`
/// isn't guaranteed identical across Dart runtimes (VM vs. web
/// dart2js/DDC), so two platforms could otherwise spotlight different
/// modules for the same week (PR #78 review finding).
String bossModuleForWeek(String weekKey) {
  final weekNumber = int.parse(weekKey.split('W').last);
  return bossRotationModules[weekNumber % bossRotationModules.length];
}
