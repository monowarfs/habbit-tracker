import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:intl/intl.dart';

/// The visual recap card itself — a fixed 1080x1920 portrait share
/// image, laid out from a month's already-computed `List<ModuleReport>`
/// (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`). A plain, previewable
/// `Widget` — capture plumbing lives separately in
/// `recap_card_capture.dart`.
class MonthlyRecapCard extends StatelessWidget {
  /// Creates the recap card for [reports] (already filtered to modules
  /// with data by `AggregateReportUseCase`), anchored at [monthAnchor].
  const MonthlyRecapCard({
    required this.reports,
    required this.monthAnchor,
    super.key,
  });

  /// One entry per module with data this month.
  final List<ModuleReport> reports;

  /// Any day within the recapped month.
  final LocalDate monthAnchor;

  static const _width = 1080.0;
  static const _height = 1920.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Falls back to the ambient theme's primary color when there's
    // nothing to seed the gradient from — an empty `reports` list never
    // actually reaches this widget in practice (`ReportsScreen` disables
    // the share button first), but the widget itself stays correct
    // standalone regardless.
    final seedColor = reports.isEmpty
        ? Theme.of(context).colorScheme.primary
        : reports.first.accentColor;
    final monthName = DateFormat.MMMM().format(
      DateTime(monthAnchor.year, monthAnchor.month),
    );

    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            seedColor.withValues(alpha: 0.85),
            seedColor.withValues(alpha: 0.35),
          ],
        ),
      ),
      padding: const EdgeInsets.all(64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.self_improvement,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l10n.recapCardMonthLabel(monthName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 64),
          for (final report in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: report.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                        Text(
                          l10n.recapCardLongestStreak(report.longestStreak),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
