import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/pauses/pause_repository.dart';
import 'package:habit_tracker/core/pauses/pause_service.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/water_module.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'module_registry.g.dart';

/// Builds the module list directly from a database instance
/// (`../../technical/architecture.md`) — used by code that can't obtain a
/// `Ref` (the notification background isolate
/// (`../notifications/notification_action_handler.dart`), the Android
/// WorkManager callback). [habitModulesProvider] wraps this so both paths
/// construct modules identically.
///
/// Adding a future module (e.g. Sleep) means writing `lib/features/sleep/`
/// and adding one line below — no other file in this list or in `core/` is
/// touched.
List<HabitModule> buildHabitModules(
  AppDatabase db, {
  Set<String>? enabledModules,
}) {
  final settingsRepository = SettingsRepositoryImpl(db);
  final pauseService = PauseService(
    pauseRepository: PauseRepository(db),
    notificationLedger: NotificationLedgerRepository(db),
  );
  final allModules = [
    (
      id: 'medicine',
      module: MedicineModule(
        MedicineRepositoryImpl(db),
        pauseService: pauseService,
      ),
    ),
    (
      id: 'water',
      module: WaterModule(
        WaterRepositoryImpl(db),
        settingsRepository: settingsRepository,
        prayerRepository: PrayerRepositoryImpl(db),
        pauseService: pauseService,
      ),
    ),
    (
      id: 'prayer',
      module: PrayerModule(
        PrayerRepositoryImpl(db),
        settingsRepository: settingsRepository,
        pauseService: pauseService,
      ),
    ),
  ];
  if (enabledModules == null) return allModules.map((e) => e.module).toList();
  return allModules
      .where((e) => enabledModules.contains(e.id))
      .map((e) => e.module)
      .toList();
}

/// The single shared list of registered modules, for widget code that has a
/// `Ref` (`Widget dashboardSummary(WidgetRef ref)`/`settingsEntry` still
/// take their own `WidgetRef` independently of this list).
@Riverpod(keepAlive: true)
List<HabitModule> habitModules(Ref ref) {
  return buildHabitModules(ref.watch(databaseProvider));
}
