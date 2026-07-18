import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';

Future<void> _pumpMedicineHome(
  WidgetTester tester,
  AppDatabase db, {
  required DateTime now,
}) async {
  await withClock(Clock.fixed(now), () async {
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
}
