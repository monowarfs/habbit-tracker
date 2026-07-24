import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Ramadan-specific display framing for a prayer name (`docs/superpowers/
/// specs/02-delightful/01-ramadan-mode-design.md`'s Design §5) — pure, so
/// `PrayerModule.nextUpcoming`/`pendingNotifications` can both call it
/// without needing a `BuildContext`.
enum RamadanPrayerFraming {
  /// Fajr — "Sehri ends" framing.
  sehri,

  /// Maghrib — "Iftar" framing.
  iftar,
}

/// The Ramadan framing for [prayerName], or `null` for every prayer
/// besides Fajr/Maghrib (no framing change).
RamadanPrayerFraming? ramadanFramingFor(PrayerName prayerName) =>
    switch (prayerName) {
      PrayerName.fajr => RamadanPrayerFraming.sehri,
      PrayerName.maghrib => RamadanPrayerFraming.iftar,
      PrayerName.dhuhr || PrayerName.asr || PrayerName.isha => null,
    };
