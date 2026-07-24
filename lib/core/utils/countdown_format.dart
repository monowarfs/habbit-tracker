/// Formats [remaining] as a short countdown string ("42 min" / "2h 15m"),
/// for the Sehri/Iftar countdown chip (`docs/superpowers/specs/
/// 02-delightful/01-ramadan-mode-design.md`). Callers must only pass a
/// positive [remaining] — this doesn't special-case zero/negative
/// durations, since every call site already guards on
/// `!remaining.isNegative` before calling.
String formatCountdown(Duration remaining) {
  final totalMinutes = remaining.inMinutes;
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}
