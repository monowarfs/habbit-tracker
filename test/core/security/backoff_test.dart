import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/security/backoff.dart';

void main() {
  test('no delay for the first 3 failed attempts', () {
    expect(calculateBackoffDelay(1), Duration.zero);
    expect(calculateBackoffDelay(3), Duration.zero);
  });

  test('4th attempt: 5s, 5th attempt: 30s', () {
    expect(calculateBackoffDelay(4), const Duration(seconds: 5));
    expect(calculateBackoffDelay(5), const Duration(seconds: 30));
  });

  test('6th+ attempts double each time, capped at 5 minutes', () {
    expect(calculateBackoffDelay(6), const Duration(seconds: 60));
    expect(calculateBackoffDelay(7), const Duration(seconds: 120));
    expect(calculateBackoffDelay(8), const Duration(seconds: 240));
    expect(calculateBackoffDelay(9), const Duration(seconds: 300));
    expect(calculateBackoffDelay(20), const Duration(seconds: 300));
  });
}
