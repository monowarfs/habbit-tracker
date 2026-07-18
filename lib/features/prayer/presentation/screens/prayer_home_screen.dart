import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Placeholder for the Prayer module's home screen — the real domain/data
/// slice ships in Run 09, presentation in Run 10.
class PrayerHomeScreen extends StatelessWidget {
  /// Creates the prayer module placeholder screen.
  const PrayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(l10n.navPrayer)));
  }
}
