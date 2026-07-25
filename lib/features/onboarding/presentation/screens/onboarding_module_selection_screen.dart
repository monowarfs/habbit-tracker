import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_settings_repository.dart';
import 'package:habit_tracker/core/database/database_provider.dart';

/// Module selection screen for the onboarding flow.
class OnboardingModuleSelectionScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding module selection screen.
  const OnboardingModuleSelectionScreen({super.key});

  @override
  ConsumerState<OnboardingModuleSelectionScreen> createState() =>
      _OnboardingModuleSelectionScreenState();
}

class _OnboardingModuleSelectionScreenState
    extends ConsumerState<OnboardingModuleSelectionScreen> {
  bool _waterEnabled = true;
  bool _medicineEnabled = false;
  bool _prayerEnabled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingModuleTitle),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(l10n.onboardingModuleSkip),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.onboardingModuleRecommended,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _ModuleTile(
              icon: Icons.water_drop_outlined,
              title: l10n.navWater,
              subtitle: l10n.onboardingModuleWaterDesc,
              enabled: _waterEnabled,
              onChanged: (v) => setState(() => _waterEnabled = v),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.onboardingModuleAlsoAvailable,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            _ModuleTile(
              icon: Icons.medication_outlined,
              title: l10n.navMedicine,
              subtitle: l10n.onboardingModuleMedicineDesc,
              enabled: _medicineEnabled,
              onChanged: (v) => setState(() => _medicineEnabled = v),
            ),
            const SizedBox(height: 8),
            _ModuleTile(
              icon: Icons.mosque_outlined,
              title: l10n.navPrayer,
              subtitle: l10n.onboardingModulePrayerDesc,
              enabled: _prayerEnabled,
              onChanged: (v) => setState(() => _prayerEnabled = v),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _continue,
              child: Text(l10n.onboardingGetStarted),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final db = ref.read(databaseProvider);
    final repo = ModuleSettingsRepository(db);
    final modules = [
      ('water', _waterEnabled),
      ('medicine', _medicineEnabled),
      ('prayer', _prayerEnabled),
    ];
    for (final (id, enabled) in modules) {
      await repo.setEnabled(id, enabled: enabled);
    }
    if (mounted) context.push('/onboarding/complete');
  }

  void _skip() {
    context.push('/onboarding/complete');
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: enabled,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
