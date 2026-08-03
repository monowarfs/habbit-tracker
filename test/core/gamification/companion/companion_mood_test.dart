import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/companion/companion_mood.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

ModuleDayStatus _status(ModuleDayStatusKind kind) =>
    ModuleDayStatus(kind: kind, value: 0);

void main() {
  group('deriveCompanionMood', () {
    test('fewer than 3 days of data returns neutral', () {
      final days = [_status(ModuleDayStatusKind.complete)];
      expect(deriveCompanionMood(days), CompanionMood.neutral);
    });

    test('5+ complete days returns thriving', () {
      final days = List.generate(
        7,
        (i) => _status(
          i < 5 ? ModuleDayStatusKind.complete : ModuleDayStatusKind.missed,
        ),
      );
      expect(deriveCompanionMood(days), CompanionMood.thriving);
    });

    test('3-4 complete days returns happy', () {
      final days = List.generate(
        7,
        (i) => _status(
          i < 3 ? ModuleDayStatusKind.complete : ModuleDayStatusKind.missed,
        ),
      );
      expect(deriveCompanionMood(days), CompanionMood.happy);
    });

    test('1-2 complete days (with >=3 days data) returns neutral', () {
      final days = List.generate(
        7,
        (i) => _status(
          i < 1 ? ModuleDayStatusKind.complete : ModuleDayStatusKind.missed,
        ),
      );
      expect(deriveCompanionMood(days), CompanionMood.neutral);
    });

    test('0 complete days returns worried, never sad', () {
      final days = List.generate(7, (_) => _status(ModuleDayStatusKind.missed));
      expect(deriveCompanionMood(days), CompanionMood.worried);
    });
  });
}
