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
