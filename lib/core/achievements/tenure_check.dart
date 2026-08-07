import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/achievements/tenure_evaluator.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// Checks and awards tenure milestones on app resume.
Future<void> evaluateTenureBadges(AppDatabase db) async {
  final settingsRow =
      await (db.select(db.appSettingsTable)
            ..where((t) => t.id.equals('singleton'))
            ..limit(1))
          .getSingleOrNull();

  final installDateMs = settingsRow?.installDate;
  if (installDateMs == null) return;

  final installDate = DateTime.fromMillisecondsSinceEpoch(
    installDateMs,
    isUtc: true,
  );

  // App-resume trigger, no Ref — pinned to the 'system' profile for the
  // same reason as `notification_planner.dart`'s `planAndApplyNotifications`
  // (`WaterModule`'s `_fixedProfileId` doc comment). Family/multi-profile's
  // Task 8/9 give this its own profile-aware entry point later.
  const profileId = 'system';
  final repository = AchievementRepository(db);
  await evaluateTenureMilestones(
    installDate: installDate,
    repository: repository,
    profileId: profileId,
  );
}
