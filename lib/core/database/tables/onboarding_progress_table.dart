import 'package:drift/drift.dart';

/// Tracks whether the onboarding flow has been completed.
@DataClassName('OnboardingProgressRow')
class OnboardingProgressTable extends Table {
  @override
  String get tableName => 'onboarding_progress';

  /// Row id (always `'singleton'`).
  TextColumn get id => text()();

  /// Whether onboarding has been completed.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// UTC epoch millis when onboarding was completed; null if not yet.
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
