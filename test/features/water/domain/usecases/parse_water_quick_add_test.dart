import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/domain/usecases/parse_water_quick_add.dart';

void main() {
  const parser = ParseWaterQuickAddUseCase();
  final now = DateTime(2026, 6, 15, 20);

  test('"2 glasses just now" -> 500ml, now, high', () {
    final result = parser.execute(rawText: '2 glasses just now', now: now);
    expect(result.amountMl, 500);
    expect(result.loggedAt, now);
    expect(result.confidence, 'high');
  });

  test('"500ml at 3pm" -> 500ml, today 15:00, high', () {
    final result = parser.execute(rawText: '500ml at 3pm', now: now);
    expect(result.amountMl, 500);
    expect(result.loggedAt, DateTime(2026, 6, 15, 15));
    expect(result.confidence, 'high');
  });

  test('"1 cup" -> 240ml, now, medium', () {
    final result = parser.execute(rawText: '1 cup', now: now);
    expect(result.amountMl, 240);
    expect(result.loggedAt, now);
    expect(result.confidence, 'medium');
  });

  test('"2L" -> 2000ml, now, medium', () {
    final result = parser.execute(rawText: '2L', now: now);
    expect(result.amountMl, 2000);
    expect(result.loggedAt, now);
    expect(result.confidence, 'medium');
  });

  test('"300ml 20 minutes ago" -> 300ml, now-20min, high', () {
    final result = parser.execute(rawText: '300ml 20 minutes ago', now: now);
    expect(result.amountMl, 300);
    expect(result.loggedAt, now.subtract(const Duration(minutes: 20)));
    expect(result.confidence, 'high');
  });

  test('"just now" -> null amount, low', () {
    final result = parser.execute(rawText: 'just now', now: now);
    expect(result.amountMl, isNull);
    expect(result.loggedAt, isNull);
    expect(result.confidence, 'low');
  });

  test('"abc" -> null amount, null time, low', () {
    final result = parser.execute(rawText: 'abc', now: now);
    expect(result.amountMl, isNull);
    expect(result.loggedAt, isNull);
    expect(result.confidence, 'low');
  });

  test('"2,5 glasses" (European decimal) -> 625ml, medium', () {
    final result = parser.execute(rawText: '2,5 glasses', now: now);
    expect(result.amountMl, 625);
    expect(result.confidence, 'medium');
  });

  test('"8 oz" -> ~237ml, medium', () {
    final result = parser.execute(rawText: '8 oz', now: now);
    expect(result.amountMl, 237);
    expect(result.confidence, 'medium');
  });

  test('"1 liter 2 hours ago" -> 1000ml, now-2h, high', () {
    final result = parser.execute(rawText: '1 liter 2 hours ago', now: now);
    expect(result.amountMl, 1000);
    expect(result.loggedAt, now.subtract(const Duration(hours: 2)));
    expect(result.confidence, 'high');
  });

  test('bare number under WaterUnit.flOz is interpreted as fl oz', () {
    final result = parser.execute(
      rawText: '8',
      now: now,
      waterUnit: WaterUnit.flOz,
    );
    expect(result.amountMl, 237);
    expect(result.confidence, 'medium');
  });

  test('bare number under the default WaterUnit.ml is interpreted as ml', () {
    final result = parser.execute(rawText: '8', now: now);
    expect(result.amountMl, 8);
  });

  test('multiple bare numbers with no unit is ambiguous -> low', () {
    final result = parser.execute(rawText: '2 3 4', now: now);
    expect(result.amountMl, isNull);
    expect(result.confidence, 'low');
  });

  test('"just now" with an amount is still high confidence', () {
    final result = parser.execute(rawText: '500 ml right now', now: now);
    expect(result.amountMl, 500);
    expect(result.confidence, 'high');
  });

  test('an "at HH:MM" time in the future resolves to yesterday', () {
    // now is 20:00; "at 9am" would be in the future today only if now were
    // earlier than 9am — here 9am today is already in the past relative to
    // 20:00, so it should stay today.
    final earlyNow = DateTime(2026, 6, 15, 6);
    final result = parser.execute(rawText: '500ml at 9am', now: earlyNow);
    expect(result.loggedAt, DateTime(2026, 6, 14, 9));
  });

  test('empty string -> null amount, low confidence', () {
    final result = parser.execute(rawText: '', now: now);
    expect(result.amountMl, isNull);
    expect(result.confidence, 'low');
  });

  test('rawText is preserved verbatim on the result', () {
    final result = parser.execute(rawText: '2 glasses just now', now: now);
    expect(result.rawText, '2 glasses just now');
  });
}
