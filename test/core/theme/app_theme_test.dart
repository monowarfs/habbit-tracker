import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

void main() {
  group('AppTheme seasonal seed override', () {
    test(
      "light() with no seasonalSeed keeps today's seed-color behavior "
      'unchanged (regression guard for the seasonal-accent override)',
      () {
        final theme = AppTheme.light(isBangla: false);
        // Matches `_seedColor` in app_theme.dart — this test exists to
        // catch an accidental default-seed change or a broken
        // "seasonalSeed: null falls back to _seedColor" path.
        final expected = ColorScheme.fromSeed(
          seedColor: const Color(0xFF006874),
        );
        expect(theme.colorScheme.primary, expected.primary);
        expect(theme.colorScheme.surface, expected.surface);
      },
    );

    test(
      "dark() with no seasonalSeed keeps today's seed-color behavior "
      'unchanged',
      () {
        final theme = AppTheme.dark(isBangla: false);
        final expected = ColorScheme.fromSeed(
          seedColor: const Color(0xFF006874),
          brightness: Brightness.dark,
        );
        expect(theme.colorScheme.primary, expected.primary);
        expect(theme.colorScheme.surface, expected.surface);
      },
    );

    test(
      'light() with a seasonalSeed produces a measurably different '
      'primary color than the non-seasonal default',
      () {
        final defaultTheme = AppTheme.light(isBangla: false);
        final seasonalTheme = AppTheme.light(
          isBangla: false,
          seasonalSeed: SeasonalAccent.pohelaBoishakh.seedColor,
        );
        expect(
          seasonalTheme.colorScheme.primary,
          isNot(equals(defaultTheme.colorScheme.primary)),
        );
      },
    );

    test(
      "a seasonalSeed does not change AppSemanticColors' success color "
      '— seasonal accents only substitute the ColorScheme seed',
      () {
        final defaultTheme = AppTheme.light(isBangla: false);
        final seasonalTheme = AppTheme.light(
          isBangla: false,
          seasonalSeed: SeasonalAccent.pohelaBoishakh.seedColor,
        );
        final defaultSuccess = defaultTheme
            .extension<AppSemanticColors>()!
            .success;
        final seasonalSuccess = seasonalTheme
            .extension<AppSemanticColors>()!
            .success;
        expect(seasonalSuccess, defaultSuccess);
        expect(seasonalSuccess, AppSemanticColors.light.success);
      },
    );

    test(
      'ModuleThemeAccents.defaults are plain static constants',
      () {
        expect(ModuleThemeAccents.defaults.water, const Color(0xFF1565C0));
        expect(ModuleThemeAccents.defaults.medicine, const Color(0xFF5E35B1));
        expect(ModuleThemeAccents.defaults.prayer, const Color(0xFFB8860B));
      },
    );
  });
}
