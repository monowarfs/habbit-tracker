import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/analytics/presentation/providers/year_comparison_provider.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

AppSettings _settings({DateTime? installDate}) => AppSettings(
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
  seasonalAccentsEnabled: false,
  installDate: installDate,
);

void main() {
  test('ineligible when appSettings has no install date yet', () async {
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWithValue(
          AsyncData(_settings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(yearComparisonEligibleProvider), isFalse);
  });

  test('eligible once appSettings.installDate crosses a year old', () async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AsyncData(_settings(installDate: DateTime.utc(2025))),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(yearComparisonEligibleProvider), isTrue);
    });
  });

  test('reacts to appSettings still loading as ineligible, not a crash', () {
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(yearComparisonEligibleProvider), isFalse);
  });
}
