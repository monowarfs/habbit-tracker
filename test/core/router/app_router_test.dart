import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/router/app_router.dart';

void main() {
  testWidgets('bottom nav switches between the 5 tab branches', (
    tester,
  ) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on Dashboard.
    expect(
      find.text('Enable a module in Settings to get started'),
      findsOneWidget,
    );

    // Tap the Water destination, land on the water placeholder screen.
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Water'), findsOneWidget);

    // Tap the Settings destination, land on the settings screen.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });
}
