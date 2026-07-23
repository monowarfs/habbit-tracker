import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';

/// The forgot-PIN confirmation screen (FR-C-04) — a full local data
/// reset, not a soft recovery (`strategies/security.md`): there is no
/// account to verify identity against, so the only honest option is
/// wiping everything and starting fresh. A typed-confirmation step
/// prevents accidental taps from destroying data.
class LockResetScreen extends ConsumerStatefulWidget {
  /// Creates the reset confirmation screen.
  const LockResetScreen({super.key});

  @override
  ConsumerState<LockResetScreen> createState() => _LockResetScreenState();
}

class _LockResetScreenState extends ConsumerState<LockResetScreen> {
  final _confirmController = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final l10n = AppLocalizations.of(context)!;
    final matches = value == l10n.lockResetConfirmationWord;
    if (matches != _confirmed) setState(() => _confirmed = matches);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockResetTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.lockResetWarning),
            const SizedBox(height: 24),
            Text(l10n.lockResetConfirmationInstruction),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: l10n.lockResetConfirmationHint,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              onPressed: _confirmed
                  ? () async {
                      final modules = ref.read(habitModulesProvider);
                      final db = ref.read(databaseProvider);
                      await ref
                          .read(pinLockControllerProvider)
                          .resetAllData(modules, db);
                      if (context.mounted) context.go(AppRoutes.dashboard);
                    }
                  : null,
              child: Text(l10n.lockResetConfirm),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.lockResetCancel),
            ),
          ],
        ),
      ),
    );
  }
}
