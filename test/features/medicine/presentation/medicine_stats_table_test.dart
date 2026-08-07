import 'package:clock/clock.dart';
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
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_stats_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // See water_stats_table_test.dart: pre-seed a personal record so a
    // fresh (0-day) streak doesn't trigger a full-screen streak
    // -celebration overlay that would swallow this test's own tap.
    await PersonalRecordRepository(db).setRecord(
      moduleId: 'medicine',
      recordType: 'longest_streak',
      value: 0,
      profileId: 'system',
    );
  });
  tearDown(() => db.close());

  testWidgets('toggling the chart shows the data-table fallback', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(isBangla: false),
            home: const MedicineStatsScreen(),
          ),
        ),
      );
      // Bounded pumps rather than pumpAndSettle — see
      // water_stats_table_test.dart for why.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(PeriodBarChart), findsOneWidget);
      expect(find.byType(ChartDataTable), findsNothing);

      await tester.tap(find.byTooltip('Show data table'));
      await tester.pump();

      expect(find.byType(PeriodBarChart), findsNothing);
      expect(find.byType(ChartDataTable), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
