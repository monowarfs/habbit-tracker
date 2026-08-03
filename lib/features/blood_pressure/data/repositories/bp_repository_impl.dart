import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/classify_bp_use_case.dart';

/// Drift-backed [BpRepository].
class BpRepositoryImpl implements BpRepository {
  /// Creates a repository backed by [_db].
  BpRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<BpLog>> watchLogsForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    return _watchLogsBetween(range.startUtc, range.endUtc);
  }

  @override
  Stream<List<BpLog>> watchLogsInRange(LocalDate start, LocalDate end) {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    return _watchLogsBetween(startUtc, endUtc);
  }

  Stream<List<BpLog>> _watchLogsBetween(DateTime startUtc, DateTime endUtc) {
    final query = _db.select(_db.bpLogsTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.loggedAt.isBiggerOrEqualValue(startUtc.millisecondsSinceEpoch) &
            t.loggedAt.isSmallerThanValue(endUtc.millisecondsSinceEpoch),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    return query.watch().map(
      (rows) => rows.map(_logFromRow).toList(growable: false),
    );
  }

  @override
  Future<BpLog?> logById(String id) async {
    final row = await (_db.select(
      _db.bpLogsTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _logFromRow(row);
  }

  @override
  Future<List<BpLog>> allLogs() async {
    final query = _db.select(_db.bpLogsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    final rows = await query.get();
    return rows.map(_logFromRow).toList(growable: false);
  }

  @override
  Future<Result<BpLog>> addLog({
    required int systolic,
    required int diastolic,
    required DateTime loggedAt,
    int? pulse,
    String? notes,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      final classification = const ClassifyBpUseCase().execute(
        systolic: systolic,
        diastolic: diastolic,
      );
      await _db
          .into(_db.bpLogsTable)
          .insert(
            BpLogsTableCompanion.insert(
              id: id,
              systolic: systolic,
              diastolic: diastolic,
              loggedAt: loggedAt.toUtc().millisecondsSinceEpoch,
              classification: classification.toDb(),
              pulse: Value(pulse),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        BpLog(
          id: id,
          systolic: systolic,
          diastolic: diastolic,
          loggedAt: loggedAt,
          classification: classification,
          pulse: pulse,
          notes: notes,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('add_bp_log', e));
    }
  }

  @override
  Future<Result<void>> deleteLog(String id) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(_db.bpLogsTable)..where(
                (t) => t.id.equals(id) & t.deletedAt.isNull(),
              ))
              .write(
                BpLogsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('BpLog', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('delete_bp_log', e));
    }
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.bpLogsTable).go();
  }

  BpLog _logFromRow(BpLogRow row) => BpLog(
    id: row.id,
    systolic: row.systolic,
    diastolic: row.diastolic,
    loggedAt: DateTime.fromMillisecondsSinceEpoch(row.loggedAt, isUtc: true),
    classification: BpClassificationDb.fromDb(row.classification),
    pulse: row.pulse,
    notes: row.notes,
  );
}

/// `BpClassification` <-> DB string mapping, by explicit literal
/// (`technical/data-models.md`'s type-mapping convention).
extension BpClassificationDb on BpClassification {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    BpClassification.normal => 'normal',
    BpClassification.elevated => 'elevated',
    BpClassification.hypertension1 => 'hypertension1',
    BpClassification.hypertension2 => 'hypertension2',
    BpClassification.hypertensionCrisis => 'hypertension_crisis',
  };

  /// Parses a stored DB string back to [BpClassification]. Every case is
  /// matched explicitly — an unrecognized string throws rather than
  /// silently defaulting to a severity level, since defaulting corrupted
  /// or unexpected data to `hypertensionCrisis` (the most alarming label)
  /// would be actively misleading for a health metric.
  static BpClassification fromDb(String value) => switch (value) {
    'normal' => BpClassification.normal,
    'elevated' => BpClassification.elevated,
    'hypertension1' => BpClassification.hypertension1,
    'hypertension2' => BpClassification.hypertension2,
    'hypertension_crisis' => BpClassification.hypertensionCrisis,
    _ => throw StateError('Unknown BpClassification DB value: $value'),
  };
}
