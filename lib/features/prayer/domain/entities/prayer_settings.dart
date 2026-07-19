import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'prayer_settings.freezed.dart';

/// A standard prayer-time calculation method (FR-P-01, D-06) — exactly
/// the ten `adhan_dart` presets this run supports, matching
/// `technical/database-design.md`'s `prayer_settings.calculation_method`
/// enum.
enum CalculationMethod {
  /// Muslim World League.
  mwl,

  /// Islamic Society of North America.
  isna,

  /// Egyptian General Survey Authority.
  egyptian,

  /// Umm Al-Qura University, Makkah.
  ummAlQura,

  /// University of Islamic Sciences, Karachi.
  karachi,

  /// Institute of Geophysics, University of Tehran.
  tehran,

  /// Dubai.
  dubai,

  /// Kuwait.
  kuwait,

  /// Qatar.
  qatar,

  /// Majlis Ugama Islam Singapura.
  singapore,
}

/// The Asr juristic method (FR-P-02, D-06).
enum AsrMethod {
  /// Shafi'i/Maliki/Hanbali.
  standard,

  /// Hanafi.
  hanafi,
}

/// Whether prayer times are computed from a live GPS fix or a fixed
/// location (FR-P-06, D-09).
enum LocationMode {
  /// One-shot GPS fix, re-resolved on app foreground/background refresh.
  auto,

  /// A fixed city/lat-long the user entered in Settings.
  manual,
}

/// The Prayer module's singleton settings row (`technical/database-
/// design.md`'s `prayer_settings`, same pattern as `app_settings`).
@freezed
sealed class PrayerSettings with _$PrayerSettings {
  /// Creates prayer settings.
  const factory PrayerSettings({
    required String id,
    required CalculationMethod calculationMethod,
    required AsrMethod asrMethod,
    required LocationMode locationMode,
    @Default(false) bool observesJumuah,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    @Default(LocalTime(0, 0)) LocalTime ishaDayRolloverTime,

    /// Whether the on-time prayer notification fires at all (FR-P-08) —
    /// an addition beyond `database-design.md`'s original column list
    /// (this plan's refinements section, #4).
    @Default(true) bool notificationsEnabled,

    /// Whether the optional pre-prayer reminder fires (FR-P-08).
    @Default(false) bool preReminderEnabled,

    /// Minutes before `scheduledFor` the pre-prayer reminder fires.
    @Default(10) int preReminderOffsetMinutes,
  }) = _PrayerSettings;
}
