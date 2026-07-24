/// Time-of-day bucket for the dashboard greeting
/// (`docs/superpowers/specs/02-delightful/
/// 11-personalized-dashboard-greeting-design.md`). Boundaries: morning
/// 05:00-11:59, afternoon 12:00-16:59, evening 17:00-20:59, night
/// 21:00-04:59.
enum GreetingPeriod {
  /// 05:00-11:59.
  morning,

  /// 12:00-16:59.
  afternoon,

  /// 17:00-20:59.
  evening,

  /// 21:00-04:59.
  night,
}

/// Pure — takes [now] explicitly rather than calling `clock.now()`
/// itself, so it's unit-testable without `withClock` and reusable from a
/// `Consumer` build method that reads the clock once per build.
GreetingPeriod greetingPeriodFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return GreetingPeriod.morning;
  if (hour >= 12 && hour < 17) return GreetingPeriod.afternoon;
  if (hour >= 17 && hour < 21) return GreetingPeriod.evening;
  return GreetingPeriod.night;
}
