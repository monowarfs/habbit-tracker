import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/recaps/recap_providers.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Screen listing past yearly recaps.
class PastRecapsScreen extends ConsumerWidget {
  /// Creates the past recaps screen.
  const PastRecapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recapRepo = ref.watch(recapRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pastRecapsTitle)),
      body: FutureBuilder<List<RecapRow>>(
        future: recapRepo.allRecaps(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recaps = snapshot.data ?? [];
          if (recaps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.pastRecapsEmpty,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recaps.length,
            itemBuilder: (context, index) {
              final recap = recaps[index];
              final generatedDate = DateTime.fromMillisecondsSinceEpoch(
                recap.generatedAt,
                isUtc: true,
              ).toLocal();
              final month = generatedDate.month.toString().padLeft(2, '0');
              final day = generatedDate.day.toString().padLeft(2, '0');
              final dateStr = '${generatedDate.year}-$month-$day';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.emoji_events),
                  title: Text(
                    l10n.yearlyRecapYearLabel(recap.yearNumber),
                  ),
                  subtitle: Text(dateStr),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final summary = _deserializeSummary(
                      recap.summaryJson,
                      recap.yearNumber,
                    );
                    if (summary == null) return;
                    unawaited(
                      context.push(
                        '/reports/recap',
                        extra: summary,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  YearSummary? _deserializeSummary(String json, int yearNumber) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final modulesRaw = map['modules'] as List<dynamic>? ?? [];
      final modules = modulesRaw.map((m) {
        final mm = m as Map<String, dynamic>;
        return ModuleYearStats(
          moduleId: mm['moduleId'] as String,
          displayName: mm['displayName'] as String,
          accentColorValue: mm['accentColorValue'] as int,
          totalMl: mm['totalMl'] as int?,
          averageDailyMl: (mm['averageDailyMl'] as num?)?.toDouble(),
          daysGoalMet: mm['daysGoalMet'] as int?,
          totalDoses: mm['totalDoses'] as int?,
          dosesTaken: mm['dosesTaken'] as int?,
          adherencePercent: (mm['adherencePercent'] as num?)?.toDouble(),
          longestConsecutiveStreak: mm['longestConsecutiveStreak'] as int?,
          totalPrayers: mm['totalPrayers'] as int?,
          prayersCompleted: mm['prayersCompleted'] as int?,
          onTimePercent: (mm['onTimePercent'] as num?)?.toDouble(),
          longestStreak: mm['longestStreak'] as int?,
          longestStreakAll: mm['longestStreakAll'] as int?,
          bestDayValue: mm['bestDayValue'] as int?,
          monthsActive: mm['monthsActive'] as int?,
          monthsTotal: mm['monthsTotal'] as int?,
        );
      }).toList();

      final installDateStr = map['installDate'] as String;
      final installDate = LocalDate.parse(installDateStr);

      return YearSummary(
        yearNumber: map['yearNumber'] as int? ?? yearNumber,
        installDate: installDate,
        activeDays: map['activeDays'] as int? ?? 0,
        modules: modules,
      );
    } on Object {
      return null;
    }
  }
}
