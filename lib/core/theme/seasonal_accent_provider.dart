import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// The active seasonal seed color, or `null` if none applies today
/// (opted out, or no occasion active) — `HabitTrackerApp.build` reads
/// this alongside `themeControllerProvider`/`localeControllerProvider`.
/// No lingering state to revert: this is a pure computed read of
/// `clock.now()` + settings each rebuild, so once the date window
/// passes, the next rebuild (app resume, at minimum) simply recomputes
/// `null` and the theme reverts to `_seedColor` on its own.
///
/// Uses a manual Provider (not codegen) because `riverpod_generator`
/// cannot serialize `dart:ui`'s `Color` type into generated code.
final seasonalAccentSeedProvider = Provider<Color?>((ref) {
  final settingsAsync = ref.watch(appSettingsProvider);
  final settings = settingsAsync.value;
  if (settings == null || !settings.seasonalAccentsEnabled) return null;
  final occasion = activeSeasonalOccasion(localDayKey(clock.now()));
  return switch (occasion) {
    null => null,
    SeasonalOccasion.pohelaBoishakh => SeasonalAccent.pohelaBoishakh.seedColor,
    SeasonalOccasion.eid => SeasonalAccent.eid.seedColor,
  };
});
