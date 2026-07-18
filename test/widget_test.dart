import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/main.dart';

import 'support/test_database.dart';

void main() {
  testWidgets('app boots to the dashboard empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase())],
        child: const HabitTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Enable a module in Settings to get started'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    // Dispose the tree now (inside the test body) and pump once more so
    // Drift's stream-close Timer fires before the test framework's
    // pending-timer check runs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
