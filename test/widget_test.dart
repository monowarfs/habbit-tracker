import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/main.dart';

import 'support/test_database.dart';

void main() {
  testWidgets('app boots to the dashboard with all modules registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase())],
        child: const HabitTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // No module enable/disable feature exists yet (that's a future run per
    // phases-and-dod.md), so all three modules are always registered and
    // the dashboard's empty state never shows in the real app.
    expect(
      find.text('Enable a module in Settings to get started'),
      findsNothing,
    );
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Dispose the tree now (inside the test body) and pump once more so
    // Drift's stream-close Timer fires before the test framework's
    // pending-timer check runs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
