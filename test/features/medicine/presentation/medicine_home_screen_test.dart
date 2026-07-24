import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
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
