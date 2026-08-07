import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// Drift-backed repository for the `recaps` table.
///
/// Every method takes `profileId` (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md`) — callers pass whatever `activeProfileProvider`
/// currently resolves to.
class RecapRepository {
  /// Creates a repository backed by the given database.
  const RecapRepository(this._db);

  final AppDatabase _db;

  /// Returns the recap for [yearNumber], or null if none exists.
  Future<RecapRow?> byYearNumber(
    int yearNumber, {
    required String profileId,
  }) async {
    return (_db.select(_db.recapsTable)
          ..where(
            (t) =>
                t.yearNumber.equals(yearNumber) & t.profileId.equals(profileId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns all stored recaps, ordered by year number descending.
  Future<List<RecapRow>> allRecaps({required String profileId}) async {
    return (_db.select(_db.recapsTable)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.yearNumber)])
          ..limit(5))
        .get();
  }

  /// Saves a recap row (insert or update).
  Future<void> save(RecapRow recap) async {
    await _db.into(_db.recapsTable).insertOnConflictUpdate(recap);
  }

  /// Marks a recap as dismissed.
  Future<void> dismiss(String id, {required String profileId}) async {
    await (_db.update(_db.recapsTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          const RecapsTableCompanion(dismissed: Value(true)),
        );
  }
}
