import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:intl/intl.dart';

/// One row in the today's-dose timeline.
class DoseTile extends StatelessWidget {
  /// Creates a dose tile for [view].
  const DoseTile({
    required this.view,
    required this.onDone,
    required this.onSkip,
    this.highlighted = false,
    super.key,
  });

  /// The dose/medicine/status to render.
  final MedicineDoseView view;

  /// Called when the user marks this dose done.
  final VoidCallback onDone;

  /// Called when the user marks this dose skipped.
  final VoidCallback onSkip;

  /// Whether this tile arrived from a notification deep link.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ponytail: nullable, not `!` — a raw `MaterialApp` (as in tests) has
    // no `AppSemanticColors` extension registered; other Water widgets
    // (`water_progress_ring.dart`, `streak_card.dart`) use the same
    // `?? fallback` pattern for this reason.
    final semantic = theme.extension<AppSemanticColors>();
    final (label, color) = switch (view.effectiveStatus) {
      MedicineDoseStatus.upcoming => ('Upcoming', theme.colorScheme.outline),
      MedicineDoseStatus.due => ('Due', theme.colorScheme.primary),
      MedicineDoseStatus.done => ('Done', semantic?.success ?? Colors.green),
      MedicineDoseStatus.missed => ('Missed', theme.colorScheme.error),
      MedicineDoseStatus.skipped => ('Skipped', theme.colorScheme.outline),
    };
    final resolved =
        view.effectiveStatus == MedicineDoseStatus.done ||
        view.effectiveStatus == MedicineDoseStatus.skipped;

    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.medication, color: color),
        ),
        title: Text(view.medicine.name),
        // Two `Text`s, not one interpolated string: the status half needs
        // its own color to actually read as "visually distinct" (FR-M-06)
        // — a missed dose isn't just an icon-colored variant, the label
        // itself is red — and `find.text('Missed')` (testing.md suite 10)
        // needs the status isolated as its own widget to match on.
        subtitle: Row(
          children: [
            Text(DateFormat.jm().format(view.dose.scheduledFor.toLocal())),
            const Text(' · '),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: resolved
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Skip',
                    onPressed: onSkip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Done',
                    onPressed: onDone,
                  ),
                ],
              ),
      ),
    );
  }
}
