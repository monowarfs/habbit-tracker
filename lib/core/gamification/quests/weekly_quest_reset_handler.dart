import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/quests/quest_providers.dart';

/// Generates the current week's quests if they don't exist yet — called
/// from the app lifecycle on cold start and foreground resume (mirrors
/// `core/nudges/reengagement_check.dart`'s `checkReEngagementNudge` shape).
/// `QuestEngine.generateWeek` is already idempotent (a no-op once the
/// current week's rows exist), so this is just a lifecycle-hook call site,
/// not its own reset logic — a missed week's quests simply expire
/// unclaimed, no cleanup needed.
///
/// [currentWeekQuestsProvider] computes its week key once, when first
/// read, and (being a plain top-level provider with no `.autoDispose`)
/// stays alive for the process's lifetime — without this invalidation, a
/// session left open across a Monday reset would keep the dashboard
/// showing the now-frozen previous week's quests until the app was
/// force-killed (PR #77 review finding).
Future<void> checkAndResetWeeklyQuests(WidgetRef ref) async {
  await ref.read(questEngineProvider).generateWeek(now: clock.now());
  ref.invalidate(currentWeekQuestsProvider);
}
