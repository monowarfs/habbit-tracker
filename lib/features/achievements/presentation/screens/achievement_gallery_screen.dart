import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_cache.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_generator.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_share.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/achievements/presentation/achievement_localization.dart';
import 'package:habit_tracker/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// The badge gallery — every module's achievements, locked (progress bar)
/// or unlocked (unlock date) (FR-C-13). Big streak milestones
/// (`CertificateGenerator.qualifiesForCertificate`) additionally offer a
/// "Share Certificate"/"Save to Photos" pair once unlocked
/// (`docs/superpowers/specs/06-gamification/
/// 07-milestone-certificate-image-design.md` Task 6 — this screen is
/// the plan's named "badge gallery" alternative trigger point; no
/// unlock-celebration dialog exists in this codebase yet to hang the
/// button off instead).
class AchievementGalleryScreen extends ConsumerStatefulWidget {
  /// Creates the achievement gallery screen.
  const AchievementGalleryScreen({super.key});

  @override
  ConsumerState<AchievementGalleryScreen> createState() =>
      _AchievementGalleryScreenState();
}

class _AchievementGalleryScreenState
    extends ConsumerState<AchievementGalleryScreen> {
  /// The achievement key currently being rendered/shared/saved, so its
  /// card can show a spinner instead of the share/save icons (and so
  /// only one certificate action runs at a time).
  String? _busyKey;

  Future<void> _shareCertificate(
    AchievementView view,
    HabitModule module,
  ) async {
    await _runCertificateAction(view, (path, l10n) {
      return const CertificateShare().shareCertificate(
        path,
        text: l10n.achievementUnlockedSnackbar(
          localizedAchievementTitle(l10n, view.definition.titleKey),
        ),
      );
    }, module);
  }

  Future<void> _saveCertificate(
    AchievementView view,
    HabitModule module,
  ) async {
    await _runCertificateAction(view, (path, l10n) async {
      await const CertificateShare().saveToLibrary(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.certificateShareSuccess)));
    }, module);
  }

  Future<void> _runCertificateAction(
    AchievementView view,
    Future<void> Function(String path, AppLocalizations l10n) action,
    HabitModule module,
  ) async {
    setState(() => _busyKey = view.definition.key);
    try {
      final l10n = AppLocalizations.of(context)!;
      final documentsDir = await path_provider
          .getApplicationDocumentsDirectory();
      final generator = CertificateGenerator(
        cache: CertificateCache(documentsDir),
      );
      if (!mounted) return;
      final path = await generator.generate(
        context: context,
        achievementKey: view.definition.key,
        moduleName: module.metadata.displayName,
        streakDays: view.definition.target,
        accentColor: module.metadata.accentColor,
        l10n: l10n,
        date: view.unlockedAt,
      );
      await action(path, l10n);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.certificateShareFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  /// The share/save icon row for a qualifying unlocked achievement, or a
  /// small spinner while [_busyKey] matches it.
  Widget _buildCertificateActions(AchievementView view) {
    if (_busyKey == view.definition.key) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // Guaranteed to find a match: achievementViewsProvider only ever
    // surfaces definitions contributed by visibleHabitModulesProvider's
    // own modules.
    final module = ref
        .watch(visibleHabitModulesProvider)
        .firstWhere((m) => m.id == view.definition.moduleId);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.certificateShareButton,
          icon: const Icon(Icons.share, size: 20),
          onPressed: () => _shareCertificate(view, module),
        ),
        IconButton(
          tooltip: l10n.certificateSaveButton,
          icon: const Icon(Icons.download, size: 20),
          onPressed: () => _saveCertificate(view, module),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewsAsync = ref.watch(achievementViewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: viewsAsync.when(
        data: (views) {
          // Sort: unlocked achievements first, then by progress percentage
          // (closest to unlocking first).
          final sorted = List<AchievementView>.from(views)
            ..sort((a, b) {
              final aUnlocked = a.unlockedAt != null;
              final bUnlocked = b.unlockedAt != null;
              if (aUnlocked && !bUnlocked) return -1;
              if (!aUnlocked && bUnlocked) return 1;
              if (aUnlocked && bUnlocked) return 0;
              // Both locked — sort by progress percentage (descending).
              final aPercent = a.definition.target > 0
                  ? a.progressCurrent / a.definition.target
                  : 0.0;
              final bPercent = b.definition.target > 0
                  ? b.progressCurrent / b.definition.target
                  : 0.0;
              return bPercent.compareTo(aPercent);
            });
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final view = sorted[index];
              final unlocked = view.unlockedAt != null;
              final qualifiesForCertificate =
                  unlocked &&
                  CertificateGenerator.qualifiesForCertificate(
                    view.definition,
                  );
              return Card(
                color: unlocked
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        unlocked
                            ? Icons.emoji_events
                            : Icons.emoji_events_outlined,
                        size: 40,
                        color: unlocked
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizedAchievementTitle(
                          l10n,
                          view.definition.titleKey,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizedAchievementDescription(
                          l10n,
                          view.definition.descriptionKey,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (!unlocked)
                        LinearProgressIndicator(
                          value: view.progressCurrent / view.definition.target,
                        ),
                      if (qualifiesForCertificate)
                        _buildCertificateActions(view),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, stack) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
