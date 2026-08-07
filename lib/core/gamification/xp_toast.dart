import 'package:flutter/material.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';
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
///
/// This is the single call site backing the TalkBack/VoiceOver audit's
/// Task 7 ("water log, dose marked done, prayer checked" — its own
/// wording, matching this doc comment above): [SnackBar] already marks
/// itself a live region (`liveRegion: true` in Flutter's own
/// implementation), but that behavior isn't reliable on every platform,
/// so this also pushes an explicit announcement.
void showXpGainToast(BuildContext context, {required int amount}) {
  final l10n = AppLocalizations.of(context)!;
  final message = l10n.xpGainToast(amount);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
  SemanticLabels.announce(context, message);
}
