import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';

/// Screen listing archived water goals with revive functionality.
class ArchivedGoalsScreen extends ConsumerStatefulWidget {
  /// Creates the archived goals screen.
  const ArchivedGoalsScreen({super.key});

  @override
  ConsumerState<ArchivedGoalsScreen> createState() =>
      _ArchivedGoalsScreenState();
}

class _ArchivedGoalsScreenState extends ConsumerState<ArchivedGoalsScreen> {
  late Future<List<WaterGoal>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadArchivedGoals();
  }

  Future<List<WaterGoal>> _loadArchivedGoals() async {
    final profile = await ref.read(activeProfileProvider.future);
    return ref
        .read(waterRepositoryProvider)
        .archivedGoals(profileId: profile.id);
  }

  void _refresh() {
    setState(() {
      _future = _loadArchivedGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.archivedGoalsTitle)),
      body: FutureBuilder<List<WaterGoal>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data ?? [];
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.archivedEmptyState,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: Text('${goal.goalMl} ml'),
                  subtitle: Text(
                    goal.effectiveFrom.toString().split(' ').first,
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => _reviveGoal(goal),
                    child: Text(l10n.reviveAction),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _reviveGoal(WaterGoal goal) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reviveConfirmTitle('${goal.goalMl} ml')),
        content: Text(l10n.reviveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reviveConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final profile = await ref.read(activeProfileProvider.future);
    final result = await ref
        .read(waterRepositoryProvider)
        .reviveGoal(goal.id, profileId: profile.id);
    switch (result) {
      case Success():
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.reviveSnackSuccess('${goal.goalMl} ml')),
            ),
          );
          _refresh();
        }
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
    }
  }
}
