import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';

QuestDefinition _def(String key, {int target = 5}) => QuestDefinition(
  questKey: key,
  moduleId: 'water',
  titleKey: 'title',
  descriptionKey: 'desc',
  target: target,
  progressEvaluator: () async => 0,
);

void main() {
  late AppDatabase db;
  late QuestRepository repo;
  final now = DateTime.utc(2026, 8, 5); // a Wednesday, week 2026-W32.

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = QuestRepository(db);
  });

  tearDown(() => db.close());

  test(
    'ensureCurrentWeekQuests inserts a row per missing definition',
    () async {
      await repo.ensureCurrentWeekQuests(
        definitions: [
          _def('water_goal_5_of_7'),
          _def('water_no_skip_week', target: 7),
        ],
        now: now,
      );
      final rows = await repo.watchCurrentWeek(weekKey: '2026-W32').first;
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.progressCurrent), everyElement(0));
      expect(rows.map((r) => r.rewardClaimed), everyElement(0));
    },
  );

  test(
    'concurrent ensureCurrentWeekQuests calls do not throw on the unique '
    'key (PR #77 review finding — resume + write can race on the '
    "week's first-ever rows)",
    () async {
      final defs = [
        _def('water_goal_5_of_7'),
        _def('water_no_skip_week', target: 7),
      ];
      await Future.wait([
        repo.ensureCurrentWeekQuests(definitions: defs, now: now),
        repo.ensureCurrentWeekQuests(definitions: defs, now: now),
      ]);
      final rows = await repo.watchCurrentWeek(weekKey: '2026-W32').first;
      expect(rows, hasLength(2));
    },
  );

  test(
    'ensureCurrentWeekQuests is idempotent (dedup on questKey+weekKey)',
    () async {
      await repo.ensureCurrentWeekQuests(
        definitions: [_def('water_goal_5_of_7')],
        now: now,
      );
      await repo.updateProgress(
        questKey: 'water_goal_5_of_7',
        weekKey: '2026-W32',
        current: 3,
        now: now,
      );
      // Calling again must not reset the progress already recorded.
      await repo.ensureCurrentWeekQuests(
        definitions: [_def('water_goal_5_of_7')],
        now: now,
      );
      final rows = await repo.watchCurrentWeek(weekKey: '2026-W32').first;
      expect(rows, hasLength(1));
      expect(rows.single.progressCurrent, 3);
    },
  );

  test('updateProgress sets completedAt once target is reached', () async {
    await repo.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repo.updateProgress(
      questKey: 'water_goal_5_of_7',
      weekKey: '2026-W32',
      current: 5,
      now: now,
    );
    final row = (await repo.watchCurrentWeek(weekKey: '2026-W32').first).single;
    expect(row.completedAt, now.millisecondsSinceEpoch);
  });

  test(
    'updateProgress does not clear completedAt if progress later drops',
    () async {
      await repo.ensureCurrentWeekQuests(
        definitions: [_def('water_goal_5_of_7')],
        now: now,
      );
      await repo.updateProgress(
        questKey: 'water_goal_5_of_7',
        weekKey: '2026-W32',
        current: 5,
        now: now,
      );
      final firstCompletedAt =
          (await repo.watchCurrentWeek(weekKey: '2026-W32').first)
              .single
              .completedAt;

      await repo.updateProgress(
        questKey: 'water_goal_5_of_7',
        weekKey: '2026-W32',
        current: 2,
        now: now.add(const Duration(hours: 1)),
      );
      final row =
          (await repo.watchCurrentWeek(weekKey: '2026-W32').first).single;
      expect(row.progressCurrent, 2);
      expect(row.completedAt, firstCompletedAt);
    },
  );

  test('updateProgress no-ops for an unknown quest', () async {
    await repo.updateProgress(
      questKey: 'nonexistent',
      weekKey: '2026-W32',
      current: 1,
      now: now,
    );
    final rows = await repo.watchCurrentWeek(weekKey: '2026-W32').first;
    expect(rows, isEmpty);
  });

  test('claimReward marks the row claimed', () async {
    await repo.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repo.claimReward('water_goal_5_of_7', '2026-W32', now: now);
    final row = (await repo.watchCurrentWeek(weekKey: '2026-W32').first).single;
    expect(row.rewardClaimed, 1);
  });

  test('watchCurrentWeek only returns rows for the requested week', () async {
    await repo.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    final otherWeekRows = await repo
        .watchCurrentWeek(weekKey: '2026-W01')
        .first;
    expect(otherWeekRows, isEmpty);
  });
}
