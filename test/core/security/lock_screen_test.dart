import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/security/lock_screen.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

import '../../support/test_secure_storage.dart';

const _testSettings = AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: true,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: false,
  screenPrivacyEnabled: false,
  soundEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: LocalTime(22, 0),
  quietHoursEnd: LocalTime(7, 0),
  seasonalAccentsEnabled: true,
);

void main() {
  late PinLockService service;
  late PinLockController controller;

  setUp(() async {
    service = PinLockService(storage: InMemorySecureStorage());
    controller = PinLockController(service, _StubSettingsRepo());
    await controller.setPin('1234');
  });

  testWidgets('wrong PIN shows error and stays on lock screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinLockControllerProvider.overrideWithValue(controller),
          appSettingsProvider.overrideWithValue(const AsyncData(_testSettings)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/lock',
            routes: [
              GoRoute(
                path: '/lock',
                builder: (context, state) => const LockScreen(),
              ),
            ],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);

    // Enter wrong PIN.
    for (final digit in ['0', '0', '0', '0']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.lockScreenWrongPin), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('correct PIN unlocks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinLockControllerProvider.overrideWithValue(controller),
          appSettingsProvider.overrideWithValue(const AsyncData(_testSettings)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/lock',
            routes: [
              GoRoute(
                path: '/lock',
                builder: (context, state) => const LockScreen(),
              ),
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('Dashboard')),
                ),
              ),
            ],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);

    // Enter correct PIN.
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsNothing);
  });
}

/// Stub [SettingsRepository] for lock-screen tests. [LockScreen] reads
/// [appSettingsProvider] (which derives from this via the default
/// `appSettings` provider function), so this must emit a value that
/// passes through `_tryBiometric`'s `biometricEnabled` gate.
class _StubSettingsRepo implements SettingsRepository {
  @override
  Stream<AppSettings> watchSettings() => Stream.value(_testSettings);

  @override
  Future<Result<void>> updateLocale(AppLocale locale) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateThemeMode(AppThemeMode mode) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateWaterUnit(WaterUnit unit) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updatePinEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updatePinLockTimeoutSeconds(int seconds) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateBiometricEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateScreenPrivacyEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateLastSeenAppVersion(String version) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateQuietHours({
    required bool enabled,
    required LocalTime start,
    required LocalTime end,
  }) => Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateDisplayName(String? name) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateSoundEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));
  @override
  Future<Result<void>> updateSeasonalAccentsEnabled({
    required bool enabled,
  }) => Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateRamadanModeManualOverride(bool? override) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateRamadanAutoDetectEnabled({
    required bool enabled,
  }) => Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateAdaptiveReminderEnabled({
    required bool enabled,
  }) => Future.value(const Result.success(null));

  @override
  Future<Result<void>> restoreSettings(AppSettings settings) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> markWaterHydrationHintSeen() =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> markPrayerQadhaHintSeen() =>
      Future.value(const Result.success(null));
}
