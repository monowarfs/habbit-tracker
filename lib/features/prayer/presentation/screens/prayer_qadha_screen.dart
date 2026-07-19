import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Five Qadha counters with a "−1" make-up control and manual balance
/// entry (FR-P-04/05).
class PrayerQadhaScreen extends ConsumerWidget {
  /// Creates the Qadha screen.
  const PrayerQadhaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerQadhaTitle)),
      body: ListView(
        children: [
          for (final counter in counters)
            ListTile(
              title: Text(_labelFor(l10n, counter.prayerName)),
              subtitle: Text(l10n.prayerQadhaCountLabel(counter.count)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: l10n.prayerQadhaMakeupButton,
                    onPressed: counter.count == 0
                        ? null
                        : () => ref
                              .read(prayerControllerProvider.notifier)
                              .markQadhaMakeup(counter.prayerName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.prayerQadhaEditButton,
                    onPressed: () => _showEditDialog(
                      context,
                      ref,
                      counter,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, PrayerName name) => switch (name) {
    PrayerName.fajr => l10n.prayerNameFajr,
    PrayerName.dhuhr => l10n.prayerNameDhuhr,
    PrayerName.asr => l10n.prayerNameAsr,
    PrayerName.maghrib => l10n.prayerNameMaghrib,
    PrayerName.isha => l10n.prayerNameIsha,
  };

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    PrayerQadhaCounter counter,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: counter.count.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.prayerQadhaEditButton),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(prayerControllerProvider.notifier)
          .setQadhaBalance(counter.prayerName, result);
    }
  }
}
