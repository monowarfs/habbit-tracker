import 'dart:async';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';

/// Subscribes to [AchievementEngine.events] and awards
/// [XpValues.streakMilestone] XP for each streak-length achievement's
/// first unlock. Per-action/day-complete XP is awarded directly from each
/// module's controller instead (`xp_award_helper.dart`) — this listener
/// only exists because `AchievementEngine` doesn't otherwise surface
/// which unlock just happened to non-UI code.
class XpAwardListener {
  /// Creates a listener over [achievementEngine], awarding through
  /// [xpRepository].
  XpAwardListener({
    required this.achievementEngine,
    required this.xpRepository,
  });

  /// The engine whose unlock events this listens to.
  final AchievementEngine achievementEngine;

  /// Where the XP award lands.
  final XpRepository xpRepository;

  /// Starts listening — callers own the returned subscription's lifetime
  /// (cancel it on dispose).
  StreamSubscription<AchievementEvent> listen() {
    return achievementEngine.events.listen((event) {
      if (!event.justUnlocked || !isStreakMilestoneKey(event.key)) return;
      unawaited(
        xpRepository.awardXp(
          moduleId: event.moduleId,
          eventType: 'streak_milestone',
          amount: XpValues.streakMilestone,
          now: clock.now(),
          sourceId: event.key,
          profileId: event.profileId,
        ),
      );
    });
  }
}
