import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/data/prayer_cities_loader.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/jumuah_label.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prayer_providers.g.dart';

/// The Prayer module's [PrayerRepository].
@Riverpod(keepAlive: true)
PrayerRepository prayerRepository(Ref ref) {
  return PrayerRepositoryImpl(ref.watch(databaseProvider));
}

LocalDate _today() => localDayKey(clock.now());

/// The (auto-seeded) singleton settings row.
@riverpod
Stream<PrayerSettings> prayerSettings(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchSettings();
}

/// The five Qadha counters.
@riverpod
Stream<List<PrayerQadhaCounter>> prayerQadhaCounters(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchQadhaCounters();
}

/// The bundled city picker list, loaded once.
@Riverpod(keepAlive: true)
Future<List<PrayerCity>> prayerCities(Ref ref) => loadPrayerCities();

/// The currently resolved calculation location — re-resolves whenever
/// [prayerSettingsProvider] changes (e.g. switching location mode), or
/// `null` if resolution failed (permission denied, incomplete manual
/// entry) — callers show a "location unavailable" state rather than
/// crashing.
@riverpod
Future<ResolvedLocation?> resolvedPrayerLocation(Ref ref) async {
  final settings = await ref.watch(prayerSettingsProvider.future);
  final result = await resolveLocation(settings);
  return switch (result) {
    Success(:final value) => value,
    Failure() => null,
  };
}

/// Every (non-deleted) record with `prayerDate` in `[start, end]`
/// inclusive — used by the history calendar and stats screens.
@riverpod
Future<List<PrayerRecord>> prayerRecordsInRange(
  Ref ref, {
  required LocalDate start,
  required LocalDate end,
}) {
  return ref.watch(prayerRepositoryProvider).recordsInRange(start, end);
}

/// Today's five prayer records.
@riverpod
Stream<List<PrayerRecord>> todaysPrayerRecords(Ref ref) {
  return ref.watch(prayerRepositoryProvider).watchRecordsForDay(_today());
}

/// A prayer record paired with its live-derived status and Jumu'ah
/// display flag — what the checklist screen actually renders.
typedef PrayerRecordView = ({
  PrayerRecord record,
  PrayerStatus effectiveStatus,
  bool showAsJumuah,
});

/// Today's records, joined with derived status/display info, sorted by
/// scheduled time — or `null` while still loading.
@riverpod
List<PrayerRecordView>? todaysPrayerViews(Ref ref) {
  final records = ref.watch(todaysPrayerRecordsProvider).value;
  final settings = ref.watch(prayerSettingsProvider).value;
  if (records == null || settings == null) return null;
  final location = ref.watch(resolvedPrayerLocationProvider).value;
  final now = clock.now();
  final sorted = [...records]
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  return [
    for (final record in sorted)
      (
        record: record,
        effectiveStatus: effectivePrayerStatus(
          storedStatus: record.storedStatus,
          scheduledFor: record.scheduledFor,
          cutoff: cutoffForPrayer(
            record: record,
            sameDayRecordsSorted: sorted,
            ishaDayRolloverTime: settings.ishaDayRolloverTime,
            ianaTimezone: location?.ianaTimezone,
          ),
          now: now,
        ),
        showAsJumuah: isJumuahDisplay(
          prayerName: record.prayerName,
          date: record.prayerDate,
          observesJumuah: settings.observesJumuah,
        ),
      ),
  ];
}
