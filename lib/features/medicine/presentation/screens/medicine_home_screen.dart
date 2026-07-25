import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/pauses/presentation/active_pauses_card.dart';
import 'package:habit_tracker/core/recalibration/presentation/widgets/recalibration_card.dart';
import 'package:habit_tracker/core/recalibration/recalibration_providers.dart';
import 'package:habit_tracker/core/widgets/haptic_feedback_helper.dart';
import 'package:habit_tracker/core/widgets/note_editor_sheet.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';
import 'package:habit_tracker/core/widgets/undo_snackbar.dart';
import 'package:habit_tracker/features/achievements/presentation/achievement_localization.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/dose_tile.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// The Medicine module's home screen: today's dose timeline, grouped
/// chronologically, tap to take/skip (FR-M-02's most complex UI surface).
class MedicineHomeScreen extends ConsumerWidget {
  /// Creates the medicine home screen. [highlightDoseId], if set, came
  /// from a notification tap deep link (FR-C-09). [chimePlayer] is a
  /// test-only seam — production code always falls back to
  /// [ChimePlayer.instance] (resolved in [build], not here, so this
  /// constructor stays `const` for the existing
  /// `const MedicineHomeScreen()` route call site in
  /// `medicine_module.dart`).
  const MedicineHomeScreen({
    super.key,
    this.highlightDoseId,
    this.chimePlayer,
  });

  /// Dose id to visually highlight, if opened via deep link.
  final String? highlightDoseId;

