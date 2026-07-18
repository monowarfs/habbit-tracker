import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/dose_tile.dart';

/// The Medicine module's home screen: today's dose timeline, grouped
/// chronologically, tap to take/skip (FR-M-02's most complex UI surface).
class MedicineHomeScreen extends ConsumerWidget {
  /// Creates the medicine home screen. [highlightDoseId], if set, came
  /// from a notification tap deep link (FR-C-09).
  const MedicineHomeScreen({super.key, this.highlightDoseId});

  /// Dose id to visually highlight, if opened via deep link.
  final String? highlightDoseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(todaysDoseViewsProvider);
    final controller = ref.read(medicineControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMedicine),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'All medicines',
            onPressed: () => context.push('/medicine/list'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => context.push('/medicine/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add medicine',
            onPressed: () => context.push('/medicine/new'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? const Center(child: Text('No doses scheduled for today'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final view in views)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DoseTile(
                      view: view,
                      highlighted: view.dose.id == highlightDoseId,
                      onDone: () => controller.markDoseDone(view.dose.id),
                      onSkip: () => controller.markDoseSkipped(view.dose.id),
                    ),
                  ),
              ],
            ),
    );
  }
}
