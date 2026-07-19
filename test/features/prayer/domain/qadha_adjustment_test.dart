import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/qadha_adjustment.dart';

void main() {
  test('decrements by 1', () {
    final counter = PrayerQadhaCounter(
      id: 'c1',
      prayerName: PrayerName.fajr,
      count: 5,
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    expect(applyQadhaMakeup(counter), 4);
  });

  test('clamps at 0, never goes negative', () {
    final counter = PrayerQadhaCounter(
      id: 'c1',
      prayerName: PrayerName.fajr,
      count: 0,
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    expect(applyQadhaMakeup(counter), 0);
  });
}
