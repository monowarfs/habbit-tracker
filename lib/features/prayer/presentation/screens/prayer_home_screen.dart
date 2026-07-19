import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/widgets/prayer_tile.dart';

/// Today's prayer checklist — countdown to next prayer (via each tile's
/// live status), Gregorian date, tap-to-mark-prayed toggle (FR-P-07).
class PrayerHomeScreen extends ConsumerWidget {
  /// Creates the checklist screen.
  const PrayerHomeScreen({super.key, this.highlightRecordId});

  /// Record id to highlight when opened via a notification deep link.
  final String? highlightRecordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(todaysPrayerViewsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prayerHomeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: l10n.prayerHomeHistoryButton,
            onPressed: () => context.push('/prayer/history'),
          ),
          IconButton(
            icon: const Icon(Icons.pending_actions),
            tooltip: l10n.prayerHomeQadhaButton,
            onPressed: () => context.push('/prayer/qadha'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.prayerHomeStatsButton,
            onPressed: () => context.push('/prayer/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.prayerHomeSettingsButton,
            onPressed: () => context.push('/prayer/settings'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? Center(child: Text(l10n.prayerHomeEmpty))
          : ListView.builder(
              itemCount: views.length,
              itemBuilder: (context, index) {
                final view = views[index];
                return PrayerTile(
                  view: view,
                  highlighted: view.record.id == highlightRecordId,
                  onToggle: () => ref
                      .read(prayerControllerProvider.notifier)
                      .togglePrayed(
                        view.record.id,
                        currentlyPrayed:
                            view.effectiveStatus == PrayerStatus.prayed,
                      ),
                );
              },
            ),
    );
  }
}
