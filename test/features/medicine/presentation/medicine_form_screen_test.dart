import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_form_screen.dart';

Future<GoRouter> _pumpMedicineForm(WidgetTester tester, AppDatabase db) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/form', builder: (_, _) => const MedicineFormScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/form'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('step 0 shows the four schedule presets plus Custom', (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    expect(find.text('Once daily'), findsOneWidget);
    expect(find.text('Twice daily'), findsOneWidget);
    expect(find.text('Every other day'), findsOneWidget);
    expect(find.text('As needed'), findsOneWidget);
    expect(find.text('Custom schedule'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('selecting a preset carries its rule through to Save', (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    await tester.tap(find.text('Every other day'));
    await tester.pumpAndSettle();

    // Landed on step 1 (details).
    expect(find.text('Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Aspirin');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2 (stock) — leave disabled, advance.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3 (schedule) — save without touching the radio group.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final repo = MedicineRepositoryImpl(db);
    final schedules = await repo.allSchedules(profileId: 'system');
    expect(schedules, hasLength(1));
    expect(
      schedules.single.rule,
      const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(20, 0)],
      ),
    );

    await disposeTree(tester);
  });

  testWidgets("selecting Custom leaves today's fixedDaily default", (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    await tester.tap(find.text('Custom schedule'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ibuprofen');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final repo = MedicineRepositoryImpl(db);
    final schedules = await repo.allSchedules(profileId: 'system');
    expect(schedules, hasLength(1));
    expect(
      schedules.single.rule,
      const RepeatRule.fixedDaily(timesOfDay: [LocalTime(20, 0)]),
    );

    await disposeTree(tester);
  });
}
