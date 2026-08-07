import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/export_orchestrator.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';

void main() {
  test(
    'builds an envelope with every module and appSettings/achievements',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final modules = buildHabitModules(db);
      final settingsRepository = SettingsRepositoryImpl(db);
      final achievementRepository = AchievementRepository(db);
      await achievementRepository.upsertProgress(
        moduleId: 'water',
        key: 'water_first_log',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 6),
        profileId: 'system',
      );

      final result = await buildExport(
        modules: modules,
        settingsRepository: settingsRepository,
        achievementRepository: achievementRepository,
        appVersion: '1.0.0',
        profileId: 'system',
      );

      expect(
        result.modules.keys,
        containsAll(['water', 'medicine', 'prayer']),
      );
      expect(result.appVersion, '1.0.0');
      final appSettings = result.common['appSettings'] as Map<String, Object?>;
      expect(appSettings['locale'], isNotNull);
      final achievements = result.common['achievements'] as List<dynamic>;
      expect(achievements, hasLength(1));
    },
  );
}
