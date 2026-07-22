import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/plan_prayer_materialization.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/qadha_adjustment.dart';

const _singletonId = 'singleton';
const _materializationWindowDays = 30;

/// Drift-backed [PrayerRepository]. No DAO — same precedent as Water/
/// Medicine, one caller.
class PrayerRepositoryImpl implements PrayerRepository {
  /// Creates a repository backed by [_db]. [defaultCalculationMethod]/
  /// [defaultAsrMethod] resolve the values a first-ever launch seeds the
  /// singleton row with — default to a device-locale heuristic (D-06:
  /// Bangladesh -> Karachi/Hanafi, else MWL/Standard), overridable for
  /// tests, same pattern as `SettingsRepositoryImpl`'s `defaultLocale`.
  PrayerRepositoryImpl(
    this._db, {
    CalculationMethod Function()? defaultCalculationMethod,
    AsrMethod Function()? defaultAsrMethod,
  }) : _defaultCalculationMethod =
           defaultCalculationMethod ?? _systemDefaultCalculationMethod,
       _defaultAsrMethod = defaultAsrMethod ?? _systemDefaultAsrMethod;

  final AppDatabase _db;
  final CalculationMethod Function() _defaultCalculationMethod;
  final AsrMethod Function() _defaultAsrMethod;

  static bool _isBangladeshLocale() =>
      PlatformDispatcher.instance.locale.countryCode == 'BD';

  static CalculationMethod _systemDefaultCalculationMethod() =>
      _isBangladeshLocale() ? CalculationMethod.karachi : CalculationMethod.mwl;

  static AsrMethod _systemDefaultAsrMethod() =>
      _isBangladeshLocale() ? AsrMethod.hanafi : AsrMethod.standard;

