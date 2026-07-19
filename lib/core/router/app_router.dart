import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_reliability_screen.dart';
import 'package:habit_tracker/core/widgets/app_scaffold.dart';
import 'package:habit_tracker/features/achievements/presentation/screens/achievement_gallery_screen.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/reports/presentation/screens/reports_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Typed route paths for the app's top-level tabs.
class AppRoutes {
  const AppRoutes._();

  /// Dashboard tab path.
  static const String dashboard = '/';

  /// Water tab path.
  static const String water = '/water';

  /// Medicine tab path.
  static const String medicine = '/medicine';

  /// Prayer tab path.
  static const String prayer = '/prayer';

  /// Settings tab path.
  static const String settings = '/settings';

  /// Reports screen path (Run 15).
  static const String reports = '/reports';

  /// Achievement gallery screen path (Run 15).
  static const String achievements = '/achievements';
}

/// The app's root [GoRouter], rebuilt whenever `habitModules` changes.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return buildAppRouter(ref.watch(habitModulesProvider));
}

/// Builds the app's root [GoRouter]: a [StatefulShellRoute] with one branch
/// per bottom-nav tab (`technical/folder-structure.md`). Each module's own
/// branch uses that module's `routes` once its own run wires it up here
/// (the module contract's routes contribution point) — Prayer still uses a
/// placeholder single route until its own run does the same swap.
GoRouter buildAppRouter(List<HabitModule> modules) {
  final waterRoutes = modules.firstWhere((m) => m.id == 'water').routes;
  final medicineRoutes = modules.firstWhere((m) => m.id == 'medicine').routes;
  final prayerRoutes = modules.firstWhere((m) => m.id == 'prayer').routes;
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    // ponytail: no PIN lock exists yet (Run 12) — this always allows
    // navigation. Replace the `null` with the real lock-state check once
    // `pin_lock_service.dart` exists; call sites elsewhere don't change.
    redirect: (context, state) => null,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'achievements',
                    builder: (context, state) =>
                        const AchievementGalleryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: waterRoutes),
          StatefulShellBranch(routes: medicineRoutes),
          StatefulShellBranch(routes: prayerRoutes),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        const NotificationReliabilityScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
