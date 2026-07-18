import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:intl/intl.dart';

/// Adherence chart across all medicines over the last 7 days, plus a
/// missed-doses list (FR-M-08).
class MedicineStatsScreen extends ConsumerWidget {
  /// Creates the medicine stats screen.
  const MedicineStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDate.fromDateTime(clock.now());
    final start = today.addDays(-6);
    final doses = ref
        .watch(medicineDosesInRangeProvider((start: start, end: today)))
        .value;

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine stats')),
      body: Builder(
        builder: (context) {
          if (doses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = clock.now();
          final byDay = <LocalDate, int>{};
          final missed = <MedicineDose>[];
          for (final dose in doses) {
            final status = effectiveDoseStatus(
              storedStatus: dose.storedStatus,
              scheduledFor: dose.scheduledFor,
              now: now,
              graceWindowMinutes: dose.graceWindowMinutes,
            );
            if (status == MedicineDoseStatus.done) {
              final day = LocalDate.fromDateTime(dose.scheduledFor.toLocal());
              byDay[day] = (byDay[day] ?? 0) + 1;
            } else if (status == MedicineDoseStatus.missed) {
              missed.add(dose);
            }
          }
          final points = [
            for (var i = 0; i <= 6; i++)
              BarChartPoint(
                label: DateFormat.E().format(start.addDays(i).toDateTimeUtc()),
                value: (byDay[start.addDays(i)] ?? 0).toDouble(),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Doses taken, last 7 days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              PeriodBarChart(points: points, color: ModuleAccents.medicine),
              const SizedBox(height: 24),
              Text(
                'Missed doses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (missed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('None — great adherence!'),
                )
              else
                for (final dose in missed)
                  ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                      DateFormat.MMMEd().add_jm().format(
                        dose.scheduledFor.toLocal(),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
