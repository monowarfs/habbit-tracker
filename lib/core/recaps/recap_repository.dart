import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// Drift-backed repository for the `recaps` table.
class RecapRepository {
  /// Creates a repository backed by the given database.
  const RecapRepository(this._db);

  final AppDatabase _db;

  /// Returns the recap for [yearNumber], or null if none exists.
  Future<RecapRow?> byYearNumber(int yearNumber) async {
    return (_db.select(_db.recapsTable)
          ..where((t) => t.yearNumber.equals(yearNumber))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns all stored recaps, ordered by year number descending.
  Future<List<RecapRow>> allRecaps() async {
    return (_db.select(_db.recapsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.yearNumber)])
          ..limit(5))
        .get();
  }

  /// Saves a recap row (insert or update).
  Future<void> save(RecapRow recap) async {
    await _db.into(_db.recapsTable).insertOnConflictUpdate(recap);
  }

  /// Marks a recap as dismissed.
  Future<void> dismiss(String id) async {
    await (_db.update(_db.recapsTable)..where((t) => t.id.equals(id))).write(
      const RecapsTableCompanion(dismissed: Value(true)),
    );
  }
}
