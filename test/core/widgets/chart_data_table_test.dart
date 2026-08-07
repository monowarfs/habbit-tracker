import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/chart_data_table.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  const points = [
    BarChartPoint(label: 'Mon', value: 2000),
    BarChartPoint(label: 'Tue', value: 1500),
  ];

  testWidgets('renders a row per point with period and value', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ChartDataTable(points: points)));

    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
  });

  testWidgets('shows the empty-state message when points is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ChartDataTable(points: [])));

    expect(find.text('No data for this period'), findsOneWidget);
    expect(find.text('Period'), findsNothing);
  });

  testWidgets('shows the goal column when targetValue is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ChartDataTable(points: points, targetValue: 1800)),
    );

    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Goal met'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
  });

  testWidgets('hides the goal column when targetValue is null', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ChartDataTable(points: points)));

    expect(find.text('Goal'), findsNothing);
    expect(find.text('Goal met'), findsNothing);
    expect(find.text('Missed'), findsNothing);
  });

  testWidgets('uses goalLabel as the goal column header when supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ChartDataTable(
          points: points,
          targetValue: 1800,
          goalLabel: 'Daily Goal',
        ),
      ),
    );

    expect(find.text('Daily Goal'), findsOneWidget);
    expect(find.text('Goal'), findsNothing);
  });

  testWidgets('column headers are marked as accessibility headers', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ChartDataTable(points: points)));

    final periodHeaderSemantics = tester.getSemantics(find.text('Period'));
    expect(periodHeaderSemantics.flagsCollection.isHeader, isTrue);
  });

  group('ChartDataTableToggle', () {
    testWidgets('shows the chart by default, table hidden', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChartDataTableToggle(
            points: points,
            color: Colors.blue,
            chartSemanticsLabel: 'Test chart',
          ),
        ),
      );

      expect(find.byType(PeriodBarChart), findsOneWidget);
      expect(find.text('Period'), findsNothing);
    });

    testWidgets('toggling swaps the chart for the data table', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ChartDataTableToggle(
            points: points,
            color: Colors.blue,
            chartSemanticsLabel: 'Test chart',
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(PeriodBarChart), findsNothing);
      expect(find.byType(ChartDataTable), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
    });

    testWidgets('toggle button announces its toggled state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChartDataTableToggle(
            points: points,
            color: Colors.blue,
            chartSemanticsLabel: 'Test chart',
          ),
        ),
      );

      final before = tester.getSemantics(find.byType(IconButton));
      expect(before.flagsCollection.isToggled, Tristate.isFalse);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final after = tester.getSemantics(find.byType(IconButton));
      expect(after.flagsCollection.isToggled, Tristate.isTrue);
    });
  });
}