  @override
  Stream<PrayerSettings> watchSettings() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      final query = _db.select(_db.prayerSettingsTable)
        ..where((t) => t.id.equals(_singletonId));
      return query.watchSingle().map(_settingsFromRow);
    });
  }

  Future<void> _ensureSeeded() async {
    final existing = await (_db.select(
      _db.prayerSettingsTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing == null) {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await _db
          .into(_db.prayerSettingsTable)
          .insertOnConflictUpdate(
            PrayerSettingsTableCompanion.insert(
              id: _singletonId,
              calculationMethod: _defaultCalculationMethod().toDb(),
              asrMethod: _defaultAsrMethod().toDb(),
              locationMode: LocationMode.auto.toDb(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await _ensureQadhaCountersSeeded();
  }

  Future<void> _ensureQadhaCountersSeeded() async {
    final existing = await _db.select(_db.prayerQadhaCountersTable).get();
    final existingNames = existing.map((r) => r.prayerName).toSet();
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    for (final name in PrayerName.values) {
      if (existingNames.contains(name.toDb())) continue;
      await _db
          .into(_db.prayerQadhaCountersTable)
          .insertOnConflictUpdate(
            PrayerQadhaCountersTableCompanion.insert(
              id: generateId(),
              prayerName: name.toDb(),
              updatedAt: now,
            ),
          );
    }
  }

  @override
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
  }) async {
    try {
      await _ensureSeeded();
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerSettingsTable,
      )..where((t) => t.id.equals(_singletonId))).write(
        PrayerSettingsTableCompanion(
          calculationMethod: calculationMethod == null
              ? const Value.absent()
              : Value(calculationMethod.toDb()),
          asrMethod: asrMethod == null
              ? const Value.absent()
              : Value(asrMethod.toDb()),
          observesJumuah: observesJumuah == null
              ? const Value.absent()
              : Value(observesJumuah),
          locationMode: locationMode == null
              ? const Value.absent()
              : Value(locationMode.toDb()),
          manualLatitude: manualLatitude == null
              ? const Value.absent()
              : Value(manualLatitude),
          manualLongitude: manualLongitude == null
              ? const Value.absent()
              : Value(manualLongitude),
          manualTimezone: manualTimezone == null
              ? const Value.absent()
              : Value(manualTimezone),
          ishaDayRolloverTime: ishaDayRolloverTime == null
              ? const Value.absent()
              : Value(ishaDayRolloverTime.format()),
          notificationsEnabled: notificationsEnabled == null
              ? const Value.absent()
              : Value(notificationsEnabled),
          preReminderEnabled: preReminderEnabled == null
              ? const Value.absent()
              : Value(preReminderEnabled),
          preReminderOffsetMinutes: preReminderOffsetMinutes == null
              ? const Value.absent()
              : Value(preReminderOffsetMinutes),
          updatedAt: Value(nowMillis),
        ),
      );

      // FR-P-01: a location/method change recalculates all *future* prayer
      // times immediately — soft-delete future `upcoming` records so the
      // next materialization pass regenerates them (this plan's
      // refinements section, #3). Past/prayed/missed records are never
      // touched.
      final locationOrMethodChanged =
          calculationMethod != null ||
          asrMethod != null ||
          locationMode != null ||
          manualLatitude != null ||
          manualLongitude != null ||
          manualTimezone != null;
      if (locationOrMethodChanged) {
        await (_db.update(_db.prayerRecordsTable)..where(
              (t) =>
                  t.status.equals('upcoming') &
                  t.scheduledFor.isBiggerThanValue(
                    now.toUtc().millisecondsSinceEpoch,
                  ) &
                  t.deletedAt.isNull(),
            ))
            .write(
              PrayerRecordsTableCompanion(
                deletedAt: Value(nowMillis),
                updatedAt: Value(nowMillis),
              ),
            );
      }

      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_prayer_settings', e));
    }
  }

  @override
  Stream<List<PrayerQadhaCounter>> watchQadhaCounters() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      return _db
          .select(_db.prayerQadhaCountersTable)
          .watch()
          .map(
            (rows) => rows.map(_qadhaFromRow).toList(growable: false),
          );
    });
  }

  @override
  Future<Result<void>> markQadhaMakeup(PrayerName prayerName) async {
    try {
      await _ensureSeeded();
      final row =
          await (_db.select(
                _db.prayerQadhaCountersTable,
              )..where((t) => t.prayerName.equals(prayerName.toDb())))
              .getSingleOrNull();
      if (row == null) {
        return Result.failure(
          AppException.notFound('PrayerQadhaCounter', prayerName.toDb()),
        );
      }
      final newCount = applyQadhaMakeup(_qadhaFromRow(row));
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerQadhaCountersTable,
      )..where((t) => t.id.equals(row.id))).write(
        PrayerQadhaCountersTableCompanion(
          count: Value(newCount),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('mark_qadha_makeup', e));
    }
  }

  @override
  Future<Result<void>> setQadhaBalance(PrayerName prayerName, int count) async {
    try {
      await _ensureSeeded();
      final clamped = count < 0 ? 0 : count;
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.prayerQadhaCountersTable,
          )..where((t) => t.prayerName.equals(prayerName.toDb()))).write(
            PrayerQadhaCountersTableCompanion(
              count: Value(clamped),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(
          AppException.notFound('PrayerQadhaCounter', prayerName.toDb()),
        );
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('set_qadha_balance', e));
    }
  }

  @override
  Future<void> materializeRecords(
    DateTime now,
    ResolvedLocation location,
  ) async {
    final windowStart = LocalDate.fromDateTime(now.toUtc());
    final windowEnd = windowStart.addDays(_materializationWindowDays - 1);
    final settings = await watchSettings().first;
    final existing = await recordsInRange(windowStart, windowEnd);

    final planned = planPrayerMaterialization(
      settings: settings,
      location: location,
      existingRecords: existing,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    if (planned.isEmpty) return;

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final record in planned) {
        batch.insert(
          _db.prayerRecordsTable,
          PrayerRecordsTableCompanion.insert(
            id: generateId(),
            prayerDate: record.prayerDate.toIso(),
            prayerName: record.prayerName.toDb(),
            scheduledFor: record.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: 'upcoming',
            createdAt: nowMillis,
            updatedAt: nowMillis,
          ),
          // `(prayerDate, prayerName)` is a unique key, and a settings
          // change (see `updateSettings`) soft-deletes future `upcoming`
          // rows without removing them — so a plain `insertOrIgnore`
          // silently no-ops against that still-occupied, soft-deleted
          // slot and the day never regenerates. `insertOrReplace` revives
          // it with the freshly computed row (undeleted, new id).
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> sweepMissedPrayers(
    DateTime now,
    ResolvedLocation location,
  ) async {
    final today = LocalDate.fromDateTime(
      now.toUtc(),
    );
    final scanStart = today.addDays(-1);
    final records = await recordsInRange(scanStart, today);
    if (records.isEmpty) return;

    final settings = await watchSettings().first;
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      byDay.putIfAbsent(record.prayerDate, () => []).add(record);
    }

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    for (final dayRecords in byDay.values) {
      dayRecords.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      for (final record in dayRecords) {
        if (record.storedStatus != PrayerStatus.upcoming) continue;
        final cutoff = cutoffForPrayer(
          record: record,
          sameDayRecordsSorted: dayRecords,
          ishaDayRolloverTime: settings.ishaDayRolloverTime,
          ianaTimezone: location.ianaTimezone,
        );
        if (!now.isAfter(cutoff)) continue;
        await (_db.update(
          _db.prayerRecordsTable,
        )..where((t) => t.id.equals(record.id))).write(
          PrayerRecordsTableCompanion(
            status: const Value('missed'),
            statusChangedAt: Value(nowMillis),
            updatedAt: Value(nowMillis),
          ),
        );
        await _bumpQadha(record.prayerName, now);
      }
    }
  }

  Future<void> _bumpQadha(PrayerName prayerName, DateTime now) async {
    final row = await (_db.select(
      _db.prayerQadhaCountersTable,
    )..where((t) => t.prayerName.equals(prayerName.toDb()))).getSingleOrNull();
    if (row == null) return;
    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.prayerQadhaCountersTable,
    )..where((t) => t.id.equals(row.id))).write(
      PrayerQadhaCountersTableCompanion(
        count: Value(row.count + 1),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  @override
  Stream<List<PrayerRecord>> watchRecordsForDay(LocalDate day) {
    final query = _db.select(_db.prayerRecordsTable)
      ..where((t) => t.deletedAt.isNull() & t.prayerDate.equals(day.toIso()))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]);
    return query.watch().map(
      (rows) => rows.map(_recordFromRow).toList(growable: false),
    );
  }

  @override
  Future<List<PrayerRecord>> recordsInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    final rows =
        await (_db.select(_db.prayerRecordsTable)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.prayerDate.isBiggerOrEqualValue(start.toIso()) &
                  t.prayerDate.isSmallerOrEqualValue(end.toIso()),
            ))
            .get();
    return rows.map(_recordFromRow).toList(growable: false);
  }

  @override
  Future<Result<void>> markPrayed(String recordId) => _resolveRecord(
    recordId,
    guard: (record) => record.storedStatus != PrayerStatus.missed,
    apply: (record, nowMillis) => PrayerRecordsTableCompanion(
      status: const Value('prayed'),
      statusChangedAt: Value(nowMillis),
      updatedAt: Value(nowMillis),
    ),
  );

  @override
  Future<Result<void>> unmarkPrayed(String recordId) => _resolveRecord(
    recordId,
    guard: (record) => record.storedStatus == PrayerStatus.prayed,
    apply: (record, nowMillis) => PrayerRecordsTableCompanion(
      status: const Value('upcoming'),
      statusChangedAt: const Value(null),
      updatedAt: Value(nowMillis),
    ),
  );

  @override
  Future<Result<void>> markMissedBySkip(String recordId) async {
    final result = await _resolveRecord(
      recordId,
      guard: (record) => record.storedStatus == PrayerStatus.upcoming,
      apply: (record, nowMillis) => PrayerRecordsTableCompanion(
        status: const Value('missed'),
        statusChangedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
    if (result case Success()) {
      final record = await _recordById(recordId);
      if (record != null) await _bumpQadha(record.prayerName, clock.now());
    }
    return result;
  }

  @override
  Future<Result<void>> updatePrayerNotes(String recordId, String? notes) =>
      _resolveRecord(
        recordId,
        guard: (_) => true,
        apply: (record, nowMillis) => PrayerRecordsTableCompanion(
          notes: Value(notes),
          updatedAt: Value(nowMillis),
        ),
      );

  Future<PrayerRecord?> _recordById(String id) async {
    final row = await (_db.select(
      _db.prayerRecordsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _recordFromRow(row);
  }

  /// Shared "look up record, check [guard], apply the write" skeleton for
  /// the three checklist/notification mark-action methods above.
  Future<Result<void>> _resolveRecord(
    String recordId, {
    required bool Function(PrayerRecord record) guard,
    required PrayerRecordsTableCompanion Function(
      PrayerRecord record,
      int nowMillis,
    )
    apply,
  }) async {
    try {
      final record = await _recordById(recordId);
      if (record == null) {
        return Result.failure(AppException.notFound('PrayerRecord', recordId));
      }
      if (!guard(record)) {
        return const Result.failure(
          AppException.validation(
            'storedStatus',
            'Record is not in a valid state for this action',
          ),
        );
      }
      final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.prayerRecordsTable,
      )..where((t) => t.id.equals(recordId))).write(apply(record, nowMillis));
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('resolve_prayer_record_action', e),
      );
    }
  }

  @override
  Future<List<PrayerRecord>> allRecords() async {
    final rows = await (_db.select(
      _db.prayerRecordsTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_recordFromRow).toList(growable: false);
  }

  @override
  Future<List<PrayerQadhaCounter>> allQadhaCounters() async {
    final rows = await _db.select(_db.prayerQadhaCountersTable).get();
    return rows.map(_qadhaFromRow).toList(growable: false);
  }

  @override
  Future<void> restoreRecord(PrayerRecord record) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.prayerRecordsTable)
        .insert(
          PrayerRecordsTableCompanion.insert(
            id: generateId(),
            prayerDate: record.prayerDate.toIso(),
            prayerName: record.prayerName.toDb(),
            scheduledFor: record.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: record.storedStatus.toDb(),
            statusChangedAt: Value(
              record.statusChangedAt?.toUtc().millisecondsSinceEpoch,
            ),
            notes: Value(record.notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.prayerRecordsTable).go();
    await _db.delete(_db.prayerQadhaCountersTable).go();
    await _db.delete(_db.prayerSettingsTable).go();
  }

  PrayerSettings _settingsFromRow(PrayerSettingsRow row) => PrayerSettings(
    id: row.id,
    calculationMethod: CalculationMethodDb.fromDb(row.calculationMethod),
    asrMethod: AsrMethodDb.fromDb(row.asrMethod),
    observesJumuah: row.observesJumuah,
    locationMode: LocationModeDb.fromDb(row.locationMode),
    manualLatitude: row.manualLatitude,
    manualLongitude: row.manualLongitude,
    manualTimezone: row.manualTimezone,
    ishaDayRolloverTime: LocalTime.parse(row.ishaDayRolloverTime),
    notificationsEnabled: row.notificationsEnabled,
    preReminderEnabled: row.preReminderEnabled,
    preReminderOffsetMinutes: row.preReminderOffsetMinutes,
  );

  PrayerQadhaCounter _qadhaFromRow(PrayerQadhaCounterRow row) =>
      PrayerQadhaCounter(
        id: row.id,
        prayerName: PrayerNameDb.fromDb(row.prayerName),
        count: row.count,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
      );

  PrayerRecord _recordFromRow(PrayerRecordRow row) => PrayerRecord(
    id: row.id,
    prayerDate: LocalDate.parse(row.prayerDate),
    prayerName: PrayerNameDb.fromDb(row.prayerName),
    scheduledFor: DateTime.fromMillisecondsSinceEpoch(
      row.scheduledFor,
      isUtc: true,
    ),
    storedStatus: PrayerStatusDb.fromDb(row.status),
    statusChangedAt: row.statusChangedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.statusChangedAt!,
            isUtc: true,
          ),
    notes: row.notes,
  );
}

