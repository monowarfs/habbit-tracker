import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';

/// Resolves prayer-time calculation location from [settings] (FR-P-06/
/// D-09) — a one-shot GPS fix + the OS's own timezone when
/// `locationMode == auto`, or the stored manual lat/long/timezone
/// otherwise. The sole file touching `geolocator`/`flutter_timezone`
/// directly, same "one file owns the plugin" precedent as
/// `core/notifications/notification_service.dart`.
Future<Result<ResolvedLocation>> resolveLocation(
  PrayerSettings settings,
) async {
  if (settings.locationMode == LocationMode.manual) {
    final lat = settings.manualLatitude;
    final long = settings.manualLongitude;
    final timezone = settings.manualTimezone;
    if (lat == null || long == null || timezone == null) {
      return const Result.failure(
        AppException.validation(
          'manualLocation',
          'Manual location mode requires latitude, longitude, and timezone',
        ),
      );
    }
    return Result.success(
      (latitude: lat, longitude: long, ianaTimezone: timezone),
    );
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const Result.failure(AppException.permission('location_service'));
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Result.failure(AppException.permission('location'));
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    final timezone = await FlutterTimezone.getLocalTimezone();
    return Result.success((
      latitude: position.latitude,
      longitude: position.longitude,
      ianaTimezone: timezone.identifier,
    ));
  } on Object catch (e) {
    return Result.failure(AppException.unexpected(e, StackTrace.current));
  }
}
