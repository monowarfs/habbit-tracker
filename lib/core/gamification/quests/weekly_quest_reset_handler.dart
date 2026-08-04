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
Future<void> checkAndResetWeeklyQuests(WidgetRef ref) {
  return ref.read(questEngineProvider).generateWeek(now: clock.now());
}
