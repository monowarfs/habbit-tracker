import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';

/// Shows a brief celebration when a same-day combo (every active module
/// complete) is detected — reuses the existing streak-celebration
/// overlay (confetti burst included) rather than a bespoke animation.
/// The overlay only has one title slot, so `comboCelebrationTitle` and
/// `comboXpBonus`'s amount are combined into one line at the call site.
/// No `modulesCompleted` param (unlike the plan's literal signature):
/// nothing renders that count — `comboCelebrationBody`'s copy ("All
/// modules done today!") doesn't need it either.
Future<void> showComboCelebration(
  BuildContext context, {
  required int xpBonus,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showStreakCelebration(
    context,
    title: '${l10n.comboCelebrationTitle} ${l10n.comboXpBonus(xpBonus)}',
    accentColor: Colors.orange,
    icon: Icons.auto_awesome,
  );
}
