import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_providers.g.dart';

/// The app's [SettingsRepository].
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepositoryImpl(ref.watch(databaseProvider));
}

/// The app's current settings, reactive to every DB write
/// (`../../../../technical/state-management.md`'s stream-provider pattern).
@Riverpod(keepAlive: true)
Stream<AppSettings> appSettings(Ref ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
}

/// Whether Simple Mode (large-button, single-column layout, `docs/
/// superpowers/specs/07-accessibility/
/// 06-SIMPLE-MODE-LARGE-BUTTON-LAYOUT-IMPLEMENTATION-PLAN.md`) is active —
/// derived from [appSettingsProvider] and exposed as a plain `bool` so
/// screen `build()` methods can branch on it directly instead of
/// unwrapping an `AsyncValue` themselves.
@riverpod
bool simpleModeEnabled(Ref ref) {
  return ref.watch(appSettingsProvider).value?.simpleModeEnabled ?? false;
}
