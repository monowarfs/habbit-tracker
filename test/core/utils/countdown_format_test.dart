import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/countdown_format.dart';

void main() {
  test('under an hour formats as "N min"', () {
    expect(formatCountdown(const Duration(minutes: 42)), '42 min');
    expect(formatCountdown(const Duration(minutes: 1)), '1 min');
  });

  test('an hour or more formats as "Hh Mm"', () {
    expect(formatCountdown(const Duration(hours: 2, minutes: 15)), '2h 15m');
    expect(formatCountdown(const Duration(hours: 1)), '1h 0m');
  });
}
