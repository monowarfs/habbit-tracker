import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/responsive_breakpoints.dart';

/// The nav shell wrapping every top-level tab
/// (`technical/folder-structure.md`'s `StatefulShellRoute`).
///
/// Renders a bottom [NavigationBar] on phone widths and a
/// [NavigationRail] side rail on tablet/landscape widths.
class AppScaffold extends StatelessWidget {
  /// Creates the nav shell for [navigationShell].
  const AppScaffold({required this.navigationShell, super.key});

  /// The shell route's navigation state, tracking each branch's own stack.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final navIcons = [
      (icon: Icons.dashboard_outlined, selected: Icons.dashboard, accent: null),
      (
        icon: Icons.water_drop_outlined,
        selected: Icons.water_drop,
        accent: ModuleAccents.water,
      ),
      (
        icon: Icons.medication_outlined,
        selected: Icons.medication,
        accent: ModuleAccents.medicine,
      ),
      (
        icon: Icons.mosque_outlined,
        selected: Icons.mosque,
        accent: ModuleAccents.prayer,
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        accent: null,
      ),
    ];

    final labels = [
      l10n.navDashboard,
      l10n.navWater,
      l10n.navMedicine,
      l10n.navPrayer,
      l10n.navSettings,
    ];

    if (isWideLayout(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (i, icon) in navIcons.indexed)
                  NavigationRailDestination(
                    icon: Icon(icon.icon),
                    selectedIcon: Icon(
                      icon.selected,
                      color: icon.accent,
                    ),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          for (final (i, icon) in navIcons.indexed)
            NavigationDestination(
              icon: Icon(icon.icon),
              selectedIcon: Icon(icon.selected, color: icon.accent),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}
