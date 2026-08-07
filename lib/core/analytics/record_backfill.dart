import 'package:clock/clock.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Module ids this feature persists a `longest_streak` record for
/// (the design doc's schema table only enumerates these three).
const personalRecordModuleIds = {'water', 'medicine', 'prayer'};

/// One-time seed of `personal_records` from full history (Task 6,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`): for each of
/// [modules] that doesn't have a `longest_streak` record yet, scans its
/// entire [range] and persists the true all-time longest streak.
///
/// A no-op for any module that already has a record — [repo]'s
/// `getRecord` returning non-null is the "already backfilled" marker,
/// so this is cheap (and safe) to call on every app resume rather than
/// needing a dedicated one-shot flag.
Future<void> backfillPersonalRecords({
  required List<HabitModule> modules,
  required PersonalRecordRepository repo,
  required DateRange range,
}) async {
  for (final module in modules) {
    final existing = await repo.getRecord(
      moduleId: module.id,
      recordType: 'longest_streak',
    );
    if (existing != null) continue;
    final dayStatus = await module.dayStatus(range);
    final longest = longestStreak(dayStatus);
    if (longest > 0) {
      await repo.setRecord(
        moduleId: module.id,
        recordType: 'longest_streak',
        value: longest,
      );
    }
  }
}

/// Resolves [backfillPersonalRecords]'s parameters from [db] (install
/// date, today, the registered water/medicine/prayer modules) — the
/// call site wired into app resume, mirroring
/// `core/achievements/tenure_check.dart`'s `evaluateTenureBadges`.
Future<void> runPersonalRecordBackfill(AppDatabase db) async {
  final settingsRow =
      await (db.select(db.appSettingsTable)
            ..where((t) => t.id.equals('singleton'))
            ..limit(1))
          .getSingleOrNull();
  final installDateMs = settingsRow?.installDate;
  if (installDateMs == null) return;

  final installDate = LocalDate.fromDateTime(
    DateTime.fromMillisecondsSinceEpoch(installDateMs, isUtc: true),
  );
  final today = LocalDate.fromDateTime(clock.now());
  final modules = buildHabitModules(
    db,
  ).where((m) => personalRecordModuleIds.contains(m.id)).toList();

  await backfillPersonalRecords(
    modules: modules,
    repo: PersonalRecordRepository(db),
    range: DateRange(start: installDate, end: today),
  );
}
