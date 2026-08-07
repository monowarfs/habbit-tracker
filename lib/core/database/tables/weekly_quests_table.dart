import 'package:drift/drift.dart';

/// Weekly quest progress rows — one row per (quest, ISO week).
@DataClassName('WeeklyQuestRow')
class WeeklyQuestsTable extends Table {
  @override
  String get tableName => 'weekly_quests';

  /// Row id.
  TextColumn get id => text()();

  /// The quest catalog key, e.g. `'water_goal_5_of_7'`.
  TextColumn get questKey => text()();

  /// The module this quest belongs to.
  TextColumn get moduleId => text()();

  /// ISO 8601 week key, `'YYYY-Www'`.
  TextColumn get weekKey => text()();

  /// Current progress toward [progressTarget].
  IntColumn get progressCurrent => integer()();

  /// Progress required to complete the quest.
  IntColumn get progressTarget => integer()();

  /// UTC epoch millis when the quest was completed, or null.
  IntColumn get completedAt => integer().nullable()();

  /// Whether the reward has been claimed: 0 or 1.
  IntColumn get rewardClaimed => integer()();

  /// Whether this is a boss challenge (higher threshold, distinct
  /// dashboard presentation): 0 or 1.
  IntColumn get isBoss => integer().withDefault(const Constant(0))();

  /// UTC epoch millis when this row was created.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis when this row was last updated.
  IntColumn get updatedAt => integer()();

  /// Multi-profile scoping (`core/profiles/`); defaults to `'system'` for
  /// rows that pre-date profile support.
  TextColumn get profileId =>
      text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {questKey, weekKey, profileId},
  ];
}
