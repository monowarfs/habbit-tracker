import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/plan_dose_materialization.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/stock_adjustment.dart';

/// How far ahead `materializeDoses` tops up the dose window (D-13).
const _materializationWindowDays = 30;

/// Drift-backed [MedicineRepository]. No DAO — same precedent as Water's
/// `WaterRepositoryImpl`, one caller.
class MedicineRepositoryImpl implements MedicineRepository {
  /// Creates a repository backed by [_db].
  MedicineRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Medicine>> watchMedicines({required bool includeArchived}) {
    final query = _db.select(_db.medicinesTable)
      ..where((t) => t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archivedAt.isNull());
    }
    return query.watch().map(
      (rows) => rows.map(_medicineFromRow).toList(growable: false),
    );
  }

  @override
  Future<Medicine?> medicineById(String id) async {
    final row = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _medicineFromRow(row);
  }

  @override
  Future<Result<Medicine>> createMedicine({
    required String name,
    required bool stockEnabled,
    String? dosageNote,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.medicinesTable)
          .insert(
            MedicinesTableCompanion.insert(
              id: id,
              name: name,
              dosageNote: Value(dosageNote),
              stockEnabled: stockEnabled,
              stockCount: Value(stockCount),
              stockThreshold: Value(stockThreshold),
              stopWhenStockDepleted: Value(stopWhenStockDepleted),
              consumptionPerDose: Value(consumptionPerDose),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        Medicine(
          id: id,
          name: name,
          dosageNote: dosageNote,
          stockEnabled: stockEnabled,
          stockCount: stockCount,
          stockThreshold: stockThreshold,
          stopWhenStockDepleted: stopWhenStockDepleted,
          consumptionPerDose: consumptionPerDose,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('create_medicine', e));
    }
  }

  @override
  Future<Result<void>> updateMedicine(
    String id, {
    String? name,
    String? dosageNote,
    bool? stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool? stopWhenStockDepleted,
    int? consumptionPerDose,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicinesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicinesTableCompanion(
              name: name == null ? const Value.absent() : Value(name),
              dosageNote: dosageNote == null
                  ? const Value.absent()
                  : Value(dosageNote),
              stockEnabled: stockEnabled == null
                  ? const Value.absent()
                  : Value(stockEnabled),
              stockCount: stockCount == null
                  ? const Value.absent()
                  : Value(stockCount),
              stockThreshold: stockThreshold == null
                  ? const Value.absent()
                  : Value(stockThreshold),
              stopWhenStockDepleted: stopWhenStockDepleted == null
                  ? const Value.absent()
                  : Value(stopWhenStockDepleted),
              consumptionPerDose: consumptionPerDose == null
                  ? const Value.absent()
                  : Value(consumptionPerDose),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('Medicine', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_medicine', e));
    }
  }

  @override
  Future<Result<void>> archiveMedicine(String id) => _setArchived(id, true);

  @override
  Future<Result<void>> restoreMedicine(String id) => _setArchived(id, false);

  Future<Result<void>> _setArchived(String id, bool archived) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicinesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicinesTableCompanion(
              archivedAt: Value(archived ? now : null),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('Medicine', id));
      }
      if (archived) {
        // FR-M-10: archiving stops generating doses/notifications. Mirrors
        // updateSchedule's FR-M-09 cascade — delete this medicine's still-
        // upcoming doses at/after now (across every schedule) so no
        // pre-materialized future dose keeps notifying; done/skipped/past
        // rows are untouched and remain in history/adherence stats.
        await (_db.update(_db.medicineDosesTable)..where(
              (t) =>
                  t.medicineId.equals(id) &
                  t.status.equals('upcoming') &
                  t.scheduledFor.isBiggerOrEqualValue(now),
            ))
            .write(MedicineDosesTableCompanion(deletedAt: Value(now)));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('archive_medicine', e));
    }
  }

  @override
  Stream<List<MedicineSchedule>> watchSchedules(String medicineId) {
    final query = _db.select(_db.medicineSchedulesTable)
      ..where((t) => t.medicineId.equals(medicineId) & t.deletedAt.isNull());
    return query.watch().map(
      (rows) => rows.map(_scheduleFromRow).toList(growable: false),
    );
  }

  @override
  Future<Result<MedicineSchedule>> createSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    try {
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.medicineSchedulesTable)
          .insert(
            MedicineSchedulesTableCompanion.insert(
              id: id,
              medicineId: medicineId,
              frequencyType: rule.toDbFrequencyType(),
              intervalDays: Value(rule.toDbIntervalDays()),
              weekdaysMask: Value(rule.toDbWeekdaysMask()),
              timesOfDay: jsonEncode(
                rule.toDbTimesOfDay().map((t) => t.format()).toList(),
              ),
              startDate: startDate.toIso(),
              endDate: Value(endDate?.toIso()),
              graceWindowMinutes: Value(graceWindowMinutes),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return Result.success(
        MedicineSchedule(
          id: id,
          medicineId: medicineId,
          rule: rule,
          startDate: startDate,
          endDate: endDate,
          graceWindowMinutes: graceWindowMinutes,
          createdAt: now,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('create_schedule', e));
    }
  }

  @override
  Future<Result<void>> updateSchedule(
    String id, {
    RepeatRule? rule,
    LocalDate? startDate,
    LocalDate? endDate,
    int? graceWindowMinutes,
  }) async {
    try {
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicineSchedulesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicineSchedulesTableCompanion(
              frequencyType: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbFrequencyType()),
              intervalDays: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbIntervalDays()),
              weekdaysMask: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbWeekdaysMask()),
              timesOfDay: rule == null
                  ? const Value.absent()
                  : Value(
                      jsonEncode(
                        rule.toDbTimesOfDay().map((t) => t.format()).toList(),
                      ),
                    ),
              startDate: startDate == null
                  ? const Value.absent()
                  : Value(startDate.toIso()),
              endDate: endDate == null
                  ? const Value.absent()
                  : Value(endDate.toIso()),
              graceWindowMinutes: graceWindowMinutes == null
                  ? const Value.absent()
                  : Value(graceWindowMinutes),
              updatedAt: Value(nowMillis),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('MedicineSchedule', id));
      }
      // FR-M-09: edits apply to future doses only. Delete this schedule's
      // still-upcoming doses at/after now so the next `materializeDoses`
      // pass regenerates them from the updated rule; done/skipped/past
      // rows are untouched.
      await (_db.update(_db.medicineDosesTable)..where(
            (t) =>
                t.scheduleId.equals(id) &
                t.status.equals('upcoming') &
                t.scheduledFor.isBiggerOrEqualValue(nowMillis),
          ))
          .write(MedicineDosesTableCompanion(deletedAt: Value(nowMillis)));
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_schedule', e));
    }
  }

  @override
  Future<Result<void>> endSchedule(String id, {required LocalDate endDate}) =>
      updateSchedule(id, endDate: endDate);

  @override
  Future<void> materializeDoses(DateTime now) async {
    final windowStart = localDayKey(now);
    final windowEnd = windowStart.addDays(_materializationWindowDays);

    final medicines =
        await (_db.select(
          _db.medicinesTable,
        )..where((t) => t.deletedAt.isNull())).get().then(
          (rows) => rows.map(_medicineFromRow).toList(),
        );
    final schedules =
        await (_db.select(
          _db.medicineSchedulesTable,
        )..where((t) => t.deletedAt.isNull())).get().then(
          (rows) => rows.map(_scheduleFromRow).toList(),
        );
    final existingDoses = await dosesInRange(windowStart, windowEnd);

    final planned = planDoseMaterialization(
      medicines: medicines,
      schedules: schedules,
      existingDoses: existingDoses,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    if (planned.isEmpty) return;

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final dose in planned) {
        batch.insert(
          _db.medicineDosesTable,
          MedicineDosesTableCompanion.insert(
            id: generateId(),
            medicineId: dose.medicineId,
            scheduleId: dose.scheduleId,
            scheduledFor: dose.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: 'upcoming',
            graceWindowMinutes: dose.graceWindowMinutes,
            createdAt: nowMillis,
            updatedAt: nowMillis,
          ),
        );
      }
    });
  }

  @override
  Stream<List<MedicineDose>> watchDosesForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    final query = _db.select(_db.medicineDosesTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.scheduledFor.isBiggerOrEqualValue(
              range.startUtc.millisecondsSinceEpoch,
            ) &
            t.scheduledFor.isSmallerThanValue(
              range.endUtc.millisecondsSinceEpoch,
            ),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]);
    return query.watch().map(
      (rows) => rows.map(_doseFromRow).toList(growable: false),
    );
  }

  @override
  Future<List<MedicineDose>> dosesInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    final rows =
        await (_db.select(_db.medicineDosesTable)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.scheduledFor.isBiggerOrEqualValue(
                    startUtc.millisecondsSinceEpoch,
                  ) &
                  t.scheduledFor.isSmallerThanValue(
                    endUtc.millisecondsSinceEpoch,
                  ),
            ))
            .get();
    return rows.map(_doseFromRow).toList(growable: false);
  }

  @override
  Future<Result<void>> markDoseDone(
    String doseId, {
    required bool fromOtherSource,
  }) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final adjustment = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: fromOtherSource,
      );
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;

      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('done'),
          statusChangedAt: Value(nowMillis),
          stockDeltaApplied: Value(adjustment.stockDelta),
          updatedAt: Value(nowMillis),
        ),
      );
      await _applyStockAdjustment(
        medicine: medicine,
        dose: dose,
        newStockCount: adjustment.newStockCount,
        stockDelta: adjustment.stockDelta,
        writesEvent: adjustment.writesEvent,
        reason: MedicineStockEventReason.doseTaken,
        occurredAt: now,
      );
    },
  );

  @override
  Future<Result<void>> markDoseSkipped(String doseId) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('skipped'),
          statusChangedAt: Value(nowMillis),
          updatedAt: Value(nowMillis),
        ),
      );
    },
  );

  @override
  Future<Result<void>> undoDose(String doseId) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final adjustment = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: dose.stockDeltaApplied,
      );
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('upcoming'),
          statusChangedAt: const Value(null),
          stockDeltaApplied: const Value(0),
          updatedAt: Value(nowMillis),
        ),
      );
      if (adjustment.stockDelta != 0) {
        await _applyStockAdjustment(
          medicine: medicine,
          dose: dose,
          newStockCount: adjustment.newStockCount,
          stockDelta: adjustment.stockDelta,
          writesEvent: true,
          reason: MedicineStockEventReason.doseUndone,
          occurredAt: now,
        );
      }
    },
  );

  @override
  Future<Result<void>> updateDoseNotes(String doseId, String? notes) =>
      _resolveDose(
        doseId,
        resolve: (medicine, dose) async {
          final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
          await (_db.update(
            _db.medicineDosesTable,
          )..where((t) => t.id.equals(dose.id))).write(
            MedicineDosesTableCompanion(
              notes: Value(notes),
              updatedAt: Value(nowMillis),
            ),
          );
        },
      );

  /// Shared "look up medicine+dose, run [resolve], wrap in `Result`"
  /// skeleton for the three dose-action methods above.
  Future<Result<void>> _resolveDose(
    String doseId, {
    required Future<void> Function(Medicine medicine, MedicineDose dose)
    resolve,
  }) async {
    try {
      final doseRow =
          await (_db.select(_db.medicineDosesTable)..where(
                (t) => t.id.equals(doseId) & t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (doseRow == null) {
        return Result.failure(AppException.notFound('MedicineDose', doseId));
      }
      final dose = _doseFromRow(doseRow);
      final medicine = await medicineById(dose.medicineId);
      if (medicine == null) {
        return Result.failure(
          AppException.notFound('Medicine', dose.medicineId),
        );
      }
      await resolve(medicine, dose);
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('resolve_dose_action', e));
    }
  }

  /// Persists a stock count change onto `medicines` (with low-stock
  /// crossing detection, FR-M-04's "notify once per crossing") and,
  /// when [writesEvent], appends the matching ledger row.
  Future<void> _applyStockAdjustment({
    required Medicine medicine,
    required MedicineDose dose,
    required int newStockCount,
    required int stockDelta,
    required bool writesEvent,
    required MedicineStockEventReason reason,
    required DateTime occurredAt,
  }) async {
    final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
    final isAtOrBelowThreshold =
        medicine.stockThreshold != null &&
        newStockCount <= medicine.stockThreshold!;
    final isAboveThreshold =
        medicine.stockThreshold != null &&
        newStockCount > medicine.stockThreshold!;
    // `lowStockNotifiedAt == null` alone gives "once per crossing": it's
    // cleared below once stock rises back above threshold, so this also
    // correctly flags a medicine that started at/below threshold at
    // creation (no prior "was above" transition to detect). Gated on
    // `stockEnabled` — a medicine with stock tracking off must never be
    // flagged, even if it carries a stale threshold/count from before
    // tracking was disabled.
    final justCrossed =
        medicine.stockEnabled &&
        isAtOrBelowThreshold &&
        medicine.lowStockNotifiedAt == null;
    // Mirrors `refillStock`'s clear condition — stock rising back above
    // threshold clears a stale flag regardless of which write path
    // (refill or an undo that restores stock) caused the rise.
    final justCleared = isAboveThreshold && medicine.lowStockNotifiedAt != null;

    await (_db.update(
      _db.medicinesTable,
    )..where((t) => t.id.equals(medicine.id))).write(
      MedicinesTableCompanion(
        stockCount: Value(newStockCount),
        lowStockNotifiedAt: justCrossed
            ? Value(nowMillis)
            : justCleared
            ? const Value(null)
            : const Value.absent(),
        updatedAt: Value(nowMillis),
      ),
    );

    if (writesEvent) {
      await _db
          .into(_db.medicineStockEventsTable)
          .insert(
            MedicineStockEventsTableCompanion.insert(
              id: generateId(),
              medicineId: medicine.id,
              doseId: Value(dose.id),
              delta: stockDelta,
              reason: reason.toDb(),
              occurredAt: occurredAt.toUtc().millisecondsSinceEpoch,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
    }
  }

  @override
  Future<Result<void>> refillStock(String medicineId, int amount) async {
    try {
      final medicine = await medicineById(medicineId);
      if (medicine == null) {
        return Result.failure(AppException.notFound('Medicine', medicineId));
      }
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final newCount = (medicine.stockCount ?? 0) + amount;
      final clearsLowStock =
          medicine.stockThreshold == null ||
          newCount > medicine.stockThreshold!;

      await (_db.update(
        _db.medicinesTable,
      )..where((t) => t.id.equals(medicineId))).write(
        MedicinesTableCompanion(
          stockCount: Value(newCount),
          lowStockNotifiedAt: clearsLowStock
              ? const Value(null)
              : const Value.absent(),
          updatedAt: Value(nowMillis),
        ),
      );
      await _db
          .into(_db.medicineStockEventsTable)
          .insert(
            MedicineStockEventsTableCompanion.insert(
              id: generateId(),
              medicineId: medicineId,
              delta: amount,
              reason: MedicineStockEventReason.manualRefill.toDb(),
              occurredAt: now.toUtc().millisecondsSinceEpoch,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('refill_stock', e));
    }
  }

  @override
  Future<List<Medicine>> medicinesNeedingLowStockAlert() async {
    final rows =
        await (_db.select(_db.medicinesTable)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.archivedAt.isNull() &
                  t.lowStockNotifiedAt.isNotNull(),
            ))
            .get();
    return rows.map(_medicineFromRow).toList(growable: false);
  }

  @override
  Future<List<Medicine>> allMedicines() async {
    final rows = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_medicineFromRow).toList(growable: false);
  }

  @override
  Future<List<MedicineSchedule>> allSchedules() async {
    final rows = await (_db.select(
      _db.medicineSchedulesTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_scheduleFromRow).toList(growable: false);
  }

  @override
  Future<List<MedicineDose>> allDoses() async {
    final rows = await (_db.select(
      _db.medicineDosesTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_doseFromRow).toList(growable: false);
  }

  @override
  Future<List<MedicineStockEvent>> allStockEvents() async {
    final rows = await (_db.select(
      _db.medicineStockEventsTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_stockEventFromRow).toList(growable: false);
  }

  @override
  Future<String> restoreDose(MedicineDose dose) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final id = generateId();
    await _db
        .into(_db.medicineDosesTable)
        .insert(
          MedicineDosesTableCompanion.insert(
            id: id,
            medicineId: dose.medicineId,
            scheduleId: dose.scheduleId,
            scheduledFor: dose.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: dose.storedStatus.name,
            graceWindowMinutes: dose.graceWindowMinutes,
            statusChangedAt: Value(
              dose.statusChangedAt?.toUtc().millisecondsSinceEpoch,
            ),
            stockDeltaApplied: Value(dose.stockDeltaApplied),
            notes: Value(dose.notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  @override
  Future<void> restoreStockEvent(MedicineStockEvent event) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.medicineStockEventsTable)
        .insert(
          MedicineStockEventsTableCompanion.insert(
            id: generateId(),
            medicineId: event.medicineId,
            doseId: Value(event.doseId),
            delta: event.delta,
            reason: event.reason.toDb(),
            occurredAt: event.occurredAt.toUtc().millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.medicineStockEventsTable).go();
    await _db.delete(_db.medicineDosesTable).go();
    await _db.delete(_db.medicineSchedulesTable).go();
    await _db.delete(_db.medicinesTable).go();
  }

  Medicine _medicineFromRow(MedicineRow row) => Medicine(
    id: row.id,
    name: row.name,
    dosageNote: row.dosageNote,
    stockEnabled: row.stockEnabled,
    stockCount: row.stockCount,
    stockThreshold: row.stockThreshold,
    stopWhenStockDepleted: row.stopWhenStockDepleted,
    consumptionPerDose: row.consumptionPerDose,
    lowStockNotifiedAt: row.lowStockNotifiedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.lowStockNotifiedAt!,
            isUtc: true,
          ),
    archivedAt: row.archivedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.archivedAt!, isUtc: true),
  );

  MedicineSchedule _scheduleFromRow(MedicineScheduleRow row) =>
      MedicineSchedule(
        id: row.id,
        medicineId: row.medicineId,
        rule: RepeatRuleDb.fromDb(
          frequencyType: row.frequencyType,
          intervalDays: row.intervalDays,
          weekdaysMask: row.weekdaysMask,
          timesOfDayJson: row.timesOfDay,
        ),
        startDate: LocalDate.parse(row.startDate),
        endDate: row.endDate == null ? null : LocalDate.parse(row.endDate!),
        graceWindowMinutes: row.graceWindowMinutes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
      );

  MedicineDose _doseFromRow(MedicineDoseRow row) => MedicineDose(
    id: row.id,
    medicineId: row.medicineId,
    scheduleId: row.scheduleId,
    scheduledFor: DateTime.fromMillisecondsSinceEpoch(
      row.scheduledFor,
      isUtc: true,
    ),
    storedStatus: MedicineDoseStatus.values.byName(row.status),
    statusChangedAt: row.statusChangedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.statusChangedAt!,
            isUtc: true,
          ),
    stockDeltaApplied: row.stockDeltaApplied,
    graceWindowMinutes: row.graceWindowMinutes,
    notes: row.notes,
  );

  MedicineStockEvent _stockEventFromRow(MedicineStockEventRow row) =>
      MedicineStockEvent(
        id: row.id,
        medicineId: row.medicineId,
        doseId: row.doseId,
        delta: row.delta,
        reason: MedicineStockEventReasonDb.fromDb(row.reason),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          row.occurredAt,
          isUtc: true,
        ),
      );
}

/// `RepeatRule` <-> DB column mapping, by explicit literal (same
/// convention as `WaterEntrySourceDb`).
extension RepeatRuleDb on RepeatRule {
  /// The stored `frequency_type` string.
  String toDbFrequencyType() => switch (this) {
    FixedDailyRule() => 'fixed_daily',
    EveryNDaysRule() => 'every_n_days',
    WeekdaySetRule() => 'weekday_set',
    PrnRule() => 'prn',
  };

  /// `interval_days`, only non-null for `every_n_days`.
  int? toDbIntervalDays() => switch (this) {
    EveryNDaysRule(:final intervalDays) => intervalDays,
    _ => null,
  };

  /// `weekdays_mask`, only non-null for `weekday_set`.
  int? toDbWeekdaysMask() => switch (this) {
    WeekdaySetRule(:final weekdaysMask) => weekdaysMask,
    _ => null,
  };

  /// `times_of_day`, empty for `prn`.
  List<LocalTime> toDbTimesOfDay() => switch (this) {
    FixedDailyRule(:final timesOfDay) => timesOfDay,
    EveryNDaysRule(:final timesOfDay) => timesOfDay,
    WeekdaySetRule(:final timesOfDay) => timesOfDay,
    PrnRule() => const [],
  };

  /// Reconstructs a [RepeatRule] from its stored columns.
  static RepeatRule fromDb({
    required String frequencyType,
    required int? intervalDays,
    required int? weekdaysMask,
    required String timesOfDayJson,
  }) {
    final times = (jsonDecode(timesOfDayJson) as List<dynamic>)
        .cast<String>()
        .map(LocalTime.parse)
        .toList();
    return switch (frequencyType) {
      'every_n_days' => RepeatRule.everyNDays(
        intervalDays: intervalDays!,
        timesOfDay: times,
      ),
      'weekday_set' => RepeatRule.weekdaySet(
        weekdaysMask: weekdaysMask!,
        timesOfDay: times,
      ),
      'prn' => const RepeatRule.prn(),
      _ => RepeatRule.fixedDaily(timesOfDay: times),
    };
  }
}

/// `MedicineStockEventReason` <-> DB string mapping.
extension MedicineStockEventReasonDb on MedicineStockEventReason {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    MedicineStockEventReason.doseTaken => 'dose_taken',
    MedicineStockEventReason.manualRefill => 'manual_refill',
    MedicineStockEventReason.manualAdjustment => 'manual_adjustment',
    MedicineStockEventReason.doseUndone => 'dose_undone',
  };

  /// Parses a stored DB string back to [MedicineStockEventReason].
  static MedicineStockEventReason fromDb(String value) => switch (value) {
    'manual_refill' => MedicineStockEventReason.manualRefill,
    'manual_adjustment' => MedicineStockEventReason.manualAdjustment,
    'dose_undone' => MedicineStockEventReason.doseUndone,
    _ => MedicineStockEventReason.doseTaken,
  };
}
