import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_controller.g.dart';

/// Exposes and mutates the app's [ThemeMode].
///
/// In-memory only for now — this is the seam `app_settings.theme_mode`
/// (`strategies/theme.md`) plugs into once the settings table exists
/// (Run 06); the provider shape itself won't need to change.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() => ThemeMode.system;

  /// The active theme mode.
  ThemeMode get themeMode => state;

  /// Updates the active theme mode.
  set themeMode(ThemeMode mode) => state = mode;
}
