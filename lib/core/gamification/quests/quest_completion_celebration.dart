import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

/// Shows a brief celebration when a weekly quest's reward is claimed —
/// reuses the existing streak-celebration overlay rather than a bespoke
/// animation. No XP amount is shown: the cross-module XP system (spec 02)
/// hasn't been built, so this only confirms the claim landed.
Future<void> showQuestCompletionCelebration(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showStreakCelebration(
    context,
    title: l10n.weeklyQuestClaimed,
    accentColor: Colors.amber,
    icon: Icons.emoji_events,
  );
}
