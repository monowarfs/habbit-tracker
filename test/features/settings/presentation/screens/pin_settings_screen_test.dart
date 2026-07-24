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
import 'package:habit_tracker/features/settings/presentation/screens/pin_settings_screen.dart';

void main() {
  testWidgets(
    'toggling biometric calls updateBiometricEnabled on the repository',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = _ReactiveSettingsRepo(
        const AppSettings(
          locale: AppLocale.en,
          themeMode: AppThemeMode.system,
          waterUnit: WaterUnit.ml,
          pinEnabled: true,
          pinLockTimeoutSeconds: 0,
          biometricEnabled: true,
          screenPrivacyEnabled: false,
          soundEnabled: false,
          quietHoursEnabled: false,
          quietHoursStart: LocalTime(22, 0),
          quietHoursEnd: LocalTime(7, 0),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PinSettingsScreen(
              biometricAvailable: () async => true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Biometric toggle defaults to true. Toggle it off.
      final biometricTile = find.widgetWithText(
        SwitchListTile,
        l10n.pinSettingsBiometric,
      );
      expect(biometricTile, findsOneWidget);

      final switch_ = tester.widget<SwitchListTile>(biometricTile);
      expect(switch_.value, isTrue);

      await tester.tap(biometricTile);
      await tester.pumpAndSettle();

      // Verify the repository was called and the setting persisted.
      expect(repo.currentSettings.biometricEnabled, isFalse);

      // Rebuild — switch should reflect persisted value.
      final switchAfter = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsBiometric),
      );
      expect(switchAfter.value, isFalse);
    },
  );

  testWidgets(
    'toggling screen privacy calls updateScreenPrivacyEnabled on the repository',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = _ReactiveSettingsRepo(
        const AppSettings(
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
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PinSettingsScreen(
              biometricAvailable: () async => false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Screen privacy toggle defaults to false. Toggle it on.
      final privacyTile = find.widgetWithText(
        SwitchListTile,
        l10n.pinSettingsScreenPrivacy,
      );
      expect(privacyTile, findsOneWidget);

      final switch_ = tester.widget<SwitchListTile>(privacyTile);
      expect(switch_.value, isFalse);

      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      // Verify the repository was called and the setting persisted.
      expect(repo.currentSettings.screenPrivacyEnabled, isTrue);

      // Rebuild — switch should reflect persisted value.
      final switchAfter = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsScreenPrivacy),
      );
      expect(switchAfter.value, isTrue);
    },
  );
}

/// A fake [SettingsRepository] that reacts to update calls by pushing
/// a new value through its stream. This lets the widget under test
/// rebuild when the toggle is flipped, just like the real DB-backed
/// implementation would.
class _ReactiveSettingsRepo implements SettingsRepository {
  _ReactiveSettingsRepo(AppSettings initial) : _settings = initial;

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
  Future<Result<void>> updateBiometricEnabled({required bool enabled}) async {
    await _update((s) => s.copyWith(biometricEnabled: enabled));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateScreenPrivacyEnabled({
    required bool enabled,
  }) async {
    await _update((s) => s.copyWith(screenPrivacyEnabled: enabled));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updatePinEnabled({required bool enabled}) async {
    await _update((s) => s.copyWith(pinEnabled: enabled));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updatePinLockTimeoutSeconds(int seconds) async {
    await _update((s) => s.copyWith(pinLockTimeoutSeconds: seconds));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateLocale(AppLocale locale) async {
    await _update((s) => s.copyWith(locale: locale));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateThemeMode(AppThemeMode mode) async {
    await _update((s) => s.copyWith(themeMode: mode));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateWaterUnit(WaterUnit unit) async {
    await _update((s) => s.copyWith(waterUnit: unit));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateLastSeenAppVersion(String version) async {
    await _update((s) => s.copyWith(lastSeenAppVersion: version));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateQuietHours({
    required bool enabled,
    required LocalTime start,
    required LocalTime end,
  }) async {
    await _update(
      (s) => s.copyWith(
        quietHoursEnabled: enabled,
        quietHoursStart: start,
        quietHoursEnd: end,
      ),
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateDisplayName(String? name) async {
    await _update((s) => s.copyWith(displayName: name));
  Future<Result<void>> updateSoundEnabled({required bool enabled}) async {
    await _update((s) => s.copyWith(soundEnabled: enabled));

    return const Result.success(null);
  }

  @override
  Future<Result<void>> restoreSettings(AppSettings settings) async {
    await _update((_) => settings);
    return const Result.success(null);
  }
}
