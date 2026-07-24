import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/domain/entities/stock_projection.dart';
import 'package:intl/intl.dart';

/// Shows when a medicine's stock is projected to run out
/// (`docs/superpowers/plans/ai-powered/
/// 03-predictive-stock-out-date-impl-plan.md`) — a derived, read-time-only
/// display, never persisted.
class StockProjectionCard extends StatelessWidget {
  /// Creates a stock projection card for [projection].
  const StockProjectionCard({required this.projection, super.key});

  /// The projection to display.
  final StockProjection projection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysRemaining = projection.daysRemaining;
    final projectedDate = projection.projectedDate;

    final String title;
    var showLowConfidenceFootnote = false;
    if (daysRemaining == 0) {
      title = l10n.stockProjectionAlreadyOut;
    } else if (daysRemaining == null || projectedDate == null) {
      title = l10n.stockProjectionNoData;
    } else {
      final locale = Localizations.localeOf(context).toString();
      title = l10n.stockProjectionBody(
        daysRemaining,
        DateFormat.yMMMd(locale).format(projectedDate.toLocal()),
      );
      showLowConfidenceFootnote = projection.confidence == 'low';
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.trending_down),
        title: Text(title),
        subtitle: showLowConfidenceFootnote
            ? Text(l10n.stockProjectionLowConfidence)
            : null,
      ),
    );
  }
}
