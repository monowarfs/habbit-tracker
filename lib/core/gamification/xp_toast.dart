import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Shows a brief "+{amount} XP" snackbar after an action-level XP award.
/// Deliberately not shown for day-complete/streak/quest/boss XP — those
/// already get their own bigger celebration (or, for day-complete, no
/// separate UI moment at all) — this is only for the lightweight
/// per-action feedback loop (water log, dose marked done, prayer
/// checked). Called from each home screen's action handler, not from the
/// controller itself: controllers have no `BuildContext` to show a
/// snackbar from (the plan's own "called from each module's controller"
/// wording doesn't fit this codebase's Notifier pattern), and the XP
/// amount is a fixed constant per module/event
/// (`XpValues.forEvent(moduleId, 'action')`), so the widget layer can
/// compute it independently without the controller needing to report
/// anything back.
void showXpGainToast(BuildContext context, {required int amount}) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.xpGainToast(amount)),
      duration: const Duration(seconds: 2),
    ),
  );
}
