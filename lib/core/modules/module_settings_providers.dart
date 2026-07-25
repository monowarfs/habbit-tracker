import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/module_settings_repository.dart';

/// Provides the [ModuleSettingsRepository].
final moduleSettingsRepositoryProvider = Provider<ModuleSettingsRepository>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return ModuleSettingsRepository(db);
});
