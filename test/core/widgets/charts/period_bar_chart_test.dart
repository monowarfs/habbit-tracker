import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';

void main() {
  const points = [
    BarChartPoint(label: '1', value: 10),
    BarChartPoint(label: '2', value: 20),
  ];

  testWidgets('renders one bar group per point with no overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PeriodBarChart(points: points, color: Colors.blue),
      ),
    );
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 2);
  });

  testWidgets('renders overlay bars behind the main bars', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PeriodBarChart(
          points: points,
          overlayPoints: [
            BarChartPoint(label: '1', value: 5),
            BarChartPoint(label: '2', value: 30),
          ],
          overlayLabel: 'Last year',
          color: Colors.blue,
        ),
      ),
    );
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    // One overlay group + one main group per point.
    expect(chart.data.barGroups.length, 4);
    // maxY grows to fit the taller overlay bar (30) too.
    expect(chart.data.maxY, greaterThanOrEqualTo(30));
  });

  testWidgets(
    'a shorter overlay list only pairs the overlapping indices',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PeriodBarChart(
            points: points,
            overlayPoints: [BarChartPoint(label: '1', value: 5)],
            color: Colors.blue,
          ),
        ),
      );
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.length, 3); // 1 overlay + 2 main
    },
  );

  testWidgets('existing call sites without overlay params keep working', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PeriodBarChart(
          points: points,
          color: Colors.teal,
          targetLine: 15,
          semanticsLabel: 'Water intake',
        ),
      ),
    );
    expect(find.byType(BarChart), findsOneWidget);
  });
}
