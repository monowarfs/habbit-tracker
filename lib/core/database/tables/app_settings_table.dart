import 'package:drift/drift.dart';

/// The singleton app-settings row (`database-design.md`) — app code always
/// upserts the fixed id `'singleton'`; Drift has no native
/// "exactly one row" constraint short of a trigger, which is unjustified
/// complexity for an app-code-enforced invariant.
@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  /// Always `'singleton'`.
  TextColumn get id => text()();

  /// `'en'` | `'bn'`.
  TextColumn get locale => text()();

  /// `'system'` | `'light'` | `'dark'`.
  TextColumn get themeMode => text()();

  /// `'ml'` | `'fl_oz'` (D-01).
  TextColumn get waterUnit => text()();

  /// PIN lock enabled (D-15) — the hash itself lives in
  /// `flutter_secure_storage`, never in this table.
  BoolColumn get pinEnabled => boolean().withDefault(const Constant(false))();

  /// 0 = immediate.
  IntColumn get pinLockTimeoutSeconds =>
      integer().withDefault(const Constant(0))();

  /// UTC epoch millis; null = onboarding not yet completed.
  IntColumn get onboardingCompletedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
