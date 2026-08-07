import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';
import 'package:habit_tracker/core/gamification/quests/week_utils.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/boss_challenge_card.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id);
  @override
  final String id;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id[0].toUpperCase() + id.substring(1),
    icon: Icons.circle,
    accentColor: Colors.blue,
  );
}

QuestDefinition _bossDef(
  String key, {
  int target = 6,
  String moduleId = 'water',
}) => QuestDefinition(
  questKey: key,
  moduleId: moduleId,
  titleKey: 'title',
  descriptionKey: 'desc',
  target: target,
  progressEvaluator: () async => 0,
);

void main() {
  late AppDatabase db;
  // A Wednesday in ISO week 2026-W32 (Monday 2026-08-03, Sunday 2026-08-09).
  final now = DateTime.utc(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentWeekQuestsProvider.overrideWith(
            (ref) => ref
                .watch(questRepositoryProvider)
                .watchCurrentWeek(weekKey: '2026-W32', profileId: 'system'),
          ),
          habitModulesProvider.overrideWith((ref) => [_FakeModule('water')]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BossChallengeCard()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders nothing when there is no boss quest this week', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byType(Card), findsNothing);
    await disposeTree(tester);
  });

  testWidgets(
    'shows module spotlight, description, progress, and countdown',
    (tester) async {
      final repository = QuestRepository(db);
      await repository.ensureBossQuest(
        _bossDef('boss_water_6_of_7'),
        weekKey: '2026-W32',
        now: now,
        profileId: 'system',
      );
      await repository.updateProgress(
        questKey: 'boss_water_6_of_7',
        weekKey: '2026-W32',
        current: 4,
        now: now,
        profileId: 'system',
      );

      await pumpCard(tester);

      expect(find.text('BOSS'), findsOneWidget);
      expect(find.text('Water Week'), findsOneWidget);
      expect(find.text('Hit water goal 6 of 7 days'), findsOneWidget);
      expect(find.text('4/6 days'), findsOneWidget);
      // The countdown reflects the real current week (not the fixture's
      // hardcoded '2026-W32' weekKey, which only scopes the DB query) —
      // computed the same way the widget does so this stays correct
      // regardless of which real day the suite runs on.
      final today = localDayKey(clock.now());
      final daysRemaining = mondayOfWeek(
        today,
      ).addDays(6).toDateTimeUtc().difference(today.toDateTimeUtc()).inDays;
      expect(find.text('$daysRemaining days remaining'), findsOneWidget);
      expect(find.text('Claim Reward'), findsNothing);

      await disposeTree(tester);
    },
  );

  testWidgets('a completed, unclaimed boss shows a claim button', (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureBossQuest(
      _bossDef('boss_water_6_of_7'),
      weekKey: '2026-W32',
      now: now,
      profileId: 'system',
    );
    await repository.updateProgress(
      questKey: 'boss_water_6_of_7',
      weekKey: '2026-W32',
      current: 6,
      now: now,
      profileId: 'system',
    );

    await pumpCard(tester);

    expect(find.text('Claim Reward'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('a claimed boss shows a trophy icon, not a button', (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureBossQuest(
      _bossDef('boss_water_6_of_7'),
      weekKey: '2026-W32',
      now: now,
      profileId: 'system',
    );
    await repository.updateProgress(
      questKey: 'boss_water_6_of_7',
      weekKey: '2026-W32',
      current: 6,
      now: now,
      profileId: 'system',
    );
    await repository.claimReward(
      'boss_water_6_of_7',
      '2026-W32',
      now: now,
      profileId: 'system',
    );

    await pumpCard(tester);

    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(find.text('Claim Reward'), findsNothing);

    await disposeTree(tester);
  });

  testWidgets(
    "a regular (non-boss) quest row doesn't render as the boss card",
    (tester) async {
      final repository = QuestRepository(db);
      await repository.ensureCurrentWeekQuests(
        definitions: [_bossDef('water_goal_5_of_7', target: 5)],
        now: now,
        profileId: 'system',
      );

      await pumpCard(tester);

      expect(find.byType(Card), findsNothing);

      await disposeTree(tester);
    },
  );
}
