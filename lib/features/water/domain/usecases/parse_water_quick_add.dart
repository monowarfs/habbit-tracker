import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/domain/entities/parsed_water_entry.dart';

final _justNowPattern = RegExp(
  r'\b(just now|right now|now)\b',
  caseSensitive: false,
);
final _minutesAgoPattern = RegExp(
  r'\b(\d+)\s*(?:min|minutes?)\s*ago\b',
  caseSensitive: false,
);
final _hoursAgoPattern = RegExp(
  r'\b(\d+)\s*(?:hr|hours?)\s*ago\b',
  caseSensitive: false,
);
final _daysAgoPattern = RegExp(
  r'\b(\d+)\s*days?\s*ago\b',
  caseSensitive: false,
);
final _atTimePattern = RegExp(
  r'\bat\s*(\d{1,2}):?(\d{2})?\s*(am|pm)?\b',
  caseSensitive: false,
);

final _amountUnitPattern = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*'
  r'(fluid\s*ounces?|fl\.?\s*oz|milliliters?|millilitres?|mil|ml|'
  r'liters?|litres?|l|cups?|glass(?:es)?|oz)?\b',
  caseSensitive: false,
);

/// Parses free-form natural-language water-intake text into a candidate
/// log entry (`docs/superpowers/plans/ai-powered/
/// 02-natural-language-quick-add-impl-plan.md`). Pure and synchronous — no
/// I/O, no clock reads; `now` is always supplied by the caller.
class ParseWaterQuickAddUseCase {
  /// Creates the parser.
  const ParseWaterQuickAddUseCase();

  /// Parses [rawText] as of [now]. [waterUnit] controls how a bare number
  /// (no unit word attached) is interpreted — `ml` by default, `flOz` when
  /// the user has set that display preference.
  ParsedWaterEntry execute({
    required String rawText,
    required DateTime now,
    WaterUnit waterUnit = WaterUnit.ml,
  }) {
    final (loggedAt, hasExplicitTimePhrase, textWithoutTime) = _extractTime(
      rawText,
      now,
    );
    final amountMl = _extractAmountMl(textWithoutTime, waterUnit);

    final confidence = amountMl == null
        ? 'low'
        : (hasExplicitTimePhrase ? 'high' : 'medium');

    return ParsedWaterEntry(
      amountMl: amountMl,
      loggedAt: amountMl == null ? null : loggedAt,
      confidence: confidence,
      rawText: rawText,
    );
  }

  (DateTime loggedAt, bool hasExplicitTimePhrase, String remainingText)
  _extractTime(String text, DateTime now) {
    final justNow = _justNowPattern.firstMatch(text);
    if (justNow != null) {
      return (now, true, text.replaceRange(justNow.start, justNow.end, ''));
    }

    final minutesAgo = _minutesAgoPattern.firstMatch(text);
    if (minutesAgo != null) {
      final minutes = int.parse(minutesAgo.group(1)!);
      return (
        now.subtract(Duration(minutes: minutes)),
        true,
        text.replaceRange(minutesAgo.start, minutesAgo.end, ''),
      );
    }

    final hoursAgo = _hoursAgoPattern.firstMatch(text);
    if (hoursAgo != null) {
      final hours = int.parse(hoursAgo.group(1)!);
      return (
        now.subtract(Duration(hours: hours)),
        true,
        text.replaceRange(hoursAgo.start, hoursAgo.end, ''),
      );
    }

    final daysAgo = _daysAgoPattern.firstMatch(text);
    if (daysAgo != null) {
      final days = int.parse(daysAgo.group(1)!);
      return (
        now.subtract(Duration(days: days)),
        true,
        text.replaceRange(daysAgo.start, daysAgo.end, ''),
      );
    }

    final atTime = _atTimePattern.firstMatch(text);
    if (atTime != null) {
      var hour = int.parse(atTime.group(1)!);
      final minute = int.parse(atTime.group(2) ?? '0');
      final meridiem = atTime.group(3)?.toLowerCase();
      if (meridiem == 'pm' && hour != 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      var candidate = DateTime(now.year, now.month, now.day, hour, minute);
      if (candidate.isAfter(now)) {
        candidate = candidate.subtract(const Duration(days: 1));
      }
      return (
        candidate,
        true,
        text.replaceRange(atTime.start, atTime.end, ''),
      );
    }

    return (now, false, text);
  }

  int? _extractAmountMl(String text, WaterUnit waterUnit) {
    final matches = _amountUnitPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    final withUnit = matches.where((m) => m.group(2) != null).toList();
    if (withUnit.isEmpty && matches.length > 1) {
      // Multiple bare numbers, no unit to disambiguate which one is the
      // amount.
      return null;
    }

    final match = withUnit.isNotEmpty ? withUnit.first : matches.first;
    final value = double.parse(match.group(1)!.replaceAll(',', '.'));
    return (value * _multiplierForUnit(match.group(2), waterUnit)).round();
  }

  double _multiplierForUnit(String? rawUnit, WaterUnit waterUnit) {
    if (rawUnit == null) {
      // Bare number: interpreted in whatever unit the user displays
      // amounts in.
      return waterUnit == WaterUnit.flOz ? 29.5735 : 1;
    }
    final unit = rawUnit
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (unit.startsWith('fl') || unit.startsWith('fluid') || unit == 'oz') {
      return 29.5735;
    }
    if (unit.startsWith('cup')) return 240;
    if (unit.startsWith('glass')) return 250;
    if (unit.startsWith('liter') || unit.startsWith('litre') || unit == 'l') {
      return 1000;
    }
    // 'ml', 'mil', 'milliliter(s)', 'millilitre(s)'.
    return 1;
  }
}
