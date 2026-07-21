import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/security/lock_screen.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

import '../../support/test_database.dart';
import '../../support/test_pin_lock.dart';
import '../../support/test_secure_storage.dart';

void main() {
  testWidgets('bottom nav switches between the 5 tab branches', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final settingsRepo = SettingsRepositoryImpl(db);
    final controller = PinLockController(
      FakePinLockService(),
      settingsRepo,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          pinLockControllerProvider.overrideWithValue(controller),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(appRouterProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );

    // Pump multiple times to let async redirects and seeded DB settle.
    await tester.pump();
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

  testWidgets(
    'a locked app redirects to /lock; wrong PIN shows an error and stays '
    'locked; the correct PIN unlocks back to the dashboard',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final settingsRepo = SettingsRepositoryImpl(db);
      final service = PinLockService(storage: InMemorySecureStorage());
      final controller = PinLockController(service, settingsRepo);

      // setPin() records an unlock at "now" (real clock); writing a
      // "backgrounded at" immediately after — also real clock, so it's
      // unambiguously later — puts the app owing a fresh unlock (default
      // timeout is 0/immediate, so any backgrounding after the last
      // unlock locks it). No fake clock needed: real wall-clock time
      // only moves forward, so `isCurrentlyLocked`'s `clock.now()` at
      // redirect-check time is guaranteed to land after this.
      await controller.setPin('1234');
      await service.writeLastBackgroundedAt(DateTime.now().toUtc());
      // Biometric off: LockScreen's post-frame biometric attempt would
      // otherwise hit the real `local_auth` platform channel, which
      // isn't available under `flutter test`.
      await settingsRepo.updateBiometricEnabled(enabled: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            pinLockControllerProvider.overrideWithValue(controller),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              routerConfig: ref.watch(appRouterProvider),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Redirected to the lock screen instead of the dashboard.
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Dashboard'), findsNothing);

      // Wrong PIN: shows the error, stays locked.
      for (final digit in ['9', '9', '9', '9']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.lockScreenWrongPin), findsOneWidget);
      expect(find.byType(LockScreen), findsOneWidget);

      // Correct PIN: unlocks back to the dashboard.
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
