import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:http/http.dart' as http;

/// Current-conditions snapshot used for reminder-copy enrichment only —
/// never displayed as a dedicated weather feature (out of scope,
/// `docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`).
typedef WeatherSnapshot = ({double temperatureCelsius, DateTime fetchedAt});

/// Fetches current temperature for [latitude]/[longitude] from Open-Meteo
/// — the sole file touching the weather API or `http` directly, same
/// "one file owns the plugin" precedent as `notification_service.dart`/
/// `location_resolver.dart`. Never allowed to block notification
/// planning: a short [timeout], and any error (timeout, no connectivity,
/// bad response, malformed JSON) becomes a `Failure`, never a thrown
/// exception. [client] is an injectable seam for tests
/// (`package:http/testing.dart`'s `MockClient`) — production callers omit
/// it and get a real, short-lived `http.Client`.
Future<Result<WeatherSnapshot>> fetchCurrentWeather({
  required double latitude,
  required double longitude,
  Duration timeout = const Duration(seconds: 5),
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m',
    });
    final response = await httpClient.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return Result.failure(
        AppException.unexpected(
          Exception('weather fetch returned HTTP ${response.statusCode}'),
          StackTrace.current,
        ),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final temperature = (current['temperature_2m'] as num).toDouble();
    return Result.success((
      temperatureCelsius: temperature,
      fetchedAt: clock.now().toUtc(),
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  } finally {
    if (client == null) httpClient.close();
  }
}
