import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/achievements/tenure_evaluator.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// Checks and awards tenure milestones on app resume.
Future<void> evaluateTenureBadges(AppDatabase db) async {
  final settingsRow = await (db.select(db.appSettingsTable)
        ..where((t) => t.id.equals('singleton'))
        ..limit(1))
      .getSingleOrNull();

  final installDateMs = settingsRow?.installDate;
  if (installDateMs == null) return;

  final installDate = DateTime.fromMillisecondsSinceEpoch(
    installDateMs,
    isUtc: true,
  );

  final repository = AchievementRepository(db);
  await evaluateTenureMilestones(
    installDate: installDate,
    repository: repository,
  );
}
