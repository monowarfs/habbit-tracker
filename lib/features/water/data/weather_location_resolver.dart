import 'package:geolocator/geolocator.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';

/// A weather-lookup location — coarse coordinates only, no timezone
/// (unlike Prayer's `ResolvedLocation`, which also carries an IANA
/// timezone this feature has no use for).
typedef WeatherLocation = ({double latitude, double longitude});

/// Resolves the device's current location for weather lookups
/// (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`) — a second, independent
/// `geolocator` call site from Prayer's own `resolveLocation()`
/// (deliberately not shared: two independent opt-ins, so a user can
/// decline weather-location while keeping Prayer's, or vice versa,
/// without an awkward "which feature is asking" parameter). The sole
/// other file (besides `features/prayer/data/location_resolver.dart`)
/// touching `geolocator` directly.
Future<Result<WeatherLocation>> resolveWeatherLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const Result.failure(
        AppException.permission('location_service'),
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Result.failure(AppException.permission('location'));
    }
    final position =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
    return Result.success((
      latitude: position.latitude,
      longitude: position.longitude,
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  }
}
