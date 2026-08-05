import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/quests/quest_definition.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/weekly_quest_list.dart';

QuestDefinition _def(String key, {int target = 5, String moduleId = 'water'}) =>
    QuestDefinition(
      questKey: key,
      moduleId: moduleId,
      titleKey: 'title',
      descriptionKey: 'desc',
      target: target,
      progressEvaluator: () async => 0,
    );

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id);
  @override
  final String id;
}

void main() {
  late AppDatabase db;
  // A Wednesday in ISO week 2026-W32.
  final now = DateTime.utc(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Decouples the widget from the real clock — the fixture data
          // below is always seeded under the fixed '2026-W32' week key.
          currentWeekQuestsProvider.overrideWith(
            (ref) => ref
                .watch(questRepositoryProvider)
                .watchCurrentWeek(weekKey: '2026-W32'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: WeeklyQuestList()),
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

  testWidgets('renders nothing when there are no quests this week', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.byType(Card), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('shows a progress tile per quest with its title and progress', (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repository.updateProgress(
      questKey: 'water_goal_5_of_7',
      weekKey: '2026-W32',
      current: 3,
      now: now,
    );

    await pumpList(tester);

    expect(find.text('Meet your water goal 5 of 7 days'), findsOneWidget);
    expect(find.text('3/5 days'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Claim Reward'), findsNothing);

    await disposeTree(tester);
  });

  testWidgets(
    'medicine_90_percent shows its progress as a percentage, not '
    "'N/90 days' (PR #77 review finding)",
    (tester) async {
      final repository = QuestRepository(db);
      await repository.ensureCurrentWeekQuests(
        definitions: [_def('medicine_90_percent', target: 90)],
        now: now,
      );
      await repository.updateProgress(
        questKey: 'medicine_90_percent',
        weekKey: '2026-W32',
        current: 67,
        now: now,
      );

      await pumpList(tester);

      expect(find.text('67%'), findsOneWidget);
      expect(find.text('67/90 days'), findsNothing);

      await disposeTree(tester);
    },
  );

  testWidgets('a completed, unclaimed quest shows a claim button', (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repository.updateProgress(
      questKey: 'water_goal_5_of_7',
      weekKey: '2026-W32',
      current: 5,
      now: now,
    );

    await pumpList(tester);

    expect(find.text('Claim Reward'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await disposeTree(tester);
  });

  testWidgets("claiming a quest's reward updates the tile to a checkmark", (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repository.updateProgress(
      questKey: 'water_goal_5_of_7',
      weekKey: '2026-W32',
      current: 5,
      now: now,
    );

    await pumpList(tester);
    expect(find.text('Claim Reward'), findsOneWidget);

    // The claim button's tap handler awaits a celebration overlay whose
    // AnimationController/Timer fight the widget-test pump/guard tracking
    // (same category of issue documented in
    // habit_stack_suggestion_card_test.dart) — exercise the same DB write
    // the handler performs instead of tapping through it.
    await repository.claimReward('water_goal_5_of_7', '2026-W32', now: now);
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Claim Reward'), findsNothing);

    List<WeeklyQuestRow>? rows;
    await tester.runAsync(() async {
      rows = await repository.watchCurrentWeek(weekKey: '2026-W32').first;
    });
    expect(rows!.single.rewardClaimed, 1);

    await disposeTree(tester);
  });

  testWidgets('an already-claimed quest shows a checkmark, not a button', (
    tester,
  ) async {
    final repository = QuestRepository(db);
    await repository.ensureCurrentWeekQuests(
      definitions: [_def('water_goal_5_of_7')],
      now: now,
    );
    await repository.updateProgress(
      questKey: 'water_goal_5_of_7',
      weekKey: '2026-W32',
      current: 5,
      now: now,
    );
    await repository.claimReward('water_goal_5_of_7', '2026-W32', now: now);

    await pumpList(tester);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Claim Reward'), findsNothing);

    await disposeTree(tester);
  });

  testWidgets(
    "a quest for a module no longer in the active module list doesn't "
    'render (PR #77 review finding)',
    (tester) async {
      final repository = QuestRepository(db);
      await repository.ensureCurrentWeekQuests(
        definitions: [
          _def('water_goal_5_of_7'),
          _def('medicine_perfect_week', target: 7, moduleId: 'medicine'),
        ],
        now: now,
      );

      // Only 'medicine' is in the active module list — 'water' isn't.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentWeekQuestsProvider.overrideWith(
              (ref) => ref
                  .watch(questRepositoryProvider)
                  .watchCurrentWeek(weekKey: '2026-W32'),
            ),
            habitModulesProvider.overrideWith(
              (ref) => [_FakeModule('medicine')],
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: WeeklyQuestList()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Meet your water goal 5 of 7 days'), findsNothing);
      expect(find.text('Take all doses every day this week'), findsOneWidget);

      await disposeTree(tester);
    },
  );
}
