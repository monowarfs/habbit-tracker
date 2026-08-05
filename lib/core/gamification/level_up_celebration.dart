import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

/// Shows a brief celebration when the user reaches a new level — reuses
/// the existing streak-celebration overlay. Only wired from the
/// weekly-quest/boss claim flows (the two places an XP award already has
/// a `BuildContext` and is already showing a comparable "big moment"
/// celebration) — per-action water/medicine/prayer XP is awarded from
/// controllers, which have no `BuildContext` to show this from, so a
/// level-up crossed by an ordinary log/dose/prayer action surfaces only
/// via the dashboard's `XpLevelDisplay` updating, not a modal.
Future<void> showLevelUpCelebration(
  BuildContext context, {
  required int newLevel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showStreakCelebration(
    context,
    title: l10n.levelUpBody(newLevel),
    accentColor: Colors.deepPurple,
    icon: Icons.star,
  );
}
