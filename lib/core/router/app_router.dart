import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/widgets/app_scaffold.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';

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

/// Builds the app's root [GoRouter]: a [StatefulShellRoute] with one branch
/// per bottom-nav tab (`technical/folder-structure.md`).
GoRouter buildAppRouter() {
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.water,
                builder: (context, state) => const WaterHomeScreen(),
              ),
            ],
          ),
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
