import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/illustrations/module_icon_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_controller.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_providers.dart';

/// The Exercise module's home screen: a recent-workouts list.
///
/// The FAB/stats button are hidden (not just the body) for non-premium
/// users as a UX nicety; ExerciseAddEntryScreen/ExerciseStatsScreen each
/// gate themselves too, so hiding these isn't the actual security
/// boundary — it just avoids a pointless tap into a paywall (same shape
/// as SleepHomeScreen/BpHomeScreen after their own review rounds).
class ExerciseHomeScreen extends ConsumerWidget {
  /// Creates the exercise home screen.
  const ExerciseHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exerciseHomeTitle),
        actions: [
          if (isPremium)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/settings/exercise/stats'),
            ),
        ],
      ),
      body: PremiumGateWidget(child: _RecentLogsList(l10n: l10n)),
      floatingActionButton: isPremium
          ? FloatingActionButton(
              onPressed: () => context.push('/settings/exercise/add'),
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
      exerciseLogsInRangeProvider(today.addDays(-13), today),
    );
    final logs = logsAsync.value;
    if (logs == null) return const Center(child: CircularProgressIndicator());
    if (logs.isEmpty) {
      return ModuleEmptyState(
        painter: (color) =>
            ModuleIconPainter(color, Icons.fitness_center_outlined),
        message: l10n.exerciseHomeEmpty,
        accentColor: const Color(0xFF43A047),
      );
    }
    final sorted = logs.reversed.toList();
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) => _ExerciseLogTile(log: sorted[index]),
    );
  }
}

class _ExerciseLogTile extends ConsumerWidget {
  const _ExerciseLogTile({required this.log});

  final ExerciseLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.fitness_center_outlined),
      title: Text(log.exerciseType),
      subtitle: Text(
        log.calories == null
            ? l10n.exerciseHomeDurationOnly(log.durationMinutes)
            : l10n.exerciseHomeDurationAndCalories(
                log.durationMinutes,
                log.calories!,
              ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.commonDelete,
        onPressed: () =>
            ref.read(exerciseControllerProvider.notifier).deleteLog(log.id),
      ),
    );
  }
}
