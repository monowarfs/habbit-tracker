import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/boss/boss_rotation.dart';

void main() {
  test('the same week key always picks the same module', () {
    final first = bossModuleForWeek('2026-W32');
    for (var i = 0; i < 5; i++) {
      expect(bossModuleForWeek('2026-W32'), first);
    }
  });

  test('every rotation module is reachable across enough weeks', () {
    final seen = <String>{};
    for (var week = 1; week <= 52; week++) {
      seen.add(bossModuleForWeek('2026-W${week.toString().padLeft(2, '0')}'));
    }
    expect(seen, bossRotationModules.toSet());
  });

  test('the picked module is always one of the 3 rotation modules', () {
    for (var week = 1; week <= 10; week++) {
      expect(
        bossRotationModules,
        contains(bossModuleForWeek('2027-W${week.toString().padLeft(2, '0')}')),
      );
    }
  });
}
