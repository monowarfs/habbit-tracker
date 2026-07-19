import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';

void main() {
  // 2026-06-05 is a Friday.
  const friday = LocalDate(2026, 6, 5);
  const saturday = LocalDate(2026, 6, 6);

  test('Dhuhr on a Friday with observesJumuah on: true', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: friday,
        observesJumuah: true,
      ),
      isTrue,
    );
  });

  test('Dhuhr on a Friday with observesJumuah off: false', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: friday,
        observesJumuah: false,
      ),
      isFalse,
    );
  });

  test('Dhuhr on a non-Friday, even with observesJumuah on: false', () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.dhuhr,
        date: saturday,
        observesJumuah: true,
      ),
      isFalse,
    );
  });

  test("a non-Dhuhr prayer on a Friday is never Jumu'ah: false", () {
    expect(
      isJumuahDisplay(
        prayerName: PrayerName.asr,
        date: friday,
        observesJumuah: true,
      ),
      isFalse,
    );
  });
}
