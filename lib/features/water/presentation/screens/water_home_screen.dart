import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Placeholder for the Water module's home screen — the real domain/data/
/// presentation slice ships in Run 06.
class WaterHomeScreen extends StatelessWidget {
  /// Creates the water module placeholder screen.
  const WaterHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(l10n.navWater)));
  }
}
