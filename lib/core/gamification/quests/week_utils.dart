import 'package:habit_tracker/core/utils/local_date.dart';

/// The Monday that starts [date]'s week — an alias for the shared
/// [weekStartFor] so quest code reads in domain terms.
LocalDate mondayOfWeek(LocalDate date) => weekStartFor(date);

/// Returns the ISO 8601 week key (`'YYYY-Www'`) for [date]'s week.
///
/// ISO weeks are timezone-agnostic once [date] is already a local calendar
/// day (callers pass `localDayKey()`'s result for DST safety) — January 4th
/// always falls in week 1 of its ISO year, so that anchor plus a day-count
/// from its own Monday gives the week number without a lookup table.
String weekKeyForDate(LocalDate date) {
  final monday = mondayOfWeek(date);
  // The ISO week-numbering year is whichever year contains this week's
  // Thursday.
  final isoYear = monday.addDays(3).year;
  final week1Monday = mondayOfWeek(LocalDate(isoYear, 1, 4));
  final weeksSinceWeek1 =
      monday.toDateTimeUtc().difference(week1Monday.toDateTimeUtc()).inDays ~/
      7;
  return '$isoYear-W${(weeksSinceWeek1 + 1).toString().padLeft(2, '0')}';
}

/// Whether [date] falls in the ISO week identified by [weekKey].
bool isInWeek(LocalDate date, String weekKey) =>
    weekKeyForDate(date) == weekKey;
