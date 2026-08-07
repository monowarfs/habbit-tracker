import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/consistency_score_display.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders the score, the excellent label, and the breakdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ConsistencyScoreDisplay(
          score: 90,
          breakdown: {'Water': 100, 'Medicine': 80},
        ),
      ),
    );

    expect(find.text('Consistency Score'), findsOneWidget);
    expect(find.text('90/100'), findsOneWidget);
    expect(find.text('Excellent!'), findsOneWidget);
    expect(find.text('Water: 100%'), findsOneWidget);
    expect(find.text('Medicine: 80%'), findsOneWidget);
  });

  testWidgets('shows the "Good" label in the mid band', (tester) async {
    await tester.pumpWidget(_wrap(const ConsistencyScoreDisplay(score: 65)));

    expect(find.text('65/100'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('shows the "Keep going!" label for a low score', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ConsistencyScoreDisplay(score: 20)));

    expect(find.text('20/100'), findsOneWidget);
    expect(find.text('Keep going!'), findsOneWidget);
  });

  testWidgets('renders with no breakdown rows when the map is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ConsistencyScoreDisplay(score: 50)));

    expect(find.text('50/100'), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
  });
}
