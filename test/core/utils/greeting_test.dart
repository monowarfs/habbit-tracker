import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/greeting.dart';

void main() {
  group('greetingPeriodFor', () {
    test('04:59 is night (just before the morning boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 4, 59)),
        GreetingPeriod.night,
      );
    });

    test('05:00 is morning (the morning boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 5)),
        GreetingPeriod.morning,
      );
    });

    test('11:59 is still morning (just before the afternoon boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 11, 59)),
        GreetingPeriod.morning,
      );
    });

    test('12:00 is afternoon (the afternoon boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 12)),
        GreetingPeriod.afternoon,
      );
    });

    test('16:59 is still afternoon (just before the evening boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 16, 59)),
        GreetingPeriod.afternoon,
      );
    });

    test('17:00 is evening (the evening boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 17)),
        GreetingPeriod.evening,
      );
    });

    test('20:59 is still evening (just before the night boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 20, 59)),
        GreetingPeriod.evening,
      );
    });

    test('21:00 is night (the night boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 21)),
        GreetingPeriod.night,
      );
    });

    test('00:00 (midnight) is night', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6)),
        GreetingPeriod.night,
      );
    });
  });
}
