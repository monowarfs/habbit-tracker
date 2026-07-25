import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Card reassuring users that their data is never pruned.
class DataLongevityGuaranteeCard extends StatelessWidget {
  /// Creates the data longevity guarantee card.
  const DataLongevityGuaranteeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.dataLongevityGuaranteeTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.dataLongevityGuaranteeBody),
            const SizedBox(height: 8),
            Text(
              l10n.dataLongevityGuaranteeMedicineCaveat,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
