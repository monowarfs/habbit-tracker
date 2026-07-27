import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';

Future<void> _pumpWaterHome(
  WidgetTester tester,
  AppDatabase db, {
  required DateTime now,
}) async {
  await withClock(Clock.fixed(now), () async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [ModuleThemeAccents.defaults]),
          home: const WaterHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

double _ringValue(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
    .value!;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty state: no entries yet today', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    await _pumpWaterHome(tester, db, now: now);

    expect(find.text('No entries yet today'), findsOneWidget);
    expect(_ringValue(tester), 0.0);

    await disposeTree(tester);
  });

  testWidgets(
    "empty state's illustration is painted in Water's own accent color",
    (tester) async {
      final now = DateTime.utc(2026, 6, 1, 8);
      await _pumpWaterHome(tester, db, now: now);

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WaterDropPainter);
      final painter = customPaint.painter! as WaterDropPainter;
      expect(painter.color, ModuleThemeAccents.defaults.water);

      await disposeTree(tester);
    },
  );

  testWidgets('partial state: some progress logged, goal not yet met', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    final repo = WaterRepositoryImpl(db);
    await repo.addEntry(
      amountMl: 500,
      loggedAt: now,
      source: WaterEntrySource.quick,
    );

    await _pumpWaterHome(tester, db, now: now);

    expect(find.text('No entries yet today'), findsNothing);
    expect(_ringValue(tester), closeTo(500 / 2000, 0.001));

    await disposeTree(tester);
  });

  testWidgets('goal-met state: ring fills, entry still recorded above the '
      'goal amount', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    final repo = WaterRepositoryImpl(db);
    await repo.addEntry(
      amountMl: 2200,
      loggedAt: now,
      source: WaterEntrySource.custom,
    );

    await _pumpWaterHome(tester, db, now: now);

    expect(_ringValue(tester), 1.0); // clamped, even though 2200 > 2000
    // NumberFormat.decimalPattern('en') groups thousands with a comma —
    // appears in both the ring's big total and the log tile.
    expect(find.textContaining('2,200'), findsNWidgets(2));

    await disposeTree(tester);
  });

  testWidgets('deleting an entry hides it immediately without writing to '
      'the DB yet', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    final repo = WaterRepositoryImpl(db);
    final added = await repo.addEntry(
      amountMl: 500,
      loggedAt: now,
      source: WaterEntrySource.quick,
    );
    final entryId = (added as Success<WaterEntry>).value.id;

    await _pumpWaterHome(tester, db, now: now);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(await repo.entryById(entryId), isNotNull); // not soft-deleted

    await disposeTree(tester);
  });

  testWidgets('tapping Undo restores the entry; the repository is never '
      'touched', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    final repo = WaterRepositoryImpl(db);
    final added = await repo.addEntry(
      amountMl: 500,
      loggedAt: now,
      source: WaterEntrySource.quick,
    );
    final entryId = (added as Success<WaterEntry>).value.id;

    await _pumpWaterHome(tester, db, now: now);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // Let the snackbar's enter animation finish before tapping its action.
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(await repo.entryById(entryId), isNotNull); // not soft-deleted

    await disposeTree(tester);
  });

  testWidgets(
    'letting the undo window elapse actually soft-deletes the entry',
    (tester) async {
      final now = DateTime.utc(2026, 6, 1, 8);
      final repo = WaterRepositoryImpl(db);
      final added = await repo.addEntry(
        amountMl: 500,
        loggedAt: now,
        source: WaterEntrySource.quick,
      );
      final entryId = (added as Success<WaterEntry>).value.id;

      await _pumpWaterHome(tester, db, now: now);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // Past the 4s default undo window, plus the snackbar's own
      // enter/exit transitions.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(await repo.entryById(entryId), isNull); // soft-deleted

      await disposeTree(tester);
    },
  );
}
