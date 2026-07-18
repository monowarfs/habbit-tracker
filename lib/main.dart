import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';

void main() {
  runApp(const ProviderScope(child: HabitTrackerApp()));
}

final GoRouter _router = buildAppRouter();

/// The app's root widget: theme, localization, and router wiring.
class HabitTrackerApp extends ConsumerWidget {
  /// Creates the root app widget.
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(isBangla: isBangla),
      darkTheme: AppTheme.dark(isBangla: isBangla),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
