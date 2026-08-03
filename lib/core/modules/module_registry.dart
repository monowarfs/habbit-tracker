import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/pauses/pause_repository.dart';
import 'package:habit_tracker/core/pauses/pause_service.dart';
import 'package:habit_tracker/core/premium/entitlement_service.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/features/blood_pressure/blood_pressure_module.dart';
import 'package:habit_tracker/features/blood_pressure/data/repositories/bp_repository_impl.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:habit_tracker/features/mood/data/repositories/mood_repository_impl.dart';
import 'package:habit_tracker/features/mood/mood_module.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/sleep/data/repositories/sleep_repository_impl.dart';
import 'package:habit_tracker/features/sleep/sleep_module.dart';
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
    (id: 'sleep', module: SleepModule(SleepRepositoryImpl(db))),
    (
      id: 'blood_pressure',
      module: BloodPressureModule(BpRepositoryImpl(db)),
    ),
    (id: 'mood', module: MoodModule(MoodRepositoryImpl(db))),
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
///
/// Deliberately includes every module regardless of premium entitlement —
/// the router splices `modules.firstWhere((m) => m.id == 'water').routes`
/// (and would do the same for a future premium module needing its own
/// branch) off this list, and data-integrity paths (the achievement
/// engine's own evaluation, local export) should see a lapsed-premium
/// user's existing data too. Every UI/display surface (dashboard, Reports,
/// the achievement gallery, local import, home-screen-widget/wearable
/// refresh) must instead go through [visibleHabitModulesProvider] or
/// [visibleHabitModules] — see those docs for why using this list directly
/// in a display surface is a premium-gating bug, not just a style choice.
@Riverpod(keepAlive: true)
List<HabitModule> habitModules(Ref ref) {
  return buildHabitModules(ref.watch(databaseProvider));
}

/// Module ids gated behind premium entitlement — hidden from
/// [visibleHabitModulesProvider]/[visibleHabitModules] until the user is
/// premium. Sleep's own screens are additionally gated via
/// `PremiumGateWidget` as defense in depth (a direct deep link must not
/// bypass this list), but this list is what actually controls whether a
/// gated module is *advertised or usable* on every UI/display surface.
const premiumGatedModuleIds = {'sleep', 'blood_pressure', 'mood'};

bool _isVisible(HabitModule module, {required bool isPremium}) =>
    isPremium || !premiumGatedModuleIds.contains(module.id);

/// [habitModulesProvider], filtered to modules the user can actually see
/// right now — every module for a premium user, every non-premium-gated
/// module otherwise. Use this (never [habitModulesProvider] directly) from
/// any widget-tree display surface: dashboard, Reports, the achievement
/// gallery, local import.
@riverpod
List<HabitModule> visibleHabitModules(Ref ref) {
  final modules = ref.watch(habitModulesProvider);
  final isPremium = ref.watch(isPremiumUserProvider);
  return modules
      .where((m) => _isVisible(m, isPremium: isPremium))
      .toList();
}

/// The ref-free equivalent of [visibleHabitModulesProvider], for
/// background/non-widget code that can't obtain a `Ref` (the home-screen-
/// widget refresh helper, the wearable sync helper) but still pushes data
/// to a *display* surface, not a data-integrity one — so it must not
/// leak a premium-gated module's data either.
Future<List<HabitModule>> visibleHabitModulesFromDb(AppDatabase db) async {
  final entitlement = await EntitlementService(db).getCachedEntitlement();
  return buildHabitModules(
    db,
  ).where((m) => _isVisible(m, isPremium: entitlement.isPremium)).toList();
}