  /// Test seam for [ChimePlayer.instance].
  final ChimePlayer? chimePlayer;

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
            tooltip: l10n.medicineHomeAllMedicinesButton,
            onPressed: () => context.push('/medicine/list'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.medicineHomeStatsButton,
            onPressed: () => context.push('/medicine/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.medicineHomeAddButton,
            onPressed: () => context.push('/medicine/new'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? Center(child: Text(l10n.medicineHomeEmpty))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _RecalibrationCheck(moduleId: 'medicine'),
                const ActivePausesCard(moduleId: 'medicine'),
                for (final view in views)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DoseTile(
                      view: view,
                      highlighted: view.dose.id == highlightDoseId,
                      onDone: () => _markDoneAndCelebrate(
                        context,
                        ref,
                        view.dose.id,
                        chimePlayer ?? ChimePlayer.instance,
                      ),
                      onSkip: () => _skipWithUndo(context, ref, view.dose.id),
                      onNoteTap: () async {
                        final result = await showNoteEditorSheet(
                          context,
                          initialNotes: view.dose.notes,
                        );
                        if (context.mounted) {
                          await controller.updateDoseNotes(
                            view.dose.id,
                            result,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Marks a dose done, offers an undo snackbar (the atlas's named "mark
/// done by mistake" scenario, giving `undoDose` its first real caller),
/// then — only if the dose wasn't undone — shows a subtle (non-modal)
/// snackbar if doing so newly unlocked an achievement (FR-C-13's "no
/// intrusive popups" requirement). Two snackbars can't usefully show at
/// once on the same `ScaffoldMessenger`, so the achievement snackbar
/// waits for the undo snackbar's own `.closed` to resolve first; if the
/// user tapped Undo, it's skipped entirely (the achievement stays
/// unlocked regardless — the engine has no revoke path, a known,
/// accepted limitation for this size of change).
Future<void> _markDoneAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  String doseId,
  ChimePlayer chimePlayer,
) async {
  // Captured synchronously (not re-read inside the deferred `onUndo`
  // below, which can fire after this widget's element is disposed).
  final controller = ref.read(medicineControllerProvider.notifier);
  final repository = ref.read(achievementRepositoryProvider);
  final before = await repository.watchByModule('medicine').first;
  final unlockedBefore = before
      .where((r) => r.unlockedAt != null)
      .map((r) => r.key)
      .toSet();

  await controller.markDoseDone(doseId);
  await HapticFeedbackHelper.lightImpact();

  // The chime is wired here — the UI-only call site — and nowhere in
  // `MedicineController`/`MedicineRepository`/`MedicineModule`, because
  // `MedicineModule.onNotificationAction` (the Done/Snooze/Skip
  // background-isolate path) calls the repository directly and has no
  // audio session to play into (`docs/superpowers/specs/02-delightful/
  // 10-optional-sound-design-pass-design.md`).
  if (ref.read(appSettingsProvider).value?.soundEnabled ?? false) {
    unawaited(chimePlayer.playDoseDoneChime());
  }

  var wasUndone = false;
  if (context.mounted) {
    final l10n = AppLocalizations.of(context)!;
    await showUndoSnackbar(
      context,
      message: l10n.medicineDoseUndoSnackbar,
      undoLabel: l10n.commonUndo,
      onCommit: () {},
      onUndo: () {
        wasUndone = true;
        unawaited(controller.undoDose(doseId));
      },
    );
  }
  if (wasUndone || !context.mounted) return;

  final after = await repository.watchByModule('medicine').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'medicine');

  String? streakKey;
  for (final row in newlyUnlocked) {
    if (isStreakMilestoneKey(row.key)) {
      streakKey = row.key;
      break;
    }
  }
  if (streakKey != null && context.mounted) {
    final streakDefinition = module.achievementDefinitions.firstWhere(
      (d) => d.key == streakKey,
    );
    final celebrationL10n = AppLocalizations.of(context)!;
    await showStreakCelebration(
      context,
      title: localizedAchievementTitle(
        celebrationL10n,
        streakDefinition.titleKey,
      ),
      accentColor: module.metadata.accentColor,
      icon: module.metadata.icon,
    );
  }
  if (!context.mounted) return;

  final definition = module.achievementDefinitions.firstWhere(
    (d) => d.key == newlyUnlocked.first.key,
  );
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, definition.titleKey),
        ),
      ),
    ),
  );
}

/// Marks a dose skipped, then offers the same `undoDose` reversal as
/// [_markDoneAndCelebrate] — skip never evaluates achievements, so no
/// sequencing with a second snackbar is needed here.
Future<void> _skipWithUndo(
  BuildContext context,
  WidgetRef ref,
  String doseId,
) async {
  // Captured synchronously (not re-read inside the deferred `onUndo`
  // below, which can fire after this widget's element is disposed).
  final controller = ref.read(medicineControllerProvider.notifier);
  await controller.markDoseSkipped(doseId);
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  await showUndoSnackbar(
    context,
    message: l10n.medicineDoseUndoSnackbar,
    undoLabel: l10n.commonUndo,
    onCommit: () {},
    onUndo: () => controller.undoDose(doseId),
  );
}

/// Stateful wrapper that checks if recalibration is due and shows the card.
class _RecalibrationCheck extends ConsumerStatefulWidget {
  const _RecalibrationCheck({required this.moduleId});

  final String moduleId;

  @override
  ConsumerState<_RecalibrationCheck> createState() =>
      _RecalibrationCheckState();
}

class _RecalibrationCheckState extends ConsumerState<_RecalibrationCheck> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final service = ref.read(recalibrationServiceProvider);
    final settings = ref.read(appSettingsProvider).value;
    final enabled = settings?.recalibrationPromptsEnabled ?? true;
    if (await service.isDue(widget.moduleId, enabled: enabled)) {
      if (mounted) setState(() => _show = true);
      await service.onPromptShown(widget.moduleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return RecalibrationCard(
      onConfirmed: () async {
        await ref
            .read(recalibrationServiceProvider)
            .onConfirmed(widget.moduleId);
        setState(() => _show = false);
      },
      onDeferred: () async {
        await ref
            .read(recalibrationServiceProvider)
            .onDeferred(widget.moduleId);
        setState(() => _show = false);
      },
    );
  }
}
