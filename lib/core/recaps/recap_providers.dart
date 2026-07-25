import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/recaps/recap_generator.dart';
import 'package:habit_tracker/core/recaps/recap_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Provides the [RecapRepository].
final recapRepositoryProvider = Provider<RecapRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RecapRepository(db);
});

/// Provides the [YearRecapGeneratorUseCase].
final yearRecapGeneratorProvider = Provider<YearRecapGeneratorUseCase>((ref) {
  final recapRepo = ref.watch(recapRepositoryProvider);
  final modules = ref.watch(habitModulesProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final db = ref.watch(databaseProvider);
  return YearRecapGeneratorUseCase(
    recapRepository: recapRepo,
    modules: modules,
    settingsRepository: settingsRepo,
    db: db,
  );
});
