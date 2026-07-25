import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// CRUD for the `pause_ranges` table with overlap validation.
class PauseRepository {
  /// Creates a repository backed by the given database.
  const PauseRepository(this._db);

  final AppDatabase _db;

  /// All pauses for [moduleId], ordered by start date.
  Future<List<PauseRangeRow>> forModule(String moduleId) async {
    return (_db.select(_db.pauseRangesTable)
          ..where((t) => t.moduleId.equals(moduleId))
          ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
        .get();
  }

  /// All active (not yet ended) pauses for [moduleId].
  Future<List<PauseRangeRow>> activeForModule(String moduleId) async {
    final today = LocalDate.fromDateTime(DateTime.now()).toIso();
    return (_db.select(_db.pauseRangesTable)
          ..where(
            (t) =>
                t.moduleId.equals(moduleId) & t.endDate.isBiggerOrEqualValue(today),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
        .get();
  }

  /// Overlapping pauses for [moduleId] that intersect [start, end].
  Future<List<PauseRangeRow>> overlapping({
    required String moduleId,
    required LocalDate start,
    required LocalDate end,
    String? excludeId,
  }) async {
    final startIso = start.toIso();
    final endIso = end.toIso();
    return (_db.select(_db.pauseRangesTable)
          ..where(
            (t) =>
                t.moduleId.equals(moduleId) &
                t.startDate.isSmallerOrEqualValue(endIso) &
                t.endDate.isBiggerOrEqualValue(startIso) &
                (excludeId != null
                    ? t.id.isNotValue(excludeId)
                    : const Constant(true)),
          ))
        .get();
  }

  /// Creates a pause row.
  Future<void> create(PauseRangeRow pause) async {
    await _db.into(_db.pauseRangesTable).insert(pause);
  }

  /// Cancels/deletes a pause by id.
  Future<void> cancel(String id) async {
    await (_db.delete(_db.pauseRangesTable)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// All pauses across all modules.
  Future<List<PauseRangeRow>> all() async {
    return (_db.select(_db.pauseRangesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .get();
  }
}
