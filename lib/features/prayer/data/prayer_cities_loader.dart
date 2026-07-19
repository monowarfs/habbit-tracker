import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';

/// Loads the bundled city picker list (`assets/data/prayer_cities.json`).
Future<List<PrayerCity>> loadPrayerCities() async {
  final raw = await rootBundle.loadString('assets/data/prayer_cities.json');
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((entry) {
        final map = entry as Map<String, dynamic>;
        return PrayerCity(
          nameKey: map['nameKey'] as String,
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          ianaTimezone: map['ianaTimezone'] as String,
        );
      })
      .toList(growable: false);
}
