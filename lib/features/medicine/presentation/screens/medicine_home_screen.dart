import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Placeholder for the Medicine module's home screen — the real domain/
/// data slice ships in Run 07, presentation in Run 08.
class MedicineHomeScreen extends StatelessWidget {
  /// Creates the medicine module placeholder screen.
  const MedicineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(l10n.navMedicine)));
  }
}
