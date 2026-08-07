import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/router/app_router.dart';

/// Dashboard entry point into the household leaderboard — hidden until a
/// second profile exists, since there's no one to compare against
/// otherwise (`docs/superpowers/specs/05-community/
/// 04-household-shared-device-leaderboard-IMPLEMENTATION-PLAN.md` Task 6).
class HouseholdLeaderboardCard extends ConsumerWidget {
  /// Creates the card.
  const HouseholdLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider).value;
    if (profiles == null || profiles.length < 2) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.leaderboard_outlined),
        title: Text(l10n.leaderboardTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.leaderboard),
      ),
    );
  }
}
