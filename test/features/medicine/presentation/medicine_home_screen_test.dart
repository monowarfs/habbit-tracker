import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/audio/chime_player.dart';

import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:mocktail/mocktail.dart';

Future<void> _pumpMedicineHome(
  WidgetTester tester,
  AppDatabase db, {
  required DateTime now,
  ChimePlayer? chimePlayer,
}) async {
  await withClock(Clock.fixed(now), () async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MedicineHomeScreen(chimePlayer: chimePlayer),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty state: no medicines yet', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('No doses scheduled for today'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('populated state: shows an upcoming dose tile', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final repo = MedicineRepositoryImpl(db);
    final medicine = await repo.createMedicine(
      name: 'Amoxicillin',
      stockEnabled: false,
    );
    await repo.createSchedule(
      medicineId: (medicine as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(now), () async {
      await repo.materializeDoses(clock.now());
    });

    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('Amoxicillin'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('overdue (missed) dose is visually distinct', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    final medicine = await repo.createMedicine(
      name: 'Ibuprofen',
      stockEnabled: false,
    );
    await repo.createSchedule(
      medicineId: (medicine as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    // Now well past the grace window -> missed.
    final now = DateTime.utc(2026, 6, 1, 10);
    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('Missed'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets(
    'missed dose uses the neutral outline color, not the error/red role '
    '(no guilt-tripping color signal)',
    (tester) async {
      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Ibuprofen',
    'marking a dose done plays the chime when sound is enabled',
    (tester) async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Amoxicillin',

        stockEnabled: false,
      );
      await repo.createSchedule(
        medicineId: (medicine as Success<Medicine>).value.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
        await repo.materializeDoses(clock.now());
      });

      // Now well past the grace window -> missed.
      final now = DateTime.utc(2026, 6, 1, 10);
      await _pumpMedicineHome(tester, db, now: now);

      final missedLabel = tester.widget<Text>(find.text('Missed'));
      final theme = Theme.of(tester.element(find.text('Missed')));
      expect(missedLabel.style?.color, theme.colorScheme.outline);
      expect(missedLabel.style?.color, isNot(theme.colorScheme.error));

      await disposeTree(tester);
      await withClock(Clock.fixed(now), () async {
        await repo.materializeDoses(clock.now());
      });

      // Seed soundEnabled BEFORE pump. Use a dedicated SettingsRepository
      // then close it immediately — no stream watcher leaks.
      final settingsRepo = SettingsRepositoryImpl(db);
      await settingsRepo.updateSoundEnabled(enabled: true);

      final chime = _MockChimePlayer();
      when(() => chime.playDoseDoneChime()).thenAnswer((_) async {});

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MedicineHomeScreen(chimePlayer: chime),
            ),
          ),
        );
        // Use pump() instead of pumpAndSettle() to avoid the
        // settings-stream-change-notification infinite settling loop.
        for (var i = 0; i < 10; i++) {
          await tester.pump();
        }
      });

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      verify(() => chime.playDoseDoneChime()).called(1);

    },
  );

  testWidgets(
    'marking the last dose of a 7-day adherence streak done shows the '
    'streak celebration before the achievement snackbar',
    (tester) async {
      final repo = MedicineRepositoryImpl(db);
      final medicineResult = await repo.createMedicine(
        name: 'Aspirin',
        stockEnabled: false,
      );
      final medicine = (medicineResult as Success<Medicine>).value;
      final scheduleResult = await repo.createSchedule(
        medicineId: medicine.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 5, 20),
      );
      final schedule = (scheduleResult as Success<MedicineSchedule>).value;

      // `medicine_first_dose` would otherwise unlock in the very same
      // diff as `medicine_adherence_streak_7` — pre-seed it as
      // already-unlocked.
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertProgress(
        moduleId: 'medicine',
        key: 'medicine_first_dose',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 21),
      );

      final today = DateTime.utc(2026, 6, 1, 8, 15);
      // 6 prior fully-taken days.
      for (var i = 1; i <= 6; i++) {
        final day = today.subtract(Duration(days: i));
        await repo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicine.id,
            scheduleId: schedule.id,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(day.year, day.month, day.day, 8, 5),
            stockDeltaApplied: 0,
          ),
        );
      }

      await withClock(Clock.fixed(today), () async {
        await repo.materializeDoses(today);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MedicineHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Done'));
        await tester.pump();
        // Let the undo snackbar's enter animation finish, then time out.
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // The celebration overlay appears first.
        expect(find.text('On Schedule'), findsOneWidget);
        expect(
          find.text('Achievement unlocked: On Schedule'),
          findsNothing,
        );

        // Let the overlay auto-dismiss, then the snackbar follows.
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        expect(
          find.text('Achievement unlocked: On Schedule'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    'marking a dose done never plays a chime when sound is off (the '
    'default)',
    (tester) async {
      final now = DateTime.utc(2026, 6, 1, 7);
      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Amoxicillin',
        stockEnabled: false,
      );
      await repo.createSchedule(
        medicineId: (medicine as Success<Medicine>).value.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      await withClock(Clock.fixed(now), () async {
        await repo.materializeDoses(clock.now());
      });

      final chime = _MockChimePlayer();
      when(() => chime.playDoseDoneChime()).thenAnswer((_) async {});

      await _pumpMedicineHome(tester, db, now: now, chimePlayer: chime);

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      verifyNever(() => chime.playDoseDoneChime());
      await disposeTree(tester);

    },
  );
}

class _MockChimePlayer extends Mock implements ChimePlayer {}
