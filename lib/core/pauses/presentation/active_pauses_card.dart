import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/pauses/pause_providers.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Card shown at the top of a module screen when an active pause exists.
class ActivePausesCard extends ConsumerWidget {
  /// Creates the active pauses card.
  const ActivePausesCard({required this.moduleId, super.key});

  /// The module ID to check pauses for.
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder(
      future: ref.read(pauseServiceProvider).activePauses(moduleId),
      builder: (context, snapshot) {
        final pauses = snapshot.data;
        if (pauses == null || pauses.isEmpty) {
          return const SizedBox.shrink();
        }

        final pause = pauses.first;
        final endDate = LocalDate.parse(pause.endDate);

        return Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.pauseActiveLabel(endDate.toIso()),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => _cancelPause(context, ref, pause.id, l10n),
                  child: Text(l10n.pauseCancelButton),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelPause(
    BuildContext context,
    WidgetRef ref,
    String pauseId,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pauseConfirmCancel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pauseCancelButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pauseServiceProvider).cancelPause(pauseId);
    }
  }
}
