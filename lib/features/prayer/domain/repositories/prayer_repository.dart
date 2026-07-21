import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';

/// Reads and mutates the Prayer module's data.
abstract class PrayerRepository {
  /// Streams the (auto-seeded) singleton settings row.
  Stream<PrayerSettings> watchSettings();

  /// Updates settings fields; only non-null arguments change. Soft-
  /// deletes future `upcoming` records when a location/method-affecting
  /// field changes, so the next materialization pass regenerates them
  /// with the new times (FR-P-01, this plan's refinements section, #3).
  Future<Result<void>> updateSettings({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
    bool? observesJumuah,
    LocationMode? locationMode,
    double? manualLatitude,
    double? manualLongitude,
    String? manualTimezone,
    LocalTime? ishaDayRolloverTime,
    bool? notificationsEnabled,
    bool? preReminderEnabled,
    int? preReminderOffsetMinutes,
  });

  /// Streams all five Qadha counters (seeded at first settings read).
  Stream<List<PrayerQadhaCounter>> watchQadhaCounters();

  /// Applies the "−1" make-up control (FR-P-05).
  Future<Result<void>> markQadhaMakeup(PrayerName prayerName);

  /// Sets a counter directly (FR-P-04's onboarding/Settings starting-
  /// balance entry — a raw input, not derived logic). Clamped at 0.
  Future<Result<void>> setQadhaBalance(PrayerName prayerName, int count);

  /// Tops up `prayer_records` for the D-13 30-day rolling window ahead of
  /// [now], given the currently resolved [location] (this plan's
  /// refinements section, #2). Idempotent.
  Future<void> materializeRecords(DateTime now, ResolvedLocation location);

  /// One-shot missed-prayer sweep + Qadha+1 (FR-P-05), given the
  /// currently resolved [location] (needed for the Isha rollover
  /// cutoff's timezone). Idempotent — a record only ever makes the
  /// upcoming->missed transition once.
  Future<void> sweepMissedPrayers(DateTime now, ResolvedLocation location);

  /// Streams every (non-deleted) record scheduled on [day].
  Stream<List<PrayerRecord>> watchRecordsForDay(LocalDate day);

  /// Every (non-deleted) record with `prayerDate` in `[start, end]`
  /// inclusive.
  Future<List<PrayerRecord>> recordsInRange(LocalDate start, LocalDate end);

  /// Marks a record prayed (FR-P-07's one-tap toggle). Fails validation
  /// if the record is already `missed` (never a manual tap target).
  Future<Result<void>> markPrayed(String recordId);

  /// Un-marks a prayed record back to `upcoming` (toggle off).
  Future<Result<void>> unmarkPrayed(String recordId);

  /// Marks a record explicitly missed via a Skip notification action
  /// (FR-P-08) — same transition `sweepMissedPrayers` would eventually
  /// make, just user-triggered; bumps that prayer's Qadha counter.
  Future<Result<void>> markMissedBySkip(String recordId);

  /// Annotates a record with a free-text note, legal in any status —
  /// including `missed` ("missed — was in a meeting"), unlike
  /// `markPrayed`/`markMissedBySkip` which guard on status.
  Future<Result<void>> updatePrayerNotes(String recordId, String? notes);

  /// Every (non-deleted) record, across every day — export groundwork.
  Future<List<PrayerRecord>> allRecords();

  /// All five Qadha counters as a snapshot (not a stream) — export
  /// groundwork.
  Future<List<PrayerQadhaCounter>> allQadhaCounters();

  /// Inserts [record] exactly as given, with a freshly generated id —
  /// import's restore path, bypassing `materializeRecords`'s
  /// upcoming-only generation.
  Future<void> restoreRecord(PrayerRecord record);

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
