import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/ramadan_settings_screen.dart';

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(AppSettings initial) : _settings = initial;

  AppSettings _settings;
  final _controller = StreamController<AppSettings>.broadcast();

  AppSettings get currentSettings => _settings;

  @override
  Stream<AppSettings> watchSettings() async* {
    yield _settings;
    yield* _controller.stream;
  }

  Future<void> _update(AppSettings Function(AppSettings) updater) async {
    _settings = updater(_settings);
    _controller.add(_settings);
  }

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
  Future<Result<void>> updateRamadanModeManualOverride(bool? override) async {
    await _update((s) => s.copyWith(ramadanModeManualOverride: override));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateRamadanAutoDetectEnabled({
    required bool enabled,
  }) async {
    await _update((s) => s.copyWith(ramadanAutoDetectEnabled: enabled));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateAdaptiveReminderEnabled({
    required bool enabled,
  }) => Future.value(const Result.success(null));


  @override
  Future<Result<void>> updateDisplayName(String? name) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateSeasonalAccentsEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> updateSoundEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> markWaterHydrationHintSeen() =>
      Future.value(const Result.success(null));

  @override
  Future<Result<void>> markPrayerQadhaHintSeen() =>
      Future.value(const Result.success(null));
  @override
  Future<Result<void>> restoreSettings(AppSettings settings) =>
      Future.value(const Result.success(null));
}

const _initial = AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: false,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: true,
  screenPrivacyEnabled: false,
      soundEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: LocalTime(22, 0),
  quietHoursEnd: LocalTime(7, 0),
  seasonalAccentsEnabled: true,
);

void main() {
  testWidgets(
    'auto-detect is on and the manual toggle is hidden by default; turning '
    'auto-detect off reveals the manual toggle, which persists its value; '
    'turning auto-detect back on clears the manual override',
    (tester) async {
      final repo = _FakeSettingsRepo(_initial);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RamadanSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Auto-detect toggle is on by default.
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                l10n.ramadanModeAutoDetectToggle,
              ),
            )
            .value,
        isTrue,
      );
      // Manual toggle is hidden when auto-detect is on.
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsNothing,
      );

      // Turn auto-detect off.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeAutoDetectToggle),
      );
      await tester.pumpAndSettle();

      expect(repo.currentSettings.ramadanAutoDetectEnabled, isFalse);
      // Manual toggle is now visible.
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsOneWidget,
      );
      // Default value is false.
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                l10n.ramadanModeManualToggle,
              ),
            )
            .value,
        isFalse,
      );

      // Turn manual override on.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
      );
      await tester.pumpAndSettle();
      expect(repo.currentSettings.ramadanModeManualOverride, isTrue);

      // Turn auto-detect back on — should clear the manual override.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeAutoDetectToggle),
      );
      await tester.pumpAndSettle();
      expect(repo.currentSettings.ramadanAutoDetectEnabled, isTrue);
      expect(repo.currentSettings.ramadanModeManualOverride, isNull);
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsNothing,
      );

      // Clean up.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
