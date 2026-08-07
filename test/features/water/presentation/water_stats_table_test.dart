import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/chart_data_table.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_stats_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Pre-seed a personal record so a fresh (0-day) streak doesn't read
    // as "breaking" the (nonexistent) record — PersonalRecordRepository
    // .checkAndUpdate treats any value as a new record when no row
    // exists yet, which would otherwise pop a full-screen streak
    // -celebration overlay (core/widgets/streak_celebration_overlay.dart)
    // that swallows this test's own tap on the toggle button.
    await PersonalRecordRepository(db).setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 0,
      profileId: 'system',
    );
  });
  tearDown(() => db.close());

  testWidgets('toggling the chart shows the data-table fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(isBangla: false),
          home: const WaterStatsScreen(),
        ),
      ),
    );
    // Bounded pumps rather than pumpAndSettle: the screen's Drift-backed
    // StreamProviders only need a couple of microtask turns to emit their
    // first value, and pumpAndSettle would otherwise also wait out any
    // real (non-animation) Timer elsewhere in the tree (e.g. a
    // celebration overlay's auto-dismiss) which is irrelevant to what
    // this test asserts and makes it needlessly sensitive to real-clock
    // timing under system load.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(PeriodBarChart), findsOneWidget);
    expect(find.byType(ChartDataTable), findsNothing);

    await tester.tap(find.byTooltip('Show data table'));
    await tester.pump();

    expect(find.byType(PeriodBarChart), findsNothing);
    expect(find.byType(ChartDataTable), findsOneWidget);

    // Cleanup: same Drift-timer dance as water_stats_text_scale_test.dart
    // — disposing WaterStatsScreen leaves a pending zero-duration Timer
    // that needs an extra pump to fire before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}
