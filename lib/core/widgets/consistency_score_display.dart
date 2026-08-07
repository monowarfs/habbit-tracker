import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

/// Shows the dashboard's composite 0-100 "Consistency Score"
/// (`ConsistencyScoreCalculator`) — the score itself with color coding, a
/// qualitative label, and a per-module completion breakdown, per
/// `docs/superpowers/specs/08-analytics/05-consistency-score-IMPLEMENTATION-PLAN.md`
/// Task 3.
class ConsistencyScoreDisplay extends StatelessWidget {
  /// Creates a consistency score display.
  const ConsistencyScoreDisplay({
    required this.score,
    this.breakdown = const {},
    super.key,
  });

  /// The composite score (0-100).
  final int score;

  /// Each visible module's own completion percentage (0-100) for today,
  /// keyed by display name — shown as a legibility breakdown so the
  /// composite doesn't read as an opaque number.
  final Map<String, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = _colorFor(score, theme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.consistencyScoreTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.consistencyScoreValue(score),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _labelFor(l10n, score),
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final entry in breakdown.entries)
                Text(
                  '${entry.key}: ${entry.value}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorFor(int score, ThemeData theme) {
    if (score >= 80) return theme.semanticColors.success;
    if (score >= 50) return Colors.amber.shade800;
    return theme.semanticColors.missed;
  }

  String _labelFor(AppLocalizations l10n, int score) {
    if (score >= 80) return l10n.consistencyScoreExcellent;
    if (score >= 50) return l10n.consistencyScoreGood;
    return l10n.consistencyScoreNeedsWork;
  }
}
