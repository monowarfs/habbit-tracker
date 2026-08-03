import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_controller.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_providers.dart';

/// The Sleep module's home screen: a recent-nights list, gated behind
/// premium (`PremiumGateWidget`) since this route is always registered
/// regardless of entitlement — see `SleepModule`'s doc comment.
class SleepHomeScreen extends ConsumerWidget {
  /// Creates the sleep home screen.
  const SleepHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sleepHomeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/settings/sleep/stats'),
          ),
        ],
      ),
      body: PremiumGateWidget(child: _RecentLogsList(l10n: l10n)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/sleep/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecentLogsList extends ConsumerWidget {
  const _RecentLogsList({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    final logsAsync = ref.watch(
      sleepLogsInRangeProvider(today.addDays(-13), today),
    );
    final logs = logsAsync.value;
    if (logs == null) return const Center(child: CircularProgressIndicator());
    if (logs.isEmpty) {
      return Center(child: Text(l10n.sleepHomeEmpty));
    }
    final sorted = logs.reversed.toList();
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) => _SleepLogTile(log: sorted[index]),
    );
  }
}

class _SleepLogTile extends ConsumerWidget {
  const _SleepLogTile({required this.log});

  final SleepLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hours = log.durationMinutes ~/ 60;
    final minutes = log.durationMinutes % 60;
    return ListTile(
      leading: const Icon(Icons.bedtime_outlined),
      title: Text('${hours}h ${minutes}m'),
      subtitle: Text(
        '${log.bedTime.toLocal().hour.toString().padLeft(2, '0')}:'
        '${log.bedTime.toLocal().minute.toString().padLeft(2, '0')} → '
        '${log.wakeTime.toLocal().hour.toString().padLeft(2, '0')}:'
        '${log.wakeTime.toLocal().minute.toString().padLeft(2, '0')}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.commonDelete,
        onPressed: () =>
            ref.read(sleepControllerProvider.notifier).deleteLog(log.id),
      ),
    );
  }
}
