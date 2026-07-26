import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_reliability_screen.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/security/lock_reset_screen.dart';
import 'package:habit_tracker/core/security/lock_screen.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/widgets/app_scaffold.dart';
import 'package:habit_tracker/features/achievements/presentation/screens/achievement_gallery_screen.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:habit_tracker/features/onboarding/presentation/screens/onboarding_module_selection_screen.dart';
import 'package:habit_tracker/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:habit_tracker/features/reports/presentation/screens/past_recaps_screen.dart';
import 'package:habit_tracker/features/reports/presentation/screens/reports_screen.dart';
import 'package:habit_tracker/features/reports/presentation/screens/yearly_recap_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/backup_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/data_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/pin_set_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/pin_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/quiet_hours_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/ramadan_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/theme_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/screens/unlocks_screen.dart';
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

  /// PIN lock settings screen.
  static const String settingsPin = '/settings/pin';

  /// Set/change PIN screen.
  static const String settingsPinSet = '/settings/pin/set';

  /// Language settings screen.
  static const String settingsLanguage = '/settings/language';

  /// Theme settings screen.
  static const String settingsTheme = '/settings/theme';

  /// Export/import/share-logs screen.
  static const String settingsData = '/settings/data';

  /// Google Drive backup/restore settings.
  static const String settingsBackup = '/settings/backup';

  /// About/version/licenses screen.
  static const String settingsAbout = '/settings/about';

  /// Quiet hours settings screen.
  static const String settingsQuietHours = '/settings/quiet-hours';

  /// Ramadan mode settings screen.
  static const String settingsRamadan = '/settings/ramadan';

  /// Past recaps list screen.
  static const String settingsPastRecaps = '/settings/past-recaps';

  /// Yearly recap full-screen viewer (receives YearSummary via extra).
  static const String recap = '/reports/recap';

  /// PIN entry (top-level redirect target, not a normal pushed route).
  static const String lock = '/lock';

  /// Forgot-PIN reset confirmation.
  static const String lockReset = '/lock/reset';
}

/// The app's root [GoRouter], rebuilt whenever `habitModules` changes.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return buildAppRouter(
    ref.watch(habitModulesProvider),
    ref.watch(pinLockControllerProvider),
  );
}

/// Builds the app's root [GoRouter]: a [StatefulShellRoute] with one branch
/// per bottom-nav tab (`technical/folder-structure.md`). Each module's own
/// branch uses that module's `routes` once its own run wires it up here
/// (the module contract's routes contribution point) — Prayer still uses a
/// placeholder single route until its own run does the same swap.
GoRouter buildAppRouter(
  List<HabitModule> modules,
  PinLockController pinLockController,
) {
  final waterRoutes = modules.firstWhere((m) => m.id == 'water').routes;
  final medicineRoutes = modules.firstWhere((m) => m.id == 'medicine').routes;
  final prayerRoutes = modules.firstWhere((m) => m.id == 'prayer').routes;
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) async {
      final path = state.matchedLocation;
      if (path == AppRoutes.lock || path == AppRoutes.lockReset) return null;
      if (!await pinLockController.isCurrentlyLocked()) return null;
      final from = Uri.encodeComponent(state.uri.toString());
      return '${AppRoutes.lock}?from=$from';
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWelcomeScreen(),
        routes: [
          GoRoute(
            path: 'modules',
            builder: (context, state) =>
                const OnboardingModuleSelectionScreen(),
          ),
          GoRoute(
            path: 'complete',
            builder: (context, state) => const OnboardingCompleteScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) =>
            LockScreen(returnTo: state.uri.queryParameters['from']),
        routes: [
          GoRoute(
            path: 'reset',
            builder: (context, state) => const LockResetScreen(),
          ),
        ],
      ),
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
                    routes: [
                      GoRoute(
                        path: 'recap',
                        builder: (context, state) => YearlyRecapScreen(
                          summary: state.extra! as YearSummary,
                        ),
                      ),
                    ],
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
                  GoRoute(
                    path: 'quiet-hours',
                    builder: (context, state) => const QuietHoursScreen(),
                  ),
                  GoRoute(
                    path: 'ramadan',
                    builder: (context, state) => const RamadanSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'pin',
                    builder: (context, state) => const PinSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'set',
                        builder: (context, state) => PinSetScreen(
                          oldPin: state.extra as String?,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'theme',
                    builder: (context, state) => const ThemeSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'language',
                    builder: (context, state) => const LanguageSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'data',
                    builder: (context, state) => const DataSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'backup',
                    builder: (context, state) => const BackupSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'past-recaps',
                    builder: (context, state) => const PastRecapsScreen(),
                  ),
                  GoRoute(
                    path: 'unlocks',
                    builder: (context, state) => const UnlocksScreen(),
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
