import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/data/weather_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses a successful response into a WeatherSnapshot', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.queryParameters['latitude'], '23.8103');
      expect(request.url.queryParameters['longitude'], '90.4125');
      expect(request.url.queryParameters['current'], 'temperature_2m');
      return http.Response(
        '{"latitude":23.8103,"longitude":90.4125,'
        '"current":{"temperature_2m":34.2,"time":"2026-06-01T12:00"}}',
        200,
      );
    });

    final result = await fetchCurrentWeather(
      latitude: 23.8103,
      longitude: 90.4125,
      client: client,
    );

    expect(result, isA<Success<WeatherSnapshot>>());
    expect(
      (result as Success<WeatherSnapshot>).value.temperatureCelsius,
      34.2,
    );
  });

  test('a non-200 response is a Failure, not a thrown exception', () async {
    final client = MockClient((request) async => http.Response('boom', 500));

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });

  test('a slow response past the timeout is a Failure', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{"current":{"temperature_2m":20}}', 200);
    });

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      timeout: const Duration(milliseconds: 5),
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });

  test('malformed JSON is a Failure', () async {
    final client = MockClient(
      (request) async => http.Response('not json', 200),
    );

    final result = await fetchCurrentWeather(
      latitude: 0,
      longitude: 0,
      client: client,
    );

    expect(result, isA<Failure<WeatherSnapshot>>());
  });
}
