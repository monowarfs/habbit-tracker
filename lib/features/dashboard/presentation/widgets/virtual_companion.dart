import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/companion/companion_mood.dart';
import 'package:habit_tracker/core/gamification/companion/companion_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

// ponytail: static icon + color per mood — no Lottie art assets exist yet.
// Swap the icon/color mapping below for `lottie.Lottie.asset(...)` once
// assets/companion/*.json are produced; MediaQuery.disableAnimations
// (Reduce-Motion) can then fall back to this same static rendering.
const Map<CompanionMood, IconData> _moodIcons = {
  CompanionMood.thriving: Icons.sentiment_very_satisfied,
  CompanionMood.happy: Icons.sentiment_satisfied,
  CompanionMood.neutral: Icons.sentiment_neutral,
  CompanionMood.worried: Icons.sentiment_dissatisfied,
};

Color _moodColor(CompanionMood mood, ThemeData theme) {
  // Falls back to the light/dark defaults rather than force-unwrapping:
  // any MaterialApp not built from AppTheme.light()/dark() (widget tests
  // that hand-roll a bare MaterialApp, e.g.) has no AppSemanticColors
  // extension registered at all.
  final semanticColors =
      theme.extension<AppSemanticColors>() ??
      (theme.brightness == Brightness.dark
          ? AppSemanticColors.dark
          : AppSemanticColors.light);
  final success = semanticColors.success;
  return switch (mood) {
    CompanionMood.thriving || CompanionMood.happy => success,
    CompanionMood.neutral => theme.colorScheme.onSurfaceVariant,
    CompanionMood.worried => theme.colorScheme.error,
  };
}

/// A dashboard card showing the virtual companion's mood, derived from
/// recent day-completion history (D-gamification-03).
class VirtualCompanion extends ConsumerWidget {
  /// Creates the companion card.
  const VirtualCompanion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final moodAsync = ref.watch(companionMoodProvider);
    if (moodAsync.hasError) {
      logger.w(
        'companion mood derivation failed',
        error: moodAsync.error,
        stackTrace: moodAsync.stackTrace,
      );
    }
    final mood = moodAsync.value;
    if (mood == null) return const SizedBox.shrink();

    final statusText = switch (mood) {
      CompanionMood.thriving => l10n.companionStatusThriving,
      CompanionMood.happy => l10n.companionStatusHappy,
      CompanionMood.neutral => l10n.companionStatusNeutral,
      CompanionMood.worried => l10n.companionStatusWorried,
    };

    return Semantics(
      label: '${l10n.companionName}: $statusText. ${l10n.companionTapHint}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _moodIcons[mood],
                size: 40,
                color: _moodColor(mood, Theme.of(context)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.companionName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(statusText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
