import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Inline card prompting the user to recalibrate their goal.
class RecalibrationCard extends StatelessWidget {
  /// Creates the recalibration card.
  const RecalibrationCard({
    required this.onConfirmed,
    required this.onDeferred,
    super.key,
  });

  /// Called when the user taps "Still right".
  final VoidCallback onConfirmed;

  /// Called when the user taps "Remind later".
  final VoidCallback onDeferred;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.track_changes_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.recalibrationTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recalibrationBody,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: onConfirmed,
                  child: Text(l10n.recalibrationConfirm),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDeferred,
                  child: Text(l10n.recalibrationDefer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
