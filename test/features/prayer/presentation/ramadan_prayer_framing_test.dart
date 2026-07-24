import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/ramadan_prayer_framing.dart';

void main() {
  test('Fajr maps to sehri framing', () {
    expect(ramadanFramingFor(PrayerName.fajr), RamadanPrayerFraming.sehri);
  });

  test('Maghrib maps to iftar framing', () {
    expect(ramadanFramingFor(PrayerName.maghrib), RamadanPrayerFraming.iftar);
  });

  test('every other prayer has no Ramadan framing', () {
    expect(ramadanFramingFor(PrayerName.dhuhr), isNull);
    expect(ramadanFramingFor(PrayerName.asr), isNull);
    expect(ramadanFramingFor(PrayerName.isha), isNull);
  });
}
