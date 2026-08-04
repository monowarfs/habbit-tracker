import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// Drift-backed CRUD over the `weekly_quests` table
/// (`core/gamification/quests/quest_engine.dart`'s only data dependency).
class QuestRepository {
  /// Creates a repository backed by [_db].
  QuestRepository(this._db);

  final AppDatabase _db;

  /// Ensures a row exists for every one of [definitions] in the week
  /// containing [now] — inserts missing rows at `0/target`, leaves
  /// existing rows (and any progress already on them) untouched.
  Future<void> ensureCurrentWeekQuests({
    required List<QuestDefinition> definitions,
    required DateTime now,
  }) async {
    final weekKey = weekKeyForDate(localDayKey(now));
    final nowMillis = now.millisecondsSinceEpoch;
    final existingKeys =
        await (_db.select(_db.weeklyQuestsTable)
              ..where((t) => t.weekKey.equals(weekKey)))
            .map((row) => row.questKey)
            .get();
    final existingSet = existingKeys.toSet();
    for (final definition in definitions) {
      if (existingSet.contains(definition.questKey)) continue;
      await _db
          .into(_db.weeklyQuestsTable)
          .insert(
            WeeklyQuestsTableCompanion.insert(
              id: generateId(),
              questKey: definition.questKey,
              moduleId: definition.moduleId,
              weekKey: weekKey,
              progressCurrent: 0,
              progressTarget: definition.target,
              rewardClaimed: 0,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
    }
  }

  /// Updates [questKey]'s progress for [weekKey] to [current], setting
  /// `completedAt` the first time [current] reaches the row's own stored
  /// target. No-ops if the row doesn't exist yet (a write raced ahead of
  /// [ensureCurrentWeekQuests]).
  Future<void> updateProgress({
    required String questKey,
    required String weekKey,
    required int current,
    required DateTime now,
  }) async {
    final row = await _rowFor(questKey, weekKey);
    if (row == null) return;
    final nowMillis = now.millisecondsSinceEpoch;
    final justCompleted =
        row.completedAt == null && current >= row.progressTarget;
    await (_db.update(
      _db.weeklyQuestsTable,
    )..where((t) => t.id.equals(row.id))).write(
      WeeklyQuestsTableCompanion(
        progressCurrent: Value(current),
        completedAt: Value(justCompleted ? nowMillis : row.completedAt),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  /// Marks [questKey]'s reward as claimed for [weekKey]. No-ops if the
  /// row doesn't exist.
  Future<void> claimReward(
    String questKey,
    String weekKey, {
    required DateTime now,
  }) async {
    final row = await _rowFor(questKey, weekKey);
    if (row == null) return;
    await (_db.update(
      _db.weeklyQuestsTable,
    )..where((t) => t.id.equals(row.id))).write(
      WeeklyQuestsTableCompanion(
        rewardClaimed: const Value(1),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  /// All quests for [weekKey], live-updating.
  Stream<List<WeeklyQuestRow>> watchCurrentWeek({required String weekKey}) {
    return (_db.select(
      _db.weeklyQuestsTable,
    )..where((t) => t.weekKey.equals(weekKey))).watch();
  }

  Future<WeeklyQuestRow?> _rowFor(String questKey, String weekKey) {
    return (_db.select(_db.weeklyQuestsTable)..where(
          (t) => t.questKey.equals(questKey) & t.weekKey.equals(weekKey),
        ))
        .getSingleOrNull();
  }
}
