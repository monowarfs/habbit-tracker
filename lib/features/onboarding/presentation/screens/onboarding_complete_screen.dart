import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Completion screen for the onboarding flow.
class OnboardingCompleteScreen extends ConsumerWidget {
  /// Creates the onboarding complete screen.
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.onboardingCompleteTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.onboardingCompleteBody,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  // Mark onboarding as completed.
                  final db = ref.read(databaseProvider);
                  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                  await (db.update(
                    db.onboardingProgressTable,
                  )..where((t) => t.id.equals('singleton'))).write(
                    OnboardingProgressTableCompanion(
                      completed: const Value(true),
                      completedAt: Value(now),
                    ),
                  );
                  if (context.mounted) {
                    context.go('/');
                  }
                },
                child: Text(l10n.onboardingCompleteButton),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