/// `CalculationMethod` <-> DB string mapping, by explicit literal (never
/// `EnumName.values.byName`, so a stored value never silently breaks if
/// the enum is reordered).
extension CalculationMethodDb on CalculationMethod {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    CalculationMethod.mwl => 'mwl',
    CalculationMethod.isna => 'isna',
    CalculationMethod.egyptian => 'egyptian',
    CalculationMethod.ummAlQura => 'umm_al_qura',
    CalculationMethod.karachi => 'karachi',
    CalculationMethod.tehran => 'tehran',
    CalculationMethod.dubai => 'dubai',
    CalculationMethod.kuwait => 'kuwait',
    CalculationMethod.qatar => 'qatar',
    CalculationMethod.singapore => 'singapore',
  };

  /// Parses a stored DB string back to [CalculationMethod].
  static CalculationMethod fromDb(String value) => switch (value) {
    'isna' => CalculationMethod.isna,
    'egyptian' => CalculationMethod.egyptian,
    'umm_al_qura' => CalculationMethod.ummAlQura,
    'tehran' => CalculationMethod.tehran,
    'dubai' => CalculationMethod.dubai,
    'kuwait' => CalculationMethod.kuwait,
    'qatar' => CalculationMethod.qatar,
    'singapore' => CalculationMethod.singapore,
    'karachi' => CalculationMethod.karachi,
    _ => CalculationMethod.mwl,
  };
}

