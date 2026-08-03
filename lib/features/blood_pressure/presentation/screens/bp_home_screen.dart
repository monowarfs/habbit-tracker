import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/illustrations/module_icon_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_controller.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_providers.dart';

/// The Blood Pressure module's home screen: a recent-readings list.
///
/// The FAB/stats button are hidden (not just the body) for non-premium
/// users as a UX nicety; BpAddEntryScreen/BpStatsScreen each gate
/// themselves too, so hiding these isn't the actual security boundary —
/// it just avoids a pointless tap into a paywall (same shape as
/// SleepHomeScreen after its own review round).
class BpHomeScreen extends ConsumerWidget {
  /// Creates the blood pressure home screen.
  const BpHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bpHomeTitle),
        actions: [
          if (isPremium)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/settings/blood-pressure/stats'),
            ),
        ],
      ),
      body: PremiumGateWidget(child: _RecentLogsList(l10n: l10n)),
      floatingActionButton: isPremium
          ? FloatingActionButton(
              onPressed: () => context.push('/settings/blood-pressure/add'),
              child: const Icon(Icons.add),
            )
          : null,
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
      bpLogsInRangeProvider(today.addDays(-13), today),
    );
    final logs = logsAsync.value;
    if (logs == null) return const Center(child: CircularProgressIndicator());
    if (logs.isEmpty) {
      return ModuleEmptyState(
        painter: (color) =>
            ModuleIconPainter(color, Icons.monitor_heart_outlined),
        message: l10n.bpHomeEmpty,
        accentColor: const Color(0xFFE53935),
      );
    }
    final sorted = logs.reversed.toList();
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) => _BpLogTile(log: sorted[index]),
    );
  }
}

class _BpLogTile extends ConsumerWidget {
  const _BpLogTile({required this.log});

  final BpLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        Icons.monitor_heart_outlined,
        color: _classificationColor(log.classification, theme),
      ),
      title: Text('${log.systolic}/${log.diastolic} mmHg'),
      subtitle: Text(_classificationLabel(l10n, log.classification)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.commonDelete,
        onPressed: () =>
            ref.read(bpControllerProvider.notifier).deleteLog(log.id),
      ),
    );
  }
}

Color _classificationColor(BpClassification classification, ThemeData theme) {
  return switch (classification) {
    BpClassification.normal => theme.semanticColors.success,
    BpClassification.elevated => theme.colorScheme.tertiary,
    BpClassification.hypertension1 ||
    BpClassification.hypertension2 ||
    BpClassification.hypertensionCrisis => theme.colorScheme.error,
  };
}

String _classificationLabel(AppLocalizations l10n, BpClassification c) {
  return switch (c) {
    BpClassification.normal => l10n.bpClassificationNormal,
    BpClassification.elevated => l10n.bpClassificationElevated,
    BpClassification.hypertension1 => l10n.bpClassificationHypertension1,
    BpClassification.hypertension2 => l10n.bpClassificationHypertension2,
    BpClassification.hypertensionCrisis => l10n.bpClassificationCrisis,
  };
}
