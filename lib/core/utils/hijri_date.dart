import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:hijri/hijri_calendar.dart';

/// Ramadan is Hijri month 9.
const _ramadanHijriMonth = 9;

/// Whether [gregorianDate] falls within Ramadan (Hijri month 9), per the
/// Umm al-Qura calendar `package:hijri` implements
/// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`).
/// Pure, deterministic, no I/O — safe to call from `pendingNotifications()`.
///
/// Umm al-Qura is a *calculated* calendar, not local moon-sighting — good
/// enough for reminder scheduling (off by at most a day around the
/// boundary, self-correcting the next day), not good enough to claim
/// liturgical authority; [resolveRamadanModeActive]'s manual-override
/// escape hatch exists precisely because of this.
bool isRamadan(LocalDate gregorianDate) =>
    HijriCalendar.fromDate(gregorianDate.toDateTimeUtc()).hMonth ==
    _ramadanHijriMonth;

/// The Hijri day-of-Ramadan (1-30) for [gregorianDate], or `null` if it
/// isn't in Ramadan.
int? ramadanDayNumber(LocalDate gregorianDate) {
  final hijri = HijriCalendar.fromDate(gregorianDate.toDateTimeUtc());
  return hijri.hMonth == _ramadanHijriMonth ? hijri.hDay : null;
}

/// The effective Ramadan-mode state for [today]: [manualOverride] wins if
/// set (`true`/`false`); otherwise falls back to [isRamadan] when
/// [autoDetectEnabled], else always `false`.
bool resolveRamadanModeActive({
  required bool? manualOverride,
  required bool autoDetectEnabled,
  required LocalDate today,
}) {
  if (manualOverride != null) return manualOverride;
  if (!autoDetectEnabled) return false;
  return isRamadan(today);
}