/// `AsrMethod` <-> DB string mapping, same convention as [CalculationMethodDb].
extension AsrMethodDb on AsrMethod {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    AsrMethod.standard => 'standard',
    AsrMethod.hanafi => 'hanafi',
  };

  /// Parses a stored DB string back to [AsrMethod].
  static AsrMethod fromDb(String value) => switch (value) {
    'hanafi' => AsrMethod.hanafi,
    _ => AsrMethod.standard,
  };
}

/// `LocationMode` <-> DB string mapping, same convention as
/// [CalculationMethodDb].
extension LocationModeDb on LocationMode {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    LocationMode.auto => 'auto',
    LocationMode.manual => 'manual',
  };

  /// Parses a stored DB string back to [LocationMode].
  static LocationMode fromDb(String value) => switch (value) {
    'manual' => LocationMode.manual,
    _ => LocationMode.auto,
  };
}

/// `PrayerName` <-> DB string mapping, same convention as
/// [CalculationMethodDb].
extension PrayerNameDb on PrayerName {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    PrayerName.fajr => 'fajr',
    PrayerName.dhuhr => 'dhuhr',
    PrayerName.asr => 'asr',
    PrayerName.maghrib => 'maghrib',
    PrayerName.isha => 'isha',
  };

  /// Parses a stored DB string back to [PrayerName].
  static PrayerName fromDb(String value) => switch (value) {
    'dhuhr' => PrayerName.dhuhr,
    'asr' => PrayerName.asr,
    'maghrib' => PrayerName.maghrib,
    'isha' => PrayerName.isha,
    _ => PrayerName.fajr,
  };
}

/// `PrayerStatus` <-> DB string mapping, same convention as
/// [CalculationMethodDb].
extension PrayerStatusDb on PrayerStatus {
  /// The stored DB string for this value. `due` is never actually
  /// persisted (FR-P-07) — included here only so the mapping is total.
  String toDb() => switch (this) {
    PrayerStatus.upcoming => 'upcoming',
    PrayerStatus.due => 'due',
    PrayerStatus.prayed => 'prayed',
    PrayerStatus.missed => 'missed',
  };

  /// Parses a stored DB string back to [PrayerStatus].
  static PrayerStatus fromDb(String value) => switch (value) {
    'prayed' => PrayerStatus.prayed,
    'missed' => PrayerStatus.missed,
    'due' => PrayerStatus.due,
    _ => PrayerStatus.upcoming,
  };
}
