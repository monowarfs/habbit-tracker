import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/stock_projection.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/predict_stock_out_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medicine_providers.g.dart';

/// The Medicine module's [MedicineRepository].
@Riverpod(keepAlive: true)
MedicineRepository medicineRepository(Ref ref) {
  return MedicineRepositoryImpl(ref.watch(databaseProvider));
}

LocalDate _today() => localDayKey(clock.now());

/// Every (non-deleted) medicine, optionally including archived ones. Empty
/// (never emitting) until the active profile resolves — Riverpod rebuilds
/// this automatically once it does, since [activeProfileProvider] is
/// watched.
@Riverpod(keepAlive: true)
Stream<List<Medicine>> medicines(Ref ref, {required bool includeArchived}) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(medicineRepositoryProvider)
      .watchMedicines(includeArchived: includeArchived, profileId: profileId);
}

/// A single medicine by id, for the detail/edit screens.
@riverpod
Future<Medicine?> medicineById(Ref ref, String id) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  return ref
      .watch(medicineRepositoryProvider)
      .medicineById(id, profileId: profileId);
}

/// A medicine's (non-deleted) schedules.
@riverpod
Stream<List<MedicineSchedule>> medicineSchedules(Ref ref, String medicineId) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(medicineRepositoryProvider)
      .watchSchedules(medicineId, profileId: profileId);
}

/// Projected stock-out date for [medicineId]
/// (`docs/superpowers/plans/ai-powered/
/// 03-predictive-stock-out-date-impl-plan.md`) — derived at read time,
/// never persisted, from the medicine's own stock ledger.
@riverpod
Future<StockProjection> stockProjection(Ref ref, String medicineId) async {
  final medicine = await ref.watch(medicineByIdProvider(medicineId).future);
  if (medicine == null || !medicine.stockEnabled) {
    return const StockProjection(
      sampleSize: 0,
      confidence: 'low',
      currentStock: 0,
    );
  }
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final events = await ref
      .watch(medicineRepositoryProvider)
      .allStockEvents(profileId: profileId);
  return const PredictStockOutDateUseCase().execute(
    medicine: medicine,
    stockEvents: events,
    now: clock.now(),
  );
}

/// Every dose scheduled today, across every medicine.
@Riverpod(keepAlive: true)
Stream<List<MedicineDose>> todaysDoses(Ref ref) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(medicineRepositoryProvider)
      .watchDosesForDay(_today(), profileId: profileId);
}

/// An inclusive local-day range, used as a family provider parameter
/// (mirrors `water_providers.dart`'s `WaterDateRange`).
typedef MedicineDateRange = ({LocalDate start, LocalDate end});

/// Every dose in [range], across every medicine — cached per unique range
/// by Riverpod so screens that `ref.watch` this (e.g. the stats screen's
/// 7-day chart, the detail screen's 30-day adherence lookback) don't
/// re-query on every rebuild the way an inline `FutureBuilder` would.
@Riverpod(keepAlive: true)
Future<List<MedicineDose>> medicineDosesInRange(
  Ref ref,
  MedicineDateRange range,
) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  return ref
      .watch(medicineRepositoryProvider)
      .dosesInRange(range.start, range.end, profileId: profileId);
}

/// A dose paired with its medicine and live-derived status — what the
/// dose timeline (Task 14) actually renders.
typedef MedicineDoseView = ({
  MedicineDose dose,
  Medicine medicine,
  MedicineDoseStatus effectiveStatus,
});

/// Today's doses, joined with their medicine and effective status,
/// ordered by scheduled time — or `null` while still loading.
@riverpod
List<MedicineDoseView>? todaysDoseViews(Ref ref) {
  final doses = ref.watch(todaysDosesProvider).value;
  final medicines = ref.watch(medicinesProvider(includeArchived: false)).value;
  // If either stream hasn't emitted yet, return null (loading state).
  // If the database is empty, both will be empty lists (not null).
  if (doses == null || medicines == null) return null;
  final medicinesById = {for (final m in medicines) m.id: m};
  final now = clock.now();
  final views = <MedicineDoseView>[
    for (final dose in doses)
      if (medicinesById[dose.medicineId] case final medicine?)
        (
          dose: dose,
          medicine: medicine,
          effectiveStatus: effectiveDoseStatus(
            storedStatus: dose.storedStatus,
            scheduledFor: dose.scheduledFor,
            now: now,
            graceWindowMinutes: dose.graceWindowMinutes,
          ),
        ),
  ]..sort((a, b) => a.dose.scheduledFor.compareTo(b.dose.scheduledFor));
  return views;
}
