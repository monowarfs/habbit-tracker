import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/stock_card.dart';
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
    final medicine = ref.watch(medicineByIdProvider(medicineId)).value;
    final schedules = ref.watch(medicineSchedulesProvider(medicineId)).value;
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

    final dosesAsync = ref.watch(
      medicineRepositoryProvider,
    ); // repository read for adherence below

    return Scaffold(
      appBar: AppBar(
        title: Text(medicine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/medicine/$medicineId/edit'),
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
          const SizedBox(height: 16),
          Text('Next 7 days', style: Theme.of(context).textTheme.titleMedium),
          for (final instant in previewInstants)
            ListTile(
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                DateFormat.MMMEd().add_jm().format(instant.toLocal()),
              ),
            ),
          const SizedBox(height: 16),
          FutureBuilder<AdherenceStats>(
            future: dosesAsync
                .dosesInRange(today.addDays(-30), today)
                .then(
                  (doses) => calculateAdherence(doses: doses, now: clock.now()),
                ),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) return const SizedBox.shrink();
              final takenPct = stats.total == 0
                  ? 0
                  : ((stats.takenOnTime + stats.takenLate) / stats.total * 100)
                        .round();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    stats.total == 0
                        ? 'No dose history yet'
                        : 'Last 30 days: $takenPct% taken '
                              '(${stats.missed} missed, '
                              '${stats.skipped} skipped)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
