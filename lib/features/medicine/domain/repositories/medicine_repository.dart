import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// Reads and mutates the Medicine module's data.
abstract class MedicineRepository {
  /// Streams every (non-deleted) medicine, optionally including archived
  /// ones (FR-M-10).
  Stream<List<Medicine>> watchMedicines({required bool includeArchived});

  /// Looks up a single medicine by id, or `null` if missing/deleted.
  Future<Medicine?> medicineById(String id);

  /// Creates a medicine (FR-M-01).
  Future<Result<Medicine>> createMedicine({
    required String name,
    required bool stockEnabled,
    String? dosageNote,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
  });

  /// Edits a medicine's own fields (not its schedules).
  Future<Result<void>> updateMedicine(
    String id, {
    String? name,
    String? dosageNote,
    bool? stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool? stopWhenStockDepleted,
    int? consumptionPerDose,
  });

  /// Soft-archives a medicine (FR-M-10) — stops generating doses/
  /// notifications, retains history.
  Future<Result<void>> archiveMedicine(String id);

  /// Restores a previously archived medicine.
  Future<Result<void>> restoreMedicine(String id);

  /// Streams a medicine's (non-deleted) schedules.
  Stream<List<MedicineSchedule>> watchSchedules(String medicineId);

  /// Creates a schedule for [medicineId] (D-02: a medicine may have
  /// several concurrent schedules).
  Future<Result<MedicineSchedule>> createSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  });

  /// Edits a schedule (FR-M-09: applies to future doses only — deletes
  /// this schedule's still-`upcoming` doses at/after `now` so the next
  /// materialization pass regenerates them from the new rule; past/done/
  /// skipped doses are never touched).
  Future<Result<void>> updateSchedule(
    String id, {
    RepeatRule? rule,
    LocalDate? startDate,
    LocalDate? endDate,
    int? graceWindowMinutes,
  });

  /// Manually ends a schedule as of [endDate] (a user-initiated stop).
  Future<Result<void>> endSchedule(String id, {required LocalDate endDate});

  /// Tops up `medicine_doses` for the D-13 30-day rolling window ahead of
  /// [now]. Idempotent — safe to call from every re-planning trigger.
  Future<void> materializeDoses(DateTime now);

  /// Streams every (non-deleted) dose scheduled on [day], across every
  /// medicine — the flattened cross-schedule timeline (FR-M-02).
  Stream<List<MedicineDose>> watchDosesForDay(LocalDate day);

  /// Every (non-deleted) dose with `scheduledFor` in `[start, end]`
  /// inclusive — for previews/adherence.
  Future<List<MedicineDose>> dosesInRange(LocalDate start, LocalDate end);

  /// Marks a dose done (FR-M-07). [fromOtherSource]: true skips stock
  /// decrement (FR-M-05's out-of-stock allowance).
  Future<Result<void>> markDoseDone(
    String doseId, {
    required bool fromOtherSource,
  });

  /// Marks a dose explicitly skipped (FR-M-07) — never decrements stock,
  /// never counts as missed.
  Future<Result<void>> markDoseSkipped(String doseId);

  /// Un-marks a done dose, reversing its stock effect exactly.
  Future<Result<void>> undoDose(String doseId);

  /// Annotates a dose with a free-text note, independent of its status
  /// (before, at, or after marking done/skipped) — never bumps
  /// `statusChangedAt` since editing a note isn't a status change.
  Future<Result<void>> updateDoseNotes(String doseId, String? notes);

  /// Manually adds stock (a refill), recording a `manual_refill` event.
  /// Clears `lowStockNotifiedAt` once stock rises back above threshold.
  Future<Result<void>> refillStock(String medicineId, int amount);

  /// Medicines currently in a "just crossed below threshold, not yet
  /// cleared" state — the source `MedicineModule.pendingNotifications()`
  /// reads for FR-M-04's one-shot low-stock alert.
  Future<List<Medicine>> medicinesNeedingLowStockAlert();

  /// Every (non-deleted) medicine, including archived — export groundwork
  /// (`strategies/backup-import-export.md`).
  Future<List<Medicine>> allMedicines();

  /// Every (non-deleted) schedule across every medicine — export
  /// groundwork.
  Future<List<MedicineSchedule>> allSchedules();

  /// Every (non-deleted) dose across every medicine, unfiltered by date —
  /// export groundwork.
  Future<List<MedicineDose>> allDoses();

  /// Every (non-deleted) stock event across every medicine — export
  /// groundwork.
  Future<List<MedicineStockEvent>> allStockEvents();

  /// Inserts [dose] exactly as given, with a freshly generated id — used
  /// by import to restore historical doses without going through
  /// `materializeDoses`'s gap-filling logic (which only ever creates
  /// `upcoming` doses). Returns the new id, so the caller can remap
  /// `MedicineStockEvent.doseId` references.
  Future<String> restoreDose(MedicineDose dose);

  /// Inserts [event] exactly as given, with a freshly generated id —
  /// import's restore counterpart to [restoreDose].
  Future<void> restoreStockEvent(MedicineStockEvent event);

  /// Deletes every row this module owns — the wipe half of import's
  /// replace semantics (`HabitModule.wipeData()`).
  Future<void> wipeAll();
}
