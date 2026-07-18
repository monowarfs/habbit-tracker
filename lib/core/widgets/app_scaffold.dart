import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

/// The bottom-nav shell wrapping every top-level tab
/// (`technical/folder-structure.md`'s `StatefulShellRoute`).
class AppScaffold extends StatelessWidget {
  /// Creates the bottom-nav shell for [navigationShell].
  const AppScaffold({required this.navigationShell, super.key});

  /// The shell route's navigation state, tracking each branch's own stack.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: l10n.navDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.water_drop_outlined),
        selectedIcon: const Icon(
          Icons.water_drop,
          color: ModuleAccents.water,
        ),
        label: l10n.navWater,
      ),
      NavigationDestination(
        icon: const Icon(Icons.medication_outlined),
        selectedIcon: const Icon(
          Icons.medication,
          color: ModuleAccents.medicine,
        ),
        label: l10n.navMedicine,
      ),
      NavigationDestination(
        icon: const Icon(Icons.mosque_outlined),
        selectedIcon: const Icon(Icons.mosque, color: ModuleAccents.prayer),
        label: l10n.navPrayer,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n.navSettings,
      ),
    ];
    // ponytail: tabs hard-coded to the 3 known modules; switch to iterating
    // habitModules once module_registry.dart actually has entries (Run 06+).
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: destinations,
      ),
    );
  }
}
