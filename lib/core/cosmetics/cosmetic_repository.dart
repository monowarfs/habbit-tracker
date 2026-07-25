import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

/// CRUD for the `cosmetic_unlocks` table.
class CosmeticRepository {
  /// Creates a repository backed by the given database.
  const CosmeticRepository(this._db);

  final AppDatabase _db;

  /// All unlocked cosmetic keys.
  Future<Set<String>> unlockedKeys() async {
    final rows = await _db.select(_db.cosmeticUnlocksTable).get();
    return rows.map((r) => r.cosmeticKey).toSet();
  }

  /// Whether [cosmeticKey] is unlocked.
  Future<bool> isUnlocked(String cosmeticKey) async {
    final row = await (_db.select(_db.cosmeticUnlocksTable)
          ..where((t) => t.cosmeticKey.equals(cosmeticKey))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Records a cosmetic unlock (append-only, idempotent).
  Future<void> unlock({
    required String achievementKey,
    required String cosmeticKey,
  }) async {
    // Check if already unlocked.
    final existing = await (_db.select(_db.cosmeticUnlocksTable)
          ..where((t) => t.cosmeticKey.equals(cosmeticKey))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;

    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db.into(_db.cosmeticUnlocksTable).insert(
      CosmeticUnlocksTableCompanion.insert(
        id: const Uuid().v4(),
        achievementKey: achievementKey,
        cosmeticKey: cosmeticKey,
        unlockedAt: now,
      ),
    );
  }
}
