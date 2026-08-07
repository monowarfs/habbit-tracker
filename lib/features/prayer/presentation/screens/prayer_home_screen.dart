import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/gamification/xp_toast.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/pauses/presentation/active_pauses_card.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/simple_mode_constants.dart';
import 'package:habit_tracker/core/widgets/haptic_feedback_helper.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';
import 'package:habit_tracker/core/widgets/note_editor_sheet.dart';
import 'package:habit_tracker/core/widgets/streak_celebration_overlay.dart';
import 'package:habit_tracker/features/achievements/presentation/achievement_localization.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/widgets/prayer_tile.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Today's prayer checklist — countdown to next prayer (via each tile's
/// live status), Gregorian date, tap-to-mark-prayed toggle (FR-P-07).
class PrayerHomeScreen extends ConsumerWidget {
  /// Creates the checklist screen.
  const PrayerHomeScreen({super.key, this.highlightRecordId});

  /// Record id to highlight when opened via a notification deep link.
  final String? highlightRecordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(todaysPrayerViewsProvider);
    final simpleMode = ref.watch(simpleModeEnabledProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prayerHomeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: l10n.prayerHomeHistoryButton,
            onPressed: () => context.push('/prayer/history'),
          ),
          IconButton(
            icon: const Icon(Icons.pending_actions),
            tooltip: l10n.prayerHomeQadhaButton,
            onPressed: () => context.push('/prayer/qadha'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.prayerHomeStatsButton,
            onPressed: () => context.push('/prayer/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.prayerHomeSettingsButton,
            onPressed: () => context.push('/prayer/settings'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? ModuleEmptyState(
              painter: CrescentMatPainter.new,
              message: l10n.prayerHomeEmpty,
              accentColor: Theme.of(context).moduleAccents.prayer,
            )
          : MediaQuery(
              // Composes on top of the ambient text scale rather than
              // replacing it, so OS-level accessibility scaling and
              // Simple Mode's own bump both apply (spec's Edge Case 2).
              data: MediaQuery.of(context).copyWith(
                textScaler: simpleMode
                    ? TextScaler.linear(
                        MediaQuery.textScalerOf(context).scale(1) *
                            simpleModeTextScaleMultiplier,
                      )
                    : MediaQuery.textScalerOf(context),
              ),
              child: Column(
                children: [
                  const ActivePausesCard(moduleId: 'prayer'),
                  Expanded(
                    child: ListView.builder(
                      padding: simpleMode ? simpleModePadding : EdgeInsets.zero,
                      itemCount: views.length,
                      itemBuilder: (context, index) {
                        final view = views[index];
                        void onToggle() => _togglePrayedAndCelebrate(
                          context,
                          ref,
                          view.record.id,
                          currentlyPrayed:
                              view.effectiveStatus == PrayerStatus.prayed,
                        );
                        if (simpleMode) {
                          return _SimplePrayerCard(
                            view: view,
                            onToggle: onToggle,
                          );
                        }
                        return PrayerTile(
                          view: view,
                          highlighted: view.record.id == highlightRecordId,
                          onToggle: onToggle,
                          onNoteTap: () async {
                            final result = await showNoteEditorSheet(
                              context,
                              initialNotes: view.record.notes,
                            );
                            if (context.mounted) {
                              await ref
                                  .read(prayerControllerProvider.notifier)
                                  .updatePrayerNotes(view.record.id, result);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Simple Mode's full-width prayer card — the prayer name and status at
/// larger text, and (while still toggleable) an oversized "Mark Prayed"
/// button instead of [PrayerTile]'s small icon toggle. Note editing is
/// dropped here, same deliberate simplification as Medicine's
/// `_SimpleDoseCard`.
class _SimplePrayerCard extends StatelessWidget {
  const _SimplePrayerCard({required this.view, required this.onToggle});

  final PrayerRecordView view;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = view.showAsJumuah
        ? l10n.prayerNameJumuah
        : _labelFor(l10n, view.record.prayerName);
    final canToggle = view.effectiveStatus != PrayerStatus.missed;
    final prayed = view.effectiveStatus == PrayerStatus.prayed;
    return SemanticLabels.wrap(
      label: label,
      child: Card(
        child: Padding(
          padding: simpleModePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              if (canToggle) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: simpleModeButtonHeight,
                  child: prayed
                      ? OutlinedButton.icon(
                          onPressed: onToggle,
                          icon: const Icon(
                            Icons.check_circle,
                            size: simpleModeIconSize,
                          ),
                          label: Text(l10n.prayerSimpleToggleButton),
                        )
                      : ElevatedButton.icon(
                          onPressed: onToggle,
                          icon: const Icon(
                            Icons.radio_button_unchecked,
                            size: simpleModeIconSize,
                          ),
                          label: Text(l10n.prayerSimpleToggleButton),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, PrayerName name) => switch (name) {
    PrayerName.fajr => l10n.prayerNameFajr,
    PrayerName.dhuhr => l10n.prayerNameDhuhr,
    PrayerName.asr => l10n.prayerNameAsr,
    PrayerName.maghrib => l10n.prayerNameMaghrib,
    PrayerName.isha => l10n.prayerNameIsha,
  };
}

/// Toggles a prayer's prayed status, then shows a subtle (non-modal)
/// snackbar if doing so newly unlocked an achievement (FR-C-13's "no
/// intrusive popups" requirement). Un-marking never unlocks anything, so
/// this only ever fires on the mark-prayed direction in practice.
Future<void> _togglePrayedAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  String recordId, {
  required bool currentlyPrayed,
}) async {
  final profileId = (await ref.read(activeProfileProvider.future)).id;
  final repository = ref.read(achievementRepositoryProvider);
  final before = await repository
      .watchByModule('prayer', profileId: profileId)
      .first;
  final unlockedBefore = before
      .where((r) => r.unlockedAt != null)
      .map((r) => r.key)
      .toSet();

  await ref
      .read(prayerControllerProvider.notifier)
      .togglePrayed(recordId, currentlyPrayed: currentlyPrayed);
  await HapticFeedbackHelper.lightImpact();
  // Matches PrayerController.togglePrayed's own guard: only the
  // mark-prayed direction is a new action worth XP.
  if (!currentlyPrayed && context.mounted) {
    showXpGainToast(context, amount: XpValues.prayerAction);
  }

  final after = await repository
      .watchByModule('prayer', profileId: profileId)
      .first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isEmpty || !context.mounted) return;
  final module = ref
      .read(habitModulesProvider)
      .firstWhere((m) => m.id == 'prayer');

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
