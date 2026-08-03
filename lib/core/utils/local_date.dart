import 'package:meta/meta.dart';

/// A calendar date with no time-of-day or timezone attached (D-14) — used
/// wherever a value is semantically a local calendar-day bucket (e.g.
/// `prayer_date`), so nothing can accidentally attach an instant/timezone
/// to what is meant to be a plain "which day is this" key
/// (`../technical/database-design.md`).
@immutable
class LocalDate implements Comparable<LocalDate> {
  /// Creates a local date from its calendar components.
  const LocalDate(this.year, this.month, this.day);

  /// Extracts the calendar date from [dateTime], ignoring its time and
  /// timezone.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Parses an ISO-8601 date string (`"YYYY-MM-DD"`).
  factory LocalDate.parse(String iso) {
    final parts = iso.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// The calendar year.
  final int year;

  /// The calendar month, 1-12.
  final int month;

  /// The calendar day of month.
  final int day;

  /// Formats as `"YYYY-MM-DD"`, the DB/JSON wire format.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// This calendar date as midnight UTC — a lossless round trip for pure
  /// calendar-day arithmetic (e.g. stepping day by day via `add`), never
  /// meant to represent a real instant.
  DateTime toDateTimeUtc() => DateTime.utc(year, month, day);

  /// The following calendar day.
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(toDateTimeUtc().add(Duration(days: days)));

  /// This date shifted by [months] calendar months, day held fixed.
  /// Round-trips through [DateTime]'s own month-overflow normalization
  /// (`DateTime(year, 0, day)` resolves to December of the previous
  /// year, `DateTime(year, 13, day)` to January of the next) — the
  /// constructor's raw fields are never used directly as a comparison
  /// or lookup key without this normalization, unlike a bare
  /// `LocalDate(year, month - 1, 1)` at a call site, which silently
  /// produces an invalid `month: 0` that every later `dayStatus`/`toIso`
  /// lookup then misses against (caught in PR review — a "previous
  /// month" chevron from January produced a dead history screen).
  LocalDate addMonths(int months) =>
      LocalDate.fromDateTime(DateTime.utc(year, month + months, day));

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// The Monday that starts [day]'s ISO week (Monday=1..Sunday=7) — the one
/// shared week-bucketing formula for period charts (Reports' week view,
/// per-module weekly-total charts), so every caller snaps to the same
/// week boundary instead of each re-deriving it.
LocalDate weekStartFor(LocalDate day) {
  final weekday = day.toDateTimeUtc().weekday;
  return day.addDays(-(weekday - 1));
}

/// A local wall-clock time-of-day with no date or timezone attached (D-14)
/// — used for recurring schedule times (e.g. `times_of_day`).
@immutable
class LocalTime implements Comparable<LocalTime> {
  /// Creates a local time from its hour/minute components.
  const LocalTime(this.hour, this.minute);

  /// Parses a `"HH:mm"` string.
  factory LocalTime.parse(String hhMm) {
    final parts = hhMm.split(':');
    return LocalTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Hour of day, 0-23.
  final int hour;

  /// Minute of hour, 0-59.
  final int minute;

  /// Formats as `"HH:mm"`, the DB wire format.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalTime other) {
    if (hour != other.hour) return hour.compareTo(other.hour);
    return minute.compareTo(other.minute);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}
