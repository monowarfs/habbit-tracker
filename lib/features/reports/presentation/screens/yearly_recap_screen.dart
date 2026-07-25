import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/yearly_recap_card.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/yearly_recap_hero_card.dart';

/// Full-screen story-style yearly recap viewer.
class YearlyRecapScreen extends StatefulWidget {
  /// Creates the yearly recap screen.
  const YearlyRecapScreen({required this.summary, super.key});

  /// The year summary to display.
  final YearSummary summary;

  @override
  State<YearlyRecapScreen> createState() => _YearlyRecapScreenState();
}

class _YearlyRecapScreenState extends State<YearlyRecapScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pageCount = widget.summary.modules.length + 1;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              if (index < widget.summary.modules.length) {
                return YearlyRecapCard(
                  moduleStats: widget.summary.modules[index],
                  yearNumber: widget.summary.yearNumber,
                );
              }
              return YearlyRecapHeroCard(
                summary: widget.summary,
              );
            },
          ),
          // Progress dots.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Close button.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Year label.
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                l10n.yearlyRecapYearLabel(widget.summary.yearNumber),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
