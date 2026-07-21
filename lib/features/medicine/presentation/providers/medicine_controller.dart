import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medicine_controller.g.dart';

/// Mutation surface for the Medicine module — a pure command controller
/// mirroring `WaterController`'s shape (no state of its own; screens
/// watch the read providers in `medicine_providers.dart`).
@Riverpod(keepAlive: true)
class MedicineController extends _$MedicineController {
  @override
  void build() {}

  /// Creates a medicine with one initial schedule (FR-M-01).
  Future<void> createMedicine({
    required String name,
    required bool stockEnabled,
    required RepeatRule rule,
    required LocalDate startDate,
    String? dosageNote,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    final repository = ref.read(medicineRepositoryProvider);
    final medicineResult = await repository.createMedicine(
      name: name,
      dosageNote: dosageNote,
      stockEnabled: stockEnabled,
      stockCount: stockCount,
      stockThreshold: stockThreshold,
      stopWhenStockDepleted: stopWhenStockDepleted,
      consumptionPerDose: consumptionPerDose,
    );
    if (medicineResult case Failure(:final error)) {
      logException(error);
      return;
    }
    final medicine = (medicineResult as Success<Medicine>).value;
    final scheduleResult = await repository.createSchedule(
      medicineId: medicine.id,
      rule: rule,
      startDate: startDate,
      endDate: endDate,
      graceWindowMinutes: graceWindowMinutes,
    );
    if (scheduleResult case Failure(:final error)) logException(error);
    await repository.materializeDoses(clock.now());
  }

  /// Adds an additional schedule to an existing medicine (D-02).
  Future<void> addSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    final repository = ref.read(medicineRepositoryProvider);
    final result = await repository.createSchedule(
      medicineId: medicineId,
      rule: rule,
      startDate: startDate,
      endDate: endDate,
      graceWindowMinutes: graceWindowMinutes,
    );
    if (result case Failure(:final error)) logException(error);
    await repository.materializeDoses(clock.now());
  }

  /// Marks a dose done (FR-M-07).
  Future<void> markDoseDone(
    String doseId, {
    bool fromOtherSource = false,
  }) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .markDoseDone(doseId, fromOtherSource: fromOtherSource);
    if (result case Failure(:final error)) {
      logException(error);
      return;
    }
    await ref.read(achievementEngineProvider).evaluate('medicine');
  }

  /// Marks a dose skipped (FR-M-07).
  Future<void> markDoseSkipped(String doseId) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .markDoseSkipped(doseId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Un-marks a done dose.
  Future<void> undoDose(String doseId) async {
    final result = await ref.read(medicineRepositoryProvider).undoDose(doseId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Annotates a dose with a free-text note, independent of its status.
  Future<void> updateDoseNotes(String doseId, String? notes) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .updateDoseNotes(doseId, notes);
    if (result case Failure(:final error)) logException(error);
  }

  /// Archives a medicine (FR-M-10).
  Future<void> archiveMedicine(String id) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .archiveMedicine(id);
    if (result case Failure(:final error)) logException(error);
  }

  /// Restores an archived medicine.
  Future<void> restoreMedicine(String id) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .restoreMedicine(id);
    if (result case Failure(:final error)) logException(error);
  }

  /// Applies a drag-to-reorder result (active-list display order only).
  Future<void> reorderMedicines(List<String> orderedIds) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .reorderMedicines(orderedIds);
    if (result case Failure(:final error)) logException(error);
  }

  /// Adds stock via a manual refill.
  Future<void> refillStock(String medicineId, int amount) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .refillStock(medicineId, amount);
    if (result case Failure(:final error)) logException(error);
  }
}
