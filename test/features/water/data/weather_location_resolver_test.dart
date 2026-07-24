import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

void main() {
  test(
    'resolves to a clean Failure (never a thrown exception) when no '
    'geolocator platform channel is registered, as in this test '
    "environment — mirrors `location_resolver_test.dart`'s own "
    "precedent for the one geolocator-touching branch that can't be "
    'exercised without a real device/emulator',
    () async {
      final result = await resolveWeatherLocation();
      expect(result, isA<Failure<WeatherLocation>>());
    },
  );
}
