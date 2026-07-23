import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

void main() {
  Future<void> pumpTrigger(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => unawaited(
                  showStreakCelebration(
                    context,
                    title: '7-Day Streak',
                    accentColor: Colors.blue,
                    icon: Icons.local_fire_department,
                  ),
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title and auto-dismisses within the 2s budget', (
    tester,
  ) async {
    await pumpTrigger(tester);
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('7-Day Streak'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('7-Day Streak'), findsNothing);
  });

  testWidgets('tapping anywhere on the overlay dismisses it immediately', (
    tester,
  ) async {
    await pumpTrigger(tester);
    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(find.text('7-Day Streak'), findsOneWidget);

    await tester.tap(find.text('7-Day Streak'));
    await tester.pumpAndSettle();

    expect(find.text('7-Day Streak'), findsNothing);
  });

  testWidgets(
    'disableAnimations shows a static flash with no motion and dismisses '
    'well under the full animated budget',
    (tester) async {
      await pumpTrigger(tester, disableAnimations: true);
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('7-Day Streak'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      expect(find.text('7-Day Streak'), findsNothing);
    },
  );
}
