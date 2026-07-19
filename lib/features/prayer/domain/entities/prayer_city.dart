import 'package:freezed_annotation/freezed_annotation.dart';

part 'prayer_city.freezed.dart';

/// One entry in the bundled `assets/data/prayer_cities.json` picker list.
/// [nameKey] is resolved through `AppLocalizations` at render time (not a
/// raw display string), so the same bundled dataset serves both locales.
@freezed
sealed class PrayerCity with _$PrayerCity {
  /// Creates a city entry.
  const factory PrayerCity({
    required String nameKey,
    required double latitude,
    required double longitude,
    required String ianaTimezone,
  }) = _PrayerCity;
}
