import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';

void main() {
  test('manual mode resolves directly from settings fields', () async {
    const settings = PrayerSettings(
      id: 'singleton',
      calculationMethod: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
      locationMode: LocationMode.manual,
      manualLatitude: 23.8103,
      manualLongitude: 90.4125,
      manualTimezone: 'Asia/Dhaka',
    );
    final result = await resolveLocation(settings);
    expect(result, isA<Success<ResolvedLocation>>());
    final location = (result as Success<ResolvedLocation>).value;
    expect(location.latitude, 23.8103);
    expect(location.ianaTimezone, 'Asia/Dhaka');
  });

  test(
    'manual mode with an incomplete manual location fails validation',
    () async {
      const settings = PrayerSettings(
        id: 'singleton',
        calculationMethod: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
        locationMode: LocationMode.manual,
      );
      final result = await resolveLocation(settings);
      expect(result, isA<Failure<ResolvedLocation>>());
    },
  );
}
