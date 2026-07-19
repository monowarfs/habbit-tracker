import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prayer_controller.g.dart';

/// Mutation surface for the Prayer module — mirrors `MedicineController`'s
/// shape (no state of its own; screens watch the read providers in
/// `prayer_providers.dart`).
@Riverpod(keepAlive: true)
class PrayerController extends _$PrayerController {
  @override
  void build() {}

  /// Toggles a record's prayed status (FR-P-07 — one-tap toggle, not a
  /// multi-state cycle).
  Future<void> togglePrayed(
    String recordId, {
    required bool currentlyPrayed,
  }) async {
    final repository = ref.read(prayerRepositoryProvider);
    final result = currentlyPrayed
        ? await repository.unmarkPrayed(recordId)
        : await repository.markPrayed(recordId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Applies the "−1" Qadha make-up control (FR-P-05).
  Future<void> markQadhaMakeup(PrayerName prayerName) async {
    final result = await ref
        .read(prayerRepositoryProvider)
        .markQadhaMakeup(prayerName);
    if (result case Failure(:final error)) logException(error);
  }

  /// Sets a Qadha counter directly (FR-P-04's onboarding/Settings entry).
  Future<void> setQadhaBalance(PrayerName prayerName, int count) async {
    final result = await ref
        .read(prayerRepositoryProvider)
        .setQadhaBalance(prayerName, count);
    if (result case Failure(:final error)) logException(error);
  }

  /// Updates settings; only non-null arguments change. A location/method
  /// change re-materializes immediately afterward (rather than waiting
  /// for the next app-resume cycle) so the checklist reflects it right
  /// away — the repository has already cleared the stale future records
  /// as part of `updateSettings` itself (this plan's refinements
  /// section, #3).
  Future<void> updateSettings({
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
  }) async {
    final repository = ref.read(prayerRepositoryProvider);
    final result = await repository.updateSettings(
      calculationMethod: calculationMethod,
      asrMethod: asrMethod,
      observesJumuah: observesJumuah,
      locationMode: locationMode,
      manualLatitude: manualLatitude,
      manualLongitude: manualLongitude,
      manualTimezone: manualTimezone,
      ishaDayRolloverTime: ishaDayRolloverTime,
      notificationsEnabled: notificationsEnabled,
      preReminderEnabled: preReminderEnabled,
      preReminderOffsetMinutes: preReminderOffsetMinutes,
    );
    if (result case Failure(:final error)) logException(error);
    ref.invalidate(resolvedPrayerLocationProvider);
    final location = await ref.read(resolvedPrayerLocationProvider.future);
    if (location != null) {
      await repository.materializeRecords(clock.now(), location);
    }
  }
}
