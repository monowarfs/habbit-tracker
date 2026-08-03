import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/illustrations/module_icon_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/presentation/mood_value_display.dart';
import 'package:habit_tracker/features/mood/presentation/providers/mood_controller.dart';
import 'package:habit_tracker/features/mood/presentation/providers/mood_providers.dart';

/// The Mood module's home screen: 5 quick-log buttons (one tap logs a
/// check-in — no separate add-entry screen, matching the "quick log"
/// framing in the spec) plus a recent-check-ins list.
///
/// The stats button is hidden (not just the body) for non-premium users
/// as a UX nicety; `MoodStatsScreen` gates itself too, so hiding this
/// isn't the actual security boundary — same shape as Sleep/BP after
/// their own review rounds.
class MoodHomeScreen extends ConsumerWidget {
  /// Creates the mood home screen.
  const MoodHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moodHomeTitle),
        actions: [
          if (isPremium)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/settings/mood/stats'),
            ),
        ],
      ),
      body: PremiumGateWidget(child: _Content(l10n: l10n)),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    final logsAsync = ref.watch(
      moodLogsInRangeProvider(today.addDays(-13), today),
    );
    final logs = logsAsync.value;
    final sorted = logs?.reversed.toList();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: _QuickLogRow(),
        ),
        Expanded(
          child: sorted == null
              ? const Center(child: CircularProgressIndicator())
              : sorted.isEmpty
              ? ModuleEmptyState(
                  painter: (color) => ModuleIconPainter(
                    color,
                    Icons.sentiment_satisfied_outlined,
                  ),
                  message: l10n.moodHomeEmpty,
                  accentColor: const Color(0xFF8E24AA),
                )
              : ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) =>
                      _MoodLogTile(log: sorted[index]),
                ),
        ),
      ],
    );
  }
}

class _QuickLogRow extends ConsumerStatefulWidget {
  const _QuickLogRow();

  @override
  ConsumerState<_QuickLogRow> createState() => _QuickLogRowState();
}

class _QuickLogRowState extends ConsumerState<_QuickLogRow> {
  bool _saving = false;

  Future<void> _logMood(int value) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await ref
        .read(moodControllerProvider.notifier)
        .logMood(value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure()) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.moodLogSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final value in const [1, 2, 3, 4, 5])
          Semantics(
            button: true,
            label: moodValueLabel(l10n, value),
            child: IconButton(
              iconSize: 36,
              icon: Icon(moodValueIcons[value]),
              onPressed: _saving ? null : () => _logMood(value),
            ),
          ),
      ],
    );
  }
}

class _MoodLogTile extends ConsumerStatefulWidget {
  const _MoodLogTile({required this.log});

  final MoodLog log;

  @override
  ConsumerState<_MoodLogTile> createState() => _MoodLogTileState();
}

class _MoodLogTileState extends ConsumerState<_MoodLogTile> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final succeeded = await ref
        .read(moodControllerProvider.notifier)
        .deleteLog(widget.log.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (!succeeded) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.moodDeleteError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(moodValueIcons[widget.log.moodValue]),
      title: Text(moodValueLabel(l10n, widget.log.moodValue)),
      subtitle: widget.log.notes == null ? null : Text(widget.log.notes!),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.commonDelete,
        onPressed: _deleting ? null : _delete,
      ),
    );
  }
}
