import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/goal_attainment_use_case.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/goal_attainment_display.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders hit/total/percent and the goal label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GoalAttainmentDisplay(
          result: GoalAttainmentResult(metDays: 22, totalDays: 30, rate: 0.73),
          goalLabel: 'Water goal reached',
        ),
      ),
    );

    expect(find.text('Goal Attainment'), findsOneWidget);
    expect(find.text('22/30 days (73%)'), findsOneWidget);
    expect(find.text('Water goal reached'), findsOneWidget);
  });

  testWidgets('shows the empty-state message when totalDays is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const GoalAttainmentDisplay(
          result: GoalAttainmentResult(metDays: 0, totalDays: 0, rate: 0),
          goalLabel: 'Water goal reached',
        ),
      ),
    );

    expect(find.text('No data for this period'), findsOneWidget);
    expect(find.text('Water goal reached'), findsNothing);
  });
}
