import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// The dashboard tab. Shows an empty state until a module is enabled.
class DashboardScreen extends StatelessWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDashboard)),
      body: Center(child: Text(l10n.emptyDashboardMessage)),
    );
  }
}
