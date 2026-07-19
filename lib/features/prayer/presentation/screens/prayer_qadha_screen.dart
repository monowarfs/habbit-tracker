import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final counters =
        ref.watch(prayerQadhaCountersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Qadha')),
      body: ListView(
        children: [
          for (final counter in counters)
            ListTile(
              title: Text(_labelFor(counter.prayerName)),
              subtitle: Text('${counter.count} owed'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Mark one made up',
                    onPressed: counter.count == 0
                        ? null
                        : () => ref
                              .read(prayerControllerProvider.notifier)
                              .markQadhaMakeup(counter.prayerName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Set balance',
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

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    PrayerQadhaCounter counter,
  ) async {
    final controller = TextEditingController(
      text: counter.count.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Qadha balance'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Save'),
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
