import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/monthly_recap_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<ModuleReport> reports,
    required LocalDate monthAnchor,
  }) async {
    // The card is a fixed 1080x1920 portrait layout — resize the test
    // surface so it lays out without overflowing the default ~800x600
    // test viewport.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MonthlyRecapCard(reports: reports, monthAnchor: monthAnchor),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders one row per module with its display name and longest-streak '
    'headline',
    (tester) async {
      const reports = [
        (
          moduleId: 'water',
          displayName: 'Water',
          accentColor: Color(0xFF1565C0),
          points: <BarChartPoint>[],
          longestStreak: 12,
        ),
        (
          moduleId: 'prayer',
          displayName: 'Prayer',
          accentColor: Color(0xFFB8860B),
          points: <BarChartPoint>[],
          longestStreak: 30,
        ),
      ];

      await pumpCard(
        tester,
        reports: reports,
        monthAnchor: const LocalDate(2026, 7, 1),
      );

      expect(find.text('July recap'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Prayer'), findsOneWidget);
      expect(find.text('12-day streak'), findsOneWidget);
      expect(find.text('30-day streak'), findsOneWidget);
    },
  );

  testWidgets('renders the header even with an empty module list', (
    tester,
  ) async {
    await pumpCard(
      tester,
      reports: const [],
      monthAnchor: const LocalDate(2026, 3, 1),
    );

    expect(find.text('March recap'), findsOneWidget);
  });
}
