import 'package:flutter/widgets.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/domain/water_unit_conversion.dart';
import 'package:intl/intl.dart';

/// Converts [amountMl] to the display unit (display-only — storage always
/// stays canonical ml, D-01/FR-W-02).
int waterDisplayValue(int amountMl, WaterUnit unit) =>
    unit == WaterUnit.ml ? amountMl : (amountMl / mlPerFlOz).round();

/// The unit abbreviation shown next to a formatted amount.
String waterUnitLabel(WaterUnit unit) => unit == WaterUnit.ml ? 'ml' : 'fl oz';

/// Formats a unit-converted numeral through `package:intl` so Bangla
/// numerals render correctly (`strategies/localization.md`'s
/// digit-rendering rule) rather than interpolating the raw `int` — use
/// this (not string interpolation) for every number shown to the user,
/// including standalone numbers like the progress ring's big total.
String formatWaterNumber(BuildContext context, int amountMl, WaterUnit unit) {
  final locale = Localizations.localeOf(context).toString();
  return NumberFormat.decimalPattern(
    locale,
  ).format(waterDisplayValue(amountMl, unit));
}

/// [formatWaterNumber] plus the unit label, e.g. "250 ml" / "৮ fl oz".
String formatWaterAmount(BuildContext context, int amountMl, WaterUnit unit) {
  final number = formatWaterNumber(context, amountMl, unit);
  return '$number ${waterUnitLabel(unit)}';
}

/// Formats [dateTime] (a UTC instant) as a locale-aware, device-local
/// time-of-day string (e.g. "8:32 AM"), per `package:intl`'s
/// `DateFormat`, never manual date-string building.
String formatWaterLogTime(BuildContext context, DateTime dateTime) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.jm(locale).format(dateTime.toLocal());
}
