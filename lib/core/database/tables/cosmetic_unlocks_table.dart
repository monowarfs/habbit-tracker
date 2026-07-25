import 'package:drift/drift.dart';

/// Cosmetic unlock records — maps achievements to cosmetic options.
@DataClassName('CosmeticUnlockRow')
class CosmeticUnlocksTable extends Table {
  @override
  String get tableName => 'cosmetic_unlocks';

  /// Row id.
  TextColumn get id => text()();

  /// The achievement key that triggered this unlock (e.g. `'tenure_2_year'`).
  TextColumn get achievementKey => text()();

  /// The cosmetic option key (e.g. `'theme_accent_midnight'`).
  TextColumn get cosmeticKey => text()();

  /// UTC epoch millis when this cosmetic was unlocked.
  IntColumn get unlockedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
