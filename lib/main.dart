import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/notifications/notification_bootstrap.dart';
import 'package:habit_tracker/core/notifications/notification_planner.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/notifications/notification_workmanager.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/security/screen_privacy_service.dart';
import 'package:habit_tracker/core/shortcuts/quick_action_handler.dart';
import 'package:habit_tracker/core/shortcuts/shortcut_items.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/app_error_widget.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';
import 'package:quick_actions/quick_actions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesInitialized();
  FlutterError.onError = (details) {
    logger.e(
      'uncaught Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) => const AppErrorWidget();

  // An explicit container (not a bare `ProviderScope`): the notification
  // deep-link callback needs to `go()` the router from outside any widget's
  // `BuildContext` (`core/notifications/notification_bootstrap.dart`), and
  // the app-resume re-planning trigger needs the same `AppDatabase` this
  // container hands out to the rest of the app.
  final container = ProviderContainer();
  final db = container.read(databaseProvider);

  await NotificationBootstrap(NotificationService.instance).init(
    onDeepLink: (route) => container.read(appRouterProvider).go(route),
  );
  final coldStartDeepLink = await NotificationService.instance
      .checkLaunchDeepLink();
  await registerNotificationWorkmanager();

  await const QuickActions().initialize((type) async {
    await handleQuickAction(type: type, db: db);
    container.read(appRouterProvider).go('/$type');
  });

  runZonedGuarded(
    () {
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: HabitTrackerApp(initialDeepLink: coldStartDeepLink),
        ),
      );
      // Re-planning trigger 1 (`strategies/notifications.md`): always
      // top up on app start; `_AppLifecycleReplanner` below repeats this on
      // every subsequent resume.
      unawaited(planAndApplyNotifications(db: db));
    },
    (error, stack) =>
        logger.e('uncaught zone error', error: error, stackTrace: stack),
  );
}

/// The app's root widget: theme, localization, and router wiring.
class HabitTrackerApp extends ConsumerStatefulWidget {
  /// Creates the root app widget. [initialDeepLink], if set, is the route a
  /// notification tap cold-started the app into (FR-C-09).
  const HabitTrackerApp({super.key, this.initialDeepLink});

  /// Route to navigate to once, right after the first frame.
  final String? initialDeepLink;

  @override
  ConsumerState<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends ConsumerState<HabitTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final route = widget.initialDeepLink;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(appRouterProvider).go(route),
      );
    }
    // Registers the 3 static home-screen/app-shortcut items
    // (`core/shortcuts/`) once now and again on every locale change, so
    // labels stay in the user's chosen language. `listenManual` (not the
    // build()-safe `listen`) because this needs `fireImmediately`, which
    // `listen` doesn't support.
    ref.listenManual<Locale>(localeControllerProvider, (previous, next) {
      final l10n = lookupAppLocalizations(next);
      unawaited(
        const QuickActions().setShortcutItems(buildShortcutItems(l10n)),
      );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-planning trigger 1 (`strategies/notifications.md`): every
    // foreground resume, not just cold start.
    if (state == AppLifecycleState.resumed) {
      unawaited(planAndApplyNotifications(db: ref.read(databaseProvider)));
    }
    // PIN resume-timeout reference point (`strategies/security.md`) —
    // records "now" every time the app leaves the foreground, so
    // `PinLockController.isCurrentlyLocked` can compare against it on
    // the next resume/navigation.
    if (state == AppLifecycleState.paused) {
      unawaited(ref.read(pinLockControllerProvider).recordBackgrounded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
    // Single call site for applying screen privacy (`strategies/
    // security.md`): fires once on cold start with whatever was
    // persisted, and again on every Settings toggle — never called
    // directly from `PinSettingsScreen`.
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (
      previous,
      next,
    ) {
      final enabled = next.value?.screenPrivacyEnabled;
      if (enabled == null) return;
      if (previous?.value?.screenPrivacyEnabled == enabled) return;
      unawaited(
        enabled
            ? ScreenPrivacyService().enable()
            : ScreenPrivacyService().disable(),
      );
    });
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(isBangla: isBangla),
      darkTheme: AppTheme.dark(isBangla: isBangla),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
