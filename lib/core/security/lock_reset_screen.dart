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
/// wiping everything and starting fresh.
class LockResetScreen extends ConsumerWidget {
  /// Creates the reset confirmation screen.
  const LockResetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockResetTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.lockResetWarning),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final modules = ref.read(habitModulesProvider);
                final db = ref.read(databaseProvider);
                await ref
                    .read(pinLockControllerProvider)
                    .resetAllData(modules, db);
                if (context.mounted) context.go(AppRoutes.dashboard);
              },
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
