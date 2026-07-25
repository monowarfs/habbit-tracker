import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/stock_card.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/stock_projection_card.dart';
import 'package:intl/intl.dart';

/// A medicine's detail screen: 7-day schedule preview (computed directly
/// via `expandRepeatRule`, not a DB read — cheaper than materializing
/// just to render a preview), stock/refill, adherence.
class MedicineDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [medicineId].
  const MedicineDetailScreen({required this.medicineId, super.key});

  /// The medicine to show.
  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final medicine = ref.watch(medicineByIdProvider(medicineId)).value;
    final schedules = ref.watch(medicineSchedulesProvider(medicineId)).value;
    final stockProjection = ref
        .watch(stockProjectionProvider(medicineId))
        .value;
    final controller = ref.read(medicineControllerProvider.notifier);

    if (medicine == null || schedules == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = LocalDate.fromDateTime(clock.now());
    final previewEnd = today.addDays(6);
    final previewInstants = <DateTime>[
      for (final schedule in schedules)
        ...expandRepeatRule(
          rule: schedule.rule,
          anchor: schedule.startDate,
          rangeStart: schedule.startDate.compareTo(today) > 0
              ? schedule.startDate
              : today,
          rangeEnd: schedule.endDate == null
              ? previewEnd
              : (schedule.endDate!.compareTo(previewEnd) < 0
                    ? schedule.endDate!
                    : previewEnd),
        ),
    ]..sort();

    final adherenceDoses = ref
        .watch(
          medicineDosesInRangeProvider((start: today.addDays(-30), end: today)),
        )
        .value;

    return Scaffold(
      appBar: AppBar(
        title: Text(medicine.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(
              context,
              ref,
              value,
              medicine.name,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(l10n.medicineDetailRename),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Text(l10n.medicineDetailEditSchedule),
              ),
              if (medicine.archivedAt == null)
                PopupMenuItem(
                  value: 'archive',
                  child: Text(l10n.archiveAction),
                )
              else
                PopupMenuItem(
                  value: 'unarchive',
                  child: Text(l10n.reviveAction),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (medicine.dosageNote != null) Text(medicine.dosageNote!),
          const SizedBox(height: 8),
          StockCard(
            medicine: medicine,
            onRefill: (amount) => controller.refillStock(medicineId, amount),
          ),
          if (medicine.stockEnabled &&
              medicine.stockCount != null &&
              stockProjection != null) ...[
            const SizedBox(height: 8),
            StockProjectionCard(projection: stockProjection),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.medicineDetailNext7DaysLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final instant in previewInstants)
            ListTile(
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                DateFormat.MMMEd().add_jm().format(instant.toLocal()),
              ),
            ),
          const SizedBox(height: 16),
          if (adherenceDoses != null)
            Builder(
              builder: (context) {
                final stats = calculateAdherence(
                  doses: adherenceDoses,
                  now: clock.now(),
                );
                final takenPct = stats.total == 0
                    ? 0
                    : ((stats.takenOnTime + stats.takenLate) /
                              stats.total *
                              100)
                          .round();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      stats.total == 0
                          ? l10n.medicineDetailNoHistory
                          : l10n.medicineDetailStatsSummary(
                              takenPct,
                              stats.missed,
                              stats.skipped,
                            ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String currentName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(medicineControllerProvider.notifier);
    switch (action) {
      case 'rename':
        final nameController = TextEditingController(text: currentName);
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.medicineDetailRename),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.medicineFormNameLabel,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(nameController.text.trim()),
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty && newName != currentName) {
          await controller.updateMedicineName(medicineId, newName);
        }
      case 'edit':
        if (context.mounted) {
          await context.push('/medicine/$medicineId/edit');
        }
      case 'archive':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.archiveConfirmTitle(currentName)),
            content: Text(l10n.archiveConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.archiveConfirmButton),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await controller.archiveMedicine(medicineId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.archiveSnackSuccess(currentName))),
            );
            context.pop();
          }
        }
      case 'unarchive':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.reviveConfirmTitle(currentName)),
            content: Text(l10n.reviveConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.reviveConfirmButton),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await controller.restoreMedicine(medicineId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.reviveSnackSuccess(currentName))),
            );
            context.pop();
          }
        }
    }
  }
}
