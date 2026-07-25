import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_settings_repository.dart';

/// Suggests enabling a module the user hasn't enabled yet.
class ModuleSuggestionCard extends ConsumerStatefulWidget {
  /// Creates the module suggestion card.
  const ModuleSuggestionCard({super.key});

  @override
  ConsumerState<ModuleSuggestionCard> createState() =>
      _ModuleSuggestionCardState();
}

class _ModuleSuggestionCardState extends ConsumerState<ModuleSuggestionCard> {
  String? _suggestedModule;

  @override
  void initState() {
    super.initState();
    _checkSuggestion();
  }

  Future<void> _checkSuggestion() async {
    final db = ref.read(databaseProvider);
    final repo = ModuleSettingsRepository(db);
    final enabled = await repo.enabledModuleIds();

    // Suggest the first non-enabled, non-dismissed module.
    for (final moduleId in ['medicine', 'prayer']) {
      if (!enabled.contains(moduleId) &&
          !await repo.isSuggestionDismissed(moduleId)) {
        if (mounted) setState(() => _suggestedModule = moduleId);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestedModule == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final moduleLabel = _suggestedModule == 'medicine'
        ? l10n.navMedicine
        : l10n.navPrayer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.moduleSuggestionTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.moduleSuggestionBody(moduleLabel)),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => _enableModule(),
                  child: Text(l10n.moduleSuggestionEnable(moduleLabel)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _dismiss(),
                  child: Text(l10n.moduleSuggestionDismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableModule() async {
    final db = ref.read(databaseProvider);
    final repo = ModuleSettingsRepository(db);
    await repo.setEnabled(_suggestedModule!, enabled: true);
    setState(() => _suggestedModule = null);
  }

  Future<void> _dismiss() async {
    final db = ref.read(databaseProvider);
    final repo = ModuleSettingsRepository(db);
    await repo.dismissSuggestion(_suggestedModule!);
    setState(() => _suggestedModule = null);
  }
}
