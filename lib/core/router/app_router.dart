import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_reliability_screen.dart';
import 'package:habit_tracker/core/widgets/app_scaffold.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
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
}

/// The app's root [GoRouter], rebuilt whenever `habitModules` changes.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return buildAppRouter(ref.watch(habitModulesProvider));
}

/// Builds the app's root [GoRouter]: a [StatefulShellRoute] with one branch
/// per bottom-nav tab (`technical/folder-structure.md`). Each module's own
/// branch uses that module's `routes` once its own run wires it up here
/// (the module contract's routes contribution point) — Medicine/Prayer
/// still use placeholder single routes until their own runs do the same
/// swap.
GoRouter buildAppRouter(List<HabitModule> modules) {
  final waterRoutes = modules.firstWhere((m) => m.id == 'water').routes;
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
              ),
            ],
          ),
          StatefulShellBranch(routes: waterRoutes),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.medicine,
                builder: (context, state) => const MedicineHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.prayer,
                builder: (context, state) => const PrayerHomeScreen(),
              ),
            ],
          ),
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
