import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/dev/seed_data_generator.dart';

void main() {
  group('generateAdherencePattern', () {
    test('returns an empty list for zero or negative days', () {
      expect(generateAdherencePattern(0, Random(1)), isEmpty);
      expect(generateAdherencePattern(-5, Random(1)), isEmpty);
    });

    test('returns exactly totalDays entries', () {
      final pattern = generateAdherencePattern(400, Random(42));
      expect(pattern, hasLength(400));
    });

    test('clumps into runs rather than flipping every day', () {
      // A pure per-day coin flip over 400 days would produce close to
      // 200 sign changes; the streak-based generator should produce far
      // fewer, since good/bad stretches run several days at a time.
      final pattern = generateAdherencePattern(400, Random(7));
      var switches = 0;
      for (var i = 1; i < pattern.length; i++) {
        if (pattern[i] != pattern[i - 1]) switches++;
      }
      expect(switches, lessThan(150));
    });

    test('is mostly (but not exclusively) good days', () {
      final pattern = generateAdherencePattern(1000, Random(99));
      final goodCount = pattern.where((isGood) => isGood).length;
      expect(goodCount, greaterThan(500));
      expect(goodCount, lessThan(1000));
    });
  });
}
