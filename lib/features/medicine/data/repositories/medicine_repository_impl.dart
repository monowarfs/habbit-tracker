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
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/plan_dose_materialization.dart';

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

    final medicines = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.deletedAt.isNull())).get().then(
      (rows) => rows.map(_medicineFromRow).toList(),
    );
    final schedules = await (_db.select(
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
  }) {
    throw UnimplementedError('markDoseDone: implemented in Task 11');
  }

  @override
  Future<Result<void>> markDoseSkipped(String doseId) {
    throw UnimplementedError('markDoseSkipped: implemented in Task 11');
  }

  @override
  Future<Result<void>> undoDose(String doseId) {
    throw UnimplementedError('undoDose: implemented in Task 11');
  }

  @override
  Future<Result<void>> refillStock(String medicineId, int amount) {
    throw UnimplementedError('refillStock: implemented in Task 11');
  }

  @override
  Future<List<Medicine>> medicinesNeedingLowStockAlert() {
    throw UnimplementedError(
      'medicinesNeedingLowStockAlert: implemented in Task 11',
    );
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
