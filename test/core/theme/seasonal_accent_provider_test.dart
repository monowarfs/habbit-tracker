import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/seasonal_accent_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

AppSettings _makeSettings({bool seasonalAccentsEnabled = true}) =>
    AppSettings(
      locale: AppLocale.en,
      themeMode: AppThemeMode.system,
      waterUnit: WaterUnit.ml,
      pinEnabled: false,
      pinLockTimeoutSeconds: 0,
      biometricEnabled: true,
      screenPrivacyEnabled: false,
      soundEnabled: false,
      quietHoursEnabled: false,
      quietHoursStart: const LocalTime(22, 0),
      quietHoursEnd: const LocalTime(7, 0),
      seasonalAccentsEnabled: seasonalAccentsEnabled,
    );

void main() {
  test(
    'returns the Pohela Boishakh seed when enabled and the date is '
    'inside its window',
    () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AsyncData(_makeSettings()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await withClock(Clock.fixed(DateTime.utc(2026, 4, 14, 8)), () {
        expect(
          container.read(seasonalAccentSeedProvider),
          SeasonalAccent.pohelaBoishakh.seedColor,
        );
      });
    },
  );

  test('returns null on a date with no active occasion', () async {
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWithValue(
          AsyncData(_makeSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await withClock(Clock.fixed(DateTime.utc(2026, 7, 23, 8)), () {
      expect(container.read(seasonalAccentSeedProvider), isNull);
    });
  });

  test(
    'returns null when the user has opted out, even inside the window',
    () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AsyncData(_makeSettings(seasonalAccentsEnabled: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await withClock(Clock.fixed(DateTime.utc(2026, 4, 14, 8)), () {
        expect(container.read(seasonalAccentSeedProvider), isNull);
      });
    },
  );

  test(
    'SeasonalAccent.pohelaBoishakh has the expected red seed color',
    () {
      expect(
        SeasonalAccent.pohelaBoishakh.seedColor,
        const Color(0xFFC62828),
      );
    },
  );
}
