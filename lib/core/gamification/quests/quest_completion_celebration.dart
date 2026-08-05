import 'package:flutter/material.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

/// Shows a brief celebration when a weekly quest or boss challenge's
/// reward is claimed — reuses the existing streak-celebration overlay
/// rather than a bespoke animation. [title] is caller-formatted (e.g.
/// `l10n.weeklyQuestClaimed(xpAmount)`) so this stays agnostic to which
/// of the two claim flows (or their XP amount) triggered it.
Future<void> showQuestCompletionCelebration(
  BuildContext context, {
  required String title,
}) {
  return showStreakCelebration(
    context,
    title: title,
    accentColor: Colors.amber,
    icon: Icons.emoji_events,
  );
}
