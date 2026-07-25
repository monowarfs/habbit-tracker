import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';

const _settingsSingletonId = 'singleton';

/// FR-W-01's documented default.
const _defaultGoalMl = 2000;

/// FR-W-03's documented defaults.
const _defaultQuickAddAmountsMl = [250, 500, 750];

/// Drift-backed [WaterRepository].
class WaterRepositoryImpl implements WaterRepository {
  /// Creates a repository backed by [_db].
  WaterRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<WaterEntry>> watchEntriesForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    return _watchEntriesBetween(range.startUtc, range.endUtc);
  }

  @override
  Stream<List<WaterEntry>> watchEntriesInRange(LocalDate start, LocalDate end) {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    return _watchEntriesBetween(startUtc, endUtc);
  }

  @override
  Future<WaterEntry?> entryById(String id) async {
    final row = await (_db.select(
      _db.waterLogsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _entryFromRow(row);
  }

  Stream<List<WaterEntry>> _watchEntriesBetween(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    final query = _db.select(_db.waterLogsTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.loggedAt.isBiggerOrEqualValue(startUtc.millisecondsSinceEpoch) &
            t.loggedAt.isSmallerThanValue(endUtc.millisecondsSinceEpoch),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    return query.watch().map(
      (rows) => rows.map(_entryFromRow).toList(growable: false),
    );
  }

  @override
  Stream<WaterGoal?> watchCurrentGoal() {
    return Stream.fromFuture(_ensureGoalSeeded()).asyncExpand((_) {
      final query = _db.select(_db.waterGoalsTable)
        ..where((t) => t.deletedAt.isNull() & t.archivedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
        ..limit(1);
      return query.watchSingleOrNull().map(
        (row) => row == null ? null : _goalFromRow(row),
      );
    });
  }

  @override
  Future<List<WaterGoal>> allGoals() async {
    await _ensureGoalSeeded();
    final rows = await (_db.select(
      _db.waterGoalsTable,
    )..where((t) => t.deletedAt.isNull() & t.archivedAt.isNull()))
        .get();
    return rows.map(_goalFromRow).toList(growable: false);
  }

  @override
  Future<List<WaterEntry>> allEntries() async {
    final query = _db.select(_db.waterLogsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    final rows = await query.get();
    return rows.map(_entryFromRow).toList(growable: false);
  }

  Future<void> _ensureGoalSeeded() async {
    // Goals are append-only — any number of non-deleted rows can exist
    // over time, so this only checks "does at least one exist" (limit 1),
    // never "is there exactly one" (`getSingleOrNull` without a limit
    // would throw once a second goal has been set).
    final existing =
        await (_db.select(_db.waterGoalsTable)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.waterGoalsTable)
        .insert(
          WaterGoalsTableCompanion.insert(
            id: generateId(),
            goalMl: _defaultGoalMl,
            effectiveFrom: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
    String? notes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.waterLogsTable)
          .insert(
            WaterLogsTableCompanion.insert(
              id: id,
              amountMl: amountMl,
              loggedAt: loggedAt.toUtc().millisecondsSinceEpoch,
              source: source.toDb(),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        WaterEntry(
          id: id,
          amountMl: amountMl,
          loggedAt: loggedAt,
          source: source,
          notes: notes,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('add_water_entry', e));
    }
  }

  @override
  Future<Result<void>> updateEntry(
    String id, {
    int? amountMl,
    DateTime? loggedAt,
    Object? notes = unsetWaterNotes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.waterLogsTable,
          )..where((t) => t.id.equals(id))).write(
            WaterLogsTableCompanion(
              amountMl: amountMl == null
                  ? const Value.absent()
                  : Value(amountMl),
              loggedAt: loggedAt == null
                  ? const Value.absent()
                  : Value(loggedAt.toUtc().millisecondsSinceEpoch),
              notes: identical(notes, unsetWaterNotes)
                  ? const Value.absent()
                  : Value(notes as String?),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('WaterEntry', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_water_entry', e));
    }
  }

  @override
  Future<Result<void>> deleteEntry(String id) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.waterLogsTable,
          )..where((t) => t.id.equals(id))).write(
            WaterLogsTableCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('WaterEntry', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('delete_water_entry', e));
    }
  }

  @override
  Future<Result<void>> setGoal(
    int goalMl, {
    required DateTime effectiveFrom,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await _db
          .into(_db.waterGoalsTable)
          .insert(
            WaterGoalsTableCompanion.insert(
              id: generateId(),
              goalMl: goalMl,
              effectiveFrom: effectiveFrom.toUtc().millisecondsSinceEpoch,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('set_water_goal', e));
    }
  }

  @override
  Stream<WaterSettings> watchSettings() {
    return Stream.fromFuture(_ensureSettingsSeeded()).asyncExpand((_) {
      final query = _db.select(_db.waterSettingsTable)
        ..where((t) => t.id.equals(_settingsSingletonId));
      return query.watchSingle().map(_settingsFromRow);
    });
  }

  Future<void> _ensureSettingsSeeded() async {
    final existing = await (_db.select(
      _db.waterSettingsTable,
    )..where((t) => t.id.equals(_settingsSingletonId))).getSingleOrNull();
    if (existing != null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.waterSettingsTable)
        .insertOnConflictUpdate(
          WaterSettingsTableCompanion.insert(
            id: _settingsSingletonId,
            quickAddAmountsMl: jsonEncode(_defaultQuickAddAmountsMl),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<Result<void>> updateQuickAddAmounts(List<int> amountsMl) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          quickAddAmountsMl: Value(jsonEncode(amountsMl)),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('update_quick_add_amounts', e),
      );
    }
  }

  @override
  Future<Result<void>> updateReminderSettings({
    required bool enabled,
    required int intervalMinutes,
    required LocalTime windowStart,
    required LocalTime windowEnd,
    required Map<int, ({LocalTime start, LocalTime end})> windowOverrides,
  }) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          reminderEnabled: Value(enabled),
          reminderIntervalMinutes: Value(intervalMinutes),
          reminderWindowStart: Value(windowStart.format()),
          reminderWindowEnd: Value(windowEnd.format()),
          reminderWindowOverrides: Value(jsonEncode({
            for (final entry in windowOverrides.entries)
              '${entry.key}': {
                'start': entry.value.start.format(),
                'end': entry.value.end.format(),
              },
          })),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('update_reminder_settings', e),
      );
    }
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.waterLogsTable).go();
    await _db.delete(_db.waterGoalsTable).go();
    await _db.delete(_db.waterSettingsTable).go();
  }

  @override
  Future<Result<void>> updateWeatherNudgeEnabled({
    required bool enabled,
  }) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          weatherNudgeEnabled: Value(enabled),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AppException.storage('update_weather_nudge_enabled', e),
      );
    }
  }

  @override
  Future<Result<void>> updateWeatherCache({
    required double temperatureCelsius,
    required DateTime fetchedAt,
  }) async {
    try {
      await _ensureSettingsSeeded();
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterSettingsTable,
      )..where((t) => t.id.equals(_settingsSingletonId))).write(
        WaterSettingsTableCompanion(
          lastWeatherTemperatureCelsius: Value(temperatureCelsius),
          lastWeatherFetchedAtMillis: Value(
            fetchedAt.toUtc().millisecondsSinceEpoch,
          ),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_weather_cache', e));
    }
  }

  @override
  Future<Result<void>> archiveGoal(String goalId) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterGoalsTable,
      )..where((t) => t.id.equals(goalId))).write(
        WaterGoalsTableCompanion(
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('archive_goal', e));
    }
  }

  @override
  Future<Result<void>> reviveGoal(String goalId) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.waterGoalsTable,
      )..where((t) => t.id.equals(goalId))).write(
        WaterGoalsTableCompanion(
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('revive_goal', e));
    }
  }

  @override
  Future<List<WaterGoal>> archivedGoals() async {
    final rows = await (_db.select(_db.waterGoalsTable)
          ..where(
            (t) => t.archivedAt.isNotNull() & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.archivedAt)]))
        .get();
    return rows.map(_goalFromRow).toList();
  }

  @override
  Future<bool> hasAnyGoals() async {
    final result = await _db.customSelect(
      'SELECT 1 FROM water_goals LIMIT 1',
    ).getSingleOrNull();
    return result != null;
  }

  WaterEntry _entryFromRow(WaterLogRow row) => WaterEntry(
    id: row.id,
    amountMl: row.amountMl,
    loggedAt: DateTime.fromMillisecondsSinceEpoch(row.loggedAt, isUtc: true),
    source: WaterEntrySourceDb.fromDb(row.source),
    notes: row.notes,
  );

  WaterGoal _goalFromRow(WaterGoalRow row) => WaterGoal(
    id: row.id,
    goalMl: row.goalMl,
    effectiveFrom: DateTime.fromMillisecondsSinceEpoch(
      row.effectiveFrom,
      isUtc: true,
    ),
    archivedAt: row.archivedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.archivedAt!, isUtc: true),
  );

  WaterSettings _settingsFromRow(WaterSettingsRow row) => WaterSettings(
    quickAddAmountsMl: (jsonDecode(row.quickAddAmountsMl) as List<dynamic>)
        .cast<int>(),
    reminderEnabled: row.reminderEnabled,
    reminderIntervalMinutes: row.reminderIntervalMinutes,
    reminderWindowStart: LocalTime.parse(row.reminderWindowStart),
    reminderWindowEnd: LocalTime.parse(row.reminderWindowEnd),
    reminderWindowOverrides: {
      for (final entry
          in (jsonDecode(row.reminderWindowOverrides) as Map<String, dynamic>)
              .entries)
        int.parse(entry.key): (
          start: LocalTime.parse((entry.value as Map)['start'] as String),
          end: LocalTime.parse((entry.value as Map)['end'] as String),
        ),
    },
    weatherNudgeEnabled: row.weatherNudgeEnabled,
    lastWeatherTemperatureCelsius: row.lastWeatherTemperatureCelsius,
    lastWeatherFetchedAt: row.lastWeatherFetchedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.lastWeatherFetchedAtMillis!,
            isUtc: true,
          ),
  );
}

/// `WaterEntrySource` <-> DB string mapping, by explicit literal
/// (`technical/data-models.md`'s type-mapping convention).
extension WaterEntrySourceDb on WaterEntrySource {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    WaterEntrySource.quick => 'quick',
    WaterEntrySource.custom => 'custom',
  };

  /// Parses a stored DB string back to [WaterEntrySource].
  static WaterEntrySource fromDb(String value) => switch (value) {
    'quick' => WaterEntrySource.quick,
    _ => WaterEntrySource.custom,
  };
}
