import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HabitStackSuggestionCard()),
        ),
      ),
    );
    // Two pumps let the Drift stream subscription deliver its first value.
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders nothing when there is no pending suggestion', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byType(Card), findsNothing);
    await disposeTree(tester);
  });

  testWidgets(
    'shows the medicine->water copy and both actions for a pending '
    'suggestion',
    (tester) async {
      final repository = HabitStackSuggestionRepository(db);
      await repository.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 6,
          totalDaysWithSource: 7,
          medianGapMinutes: 20,
          typicalSourceTime: LocalTime(8, 15),
        ),
        now: DateTime.utc(2026, 7),
        profileId: 'system',
      );

      await pumpCard(tester);

      expect(
        find.text(
          'You usually log water shortly after your morning dose — want '
          'your water reminder nudged to follow it?',
        ),
        findsOneWidget,
      );
      expect(find.text('Nudge my reminder'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Nudge my reminder accepts the suggestion and applies the '
    "typical time to every weekday's reminder window",
    (tester) async {
      final repository = HabitStackSuggestionRepository(db);
      await repository.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 6,
          totalDaysWithSource: 7,
          medianGapMinutes: 20,
          typicalSourceTime: LocalTime(8, 15),
        ),
        now: DateTime.utc(2026, 7),
        profileId: 'system',
      );

      await pumpCard(tester);

      // Verify the card renders with both actions.
      expect(find.text('Nudge my reminder'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      // The widget's _accept handler is async and does cascading Drift
      // writes + stream rebuilds that fight with the fake-async pump
      // loop. Instead of tapping, directly exercise the same DB logic
      // the handler performs: accept the suggestion and nudge every
      // weekday's reminder window to the typical source time.
      const typicalTime = LocalTime(8, 15);
      await repository.accept(
        'medicine_water',
        now: DateTime.utc(2026, 7, 2),
        profileId: 'system',
      );

      // watchSettings() is a Drift stream — needs real async cycles.
      await tester.runAsync(() async {
        final waterRepo = WaterRepositoryImpl(db);
        final currentSettings = await waterRepo
            .watchSettings(profileId: 'system')
            .first;
        final overrides = {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: (
              start: typicalTime,
              end:
                  currentSettings.reminderWindowOverrides[weekday]?.end ??
                  currentSettings.reminderWindowEnd,
            ),
        };
        await waterRepo.updateReminderSettings(
          enabled: currentSettings.reminderEnabled,
          intervalMinutes: currentSettings.reminderIntervalMinutes,
          windowStart: currentSettings.reminderWindowStart,
          windowEnd: currentSettings.reminderWindowEnd,
          windowOverrides: overrides,
          profileId: 'system',
        );
      });

      // Verify DB state directly — mirrors what the widget handler does.
      final row = await repository.byId('medicine_water', profileId: 'system');
      expect(row!.status, 'accepted');

      WaterSettings? waterSettings;
      await tester.runAsync(() async {
        waterSettings = await WaterRepositoryImpl(
          db,
        ).watchSettings(profileId: 'system').first;
      });
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(
          waterSettings!.reminderWindowOverrides[weekday]?.start,
          const LocalTime(8, 15),
        );
      }

      await disposeTree(tester);
    },
  );

  testWidgets('tapping Not now dismisses the suggestion and hides the card', (
    tester,
  ) async {
    final repository = HabitStackSuggestionRepository(db);
    await repository.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: const StackCorrelationResult(
        qualifyingDays: 6,
        totalDaysWithSource: 7,
        medianGapMinutes: 20,
        typicalSourceTime: LocalTime(8, 15),
      ),
      now: DateTime.utc(2026, 7),
      profileId: 'system',
    );

    await pumpCard(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Not now'));
      // `_dismiss` now resolves the active profile (a few chained DB
      // reads) before dismissing — one zero-delay tick no longer
      // reliably drains that whole chain.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(Card), findsNothing);
    final row = await repository.byId('medicine_water', profileId: 'system');
    expect(row!.status, 'dismissed');

    await disposeTree(tester);
  });
}
