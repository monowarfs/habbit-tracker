import 'package:flutter/material.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_controller.g.dart';

/// Exposes the app's [ThemeMode], derived from the DB-backed
/// [appSettingsProvider] (`../../../../strategies/theme.md`) — defaults to
/// [ThemeMode.system] before the first DB read resolves.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() {
    final settings = ref.watch(appSettingsProvider);
    return settings.value?.themeMode.toFlutterThemeMode() ?? ThemeMode.system;
  }

  /// Persists a new theme mode; [build] picks up the change automatically
  /// once the write lands (the DB stream re-emits).
  Future<void> updateThemeMode(ThemeMode mode) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .updateThemeMode(mode.toAppThemeMode());
    if (result case Failure(:final error)) logException(error);
  }
}

/// Domain <-> Flutter mapping, kept at the presentation boundary since
/// `domain/` has zero Flutter imports (`../../../../technical/architecture.md`).
extension AppThemeModeFlutter on AppThemeMode {
  /// Maps to Flutter's [ThemeMode].
  ThemeMode toFlutterThemeMode() => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// The inverse of [AppThemeModeFlutter].
extension ThemeModeApp on ThemeMode {
  /// Maps to the domain's [AppThemeMode].
  AppThemeMode toAppThemeMode() => switch (this) {
    ThemeMode.system => AppThemeMode.system,
    ThemeMode.light => AppThemeMode.light,
    ThemeMode.dark => AppThemeMode.dark,
  };
}
