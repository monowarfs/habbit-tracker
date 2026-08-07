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

/// Seeds `personal_records` from full history (Task 6,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`): for each of
/// [modules], scans its entire [range] and raises its `longest_streak`
/// record to the true all-time value if the scan beats what's currently
/// persisted.
///
/// Deliberately uses [PersonalRecordRepository.checkAndUpdate] (compare
/// -and-raise), not a "skip if a record already exists" guard: a stats
/// screen's own live check (`personal_record_providers.dart`) can create
/// a record from just the *current* streak before this ever runs (it's
/// `unawaited` from an app-resume hook, so ordering against UI builds
/// isn't guaranteed) — if this early-exited on "a row exists", that
/// live-created, possibly-lower value would permanently shadow the true
/// historical max. Comparing instead of skipping makes the result
/// correct regardless of run order, at the cost of one dayStatus scan
/// per module on every resume (still far cheaper than a stats-screen
/// load, which is what the design doc's "no re-scanning" goal is about).
Future<void> backfillPersonalRecords({
  required List<HabitModule> modules,
  required PersonalRecordRepository repo,
  required DateRange range,
}) async {
  for (final module in modules) {
    final dayStatus = await module.dayStatus(range);
    final longest = longestStreak(dayStatus);
    if (longest > 0) {
      await repo.checkAndUpdate(
        moduleId: module.id,
        recordType: 'longest_streak',
        newValue: longest,
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
