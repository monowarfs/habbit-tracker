import 'package:habit_tracker/core/utils/local_date.dart';

/// A curated seasonal occasion this app acknowledges cosmetically
/// (`docs/superpowers/specs/02-delightful/
/// 12-seasonal-theme-accents-design.md`).
enum SeasonalOccasion {
  /// Pohela Boishakh (Bengali New Year), 14 April Gregorian.
  poholaBoishakh,

  /// Eid-ul-Fitr/Eid-ul-Adha — detection blocked on a Hijri date source
  /// this app doesn't have yet (see [activeSeasonalOccasion]'s doc
  /// comment); [activeSeasonalOccasion] never actually returns this.
  eid,
}

/// Pure — returns the active seasonal occasion for [today], or `null` if
/// none is active. Takes an explicit [LocalDate] rather than calling
/// `clock.now()` itself, so it's unit-testable and reusable from a
/// `Consumer` that reads the clock once per build (same convention as
/// `core/utils/greeting.dart`'s `greetingPeriodFor`).
///
/// Pohela Boishakh (14 April, Gregorian — fixed, no calendar-conversion
/// dependency needed) gets a same-day-plus-one-either-side window
/// (13-15 April inclusive).
///
/// Eid-ul-Fitr/Eid-ul-Adha need a Hijri date source this app doesn't have
/// yet — `pubspec.yaml` has no Hijri/lunar-calendar package (`adhan_dart`
/// only computes prayer times, not Gregorian↔Hijri conversion). Until
/// that prerequisite lands (shared with the separate Ramadan-mode item),
/// [SeasonalOccasion.eid] detection is dead code: this function
/// unconditionally never returns it.
SeasonalOccasion? activeSeasonalOccasion(LocalDate today) {
  if (today.month == 4 && (today.day - 14).abs() <= 1) {
    return SeasonalOccasion.poholaBoishakh;
  }
  return null;
}
