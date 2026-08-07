import 'package:drift/drift.dart';

/// Stores generated yearly recaps. Each row is one year's worth of
/// aggregated stats, serialized as JSON for forward-compatible reads
/// (new stats fields don't require a schema migration on this table).
@DataClassName('RecapRow')
class RecapsTable extends Table {
  @override
  String get tableName => 'recaps';

  /// Stable id, e.g. `'year_1'`, `'year_2'`.
  TextColumn get id => text()();

  /// 1-based year number since install.
  IntColumn get yearNumber => integer()();

  /// Gregorian year of the user's install date.
  IntColumn get installYear => integer()();

  /// UTC epoch millis when this recap was generated.
  IntColumn get generatedAt => integer()();

  /// JSON-serialized YearSummary.
  TextColumn get summaryJson => text()();

  /// Whether the user has dismissed this recap from the full-screen view.
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}
