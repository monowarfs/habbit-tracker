import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/router/app_router.dart';

import '../../support/test_database.dart';

void main() {
  testWidgets('bottom nav switches between the 5 tab branches', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase())],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(appRouterProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on Dashboard. Water/Medicine/Prayer are always registered
    // (no module enable/disable feature exists yet), so the dashboard
    // shows their content, not the empty state.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    // Tap the Water destination, land on the water placeholder screen.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Water'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Water'), findsOneWidget);

    // Tap the Settings destination, land on the settings screen.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    // Dispose the tree now (inside the test body) and pump once more so
    // Drift's stream-close Timer fires before the test framework's
    // pending-timer check runs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
