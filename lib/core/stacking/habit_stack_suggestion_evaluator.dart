import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';

/// Evaluates both tracked stacking pairs (`medicine -> water`,
/// `prayer -> water`) against the trailing 14 days of real log data and
/// persists any qualifying pattern as a `pending` suggestion. Piggybacks
/// on the same app-resume trigger `planAndApplyNotifications` already
/// uses (`main.dart`) — no new timer, no new call site
/// (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`, "Where it runs").
Future<void> evaluateStackSuggestions({required AppDatabase db}) async {
  final now = clock.now();
  final repository = HabitStackSuggestionRepository(db);
  final today = localDayKey(now);
  final windowStart = today.addDays(-13);

  final waterEntries = await WaterRepositoryImpl(
    db,
  ).watchEntriesInRange(windowStart, today).first;
  final targetByDay = <LocalDate, List<DateTime>>{};
  for (final entry in waterEntries) {
    (targetByDay[localDayKey(entry.loggedAt)] ??= []).add(entry.loggedAt);
  }

  await _evaluatePair(
    repository: repository,
    id: 'medicine_water',
    sourceModuleId: 'medicine',
    targetModuleId: 'water',
    now: now,
    sourceByDay: await _medicineDoneByDay(db, windowStart, today),
    sourceLabel: null,
    targetByDay: targetByDay,
  );

  final prayerSource = await _prayerPrayedByDay(db, windowStart, today);
  await _evaluatePair(
    repository: repository,
    id: 'prayer_water',
    sourceModuleId: 'prayer',
    targetModuleId: 'water',
    now: now,
    sourceByDay: prayerSource.byDay,
    sourceLabel: prayerSource.modeLabel,
    targetByDay: targetByDay,
  );
}

Future<void> _evaluatePair({
  required HabitStackSuggestionRepository repository,
  required String id,
  required String sourceModuleId,
  required String targetModuleId,
  required DateTime now,
  required Map<LocalDate, DateTime> sourceByDay,
  required String? sourceLabel,
  required Map<LocalDate, List<DateTime>> targetByDay,
}) async {
  final existing = await repository.byId(id);
  if (existing != null) {
    if (existing.status == 'accepted') return;
    // Cheap early-exit: a user resuming the app five times a day
    // shouldn't re-run the correlation query five times.
    final lastEvaluated = DateTime.fromMillisecondsSinceEpoch(
      existing.lastEvaluatedAt,
    );
    if (now.difference(lastEvaluated) < const Duration(hours: 24)) return;
  }
  final result = findStackCorrelation(
    sourceByDay: sourceByDay,
    targetByDay: targetByDay,
  );
  if (result == null) return;
  await repository.upsertEvaluation(
    id: id,
    sourceModuleId: sourceModuleId,
    targetModuleId: targetModuleId,
    result: result,
    now: now,
    sourceLabel: sourceLabel,
  );
}

Future<Map<LocalDate, DateTime>> _medicineDoneByDay(
  AppDatabase db,
  LocalDate start,
  LocalDate end,
) async {
  final doses = await MedicineRepositoryImpl(db).dosesInRange(start, end);
  final result = <LocalDate, DateTime>{};
  for (final dose in doses) {
    if (dose.storedStatus != MedicineDoseStatus.done) continue;
    final changedAt = dose.statusChangedAt;
    if (changedAt == null) continue;
    final day = localDayKey(changedAt);
    final existing = result[day];
    if (existing == null || changedAt.isBefore(existing)) {
      result[day] = changedAt;
    }
  }
  return result;
}

/// Prayer's "first prayed action of the day," plus the most common
/// prayer name behind it (for the `{prayer}` placeholder in
/// `habitStackSuggestionPrayerToWater`) — a plain 'record.prayerDate' is
/// already the bucket key (no `localDayKey` needed, unlike Medicine's
/// `scheduledFor`).
Future<({Map<LocalDate, DateTime> byDay, String? modeLabel})>
_prayerPrayedByDay(AppDatabase db, LocalDate start, LocalDate end) async {
  final records = await PrayerRepositoryImpl(db).recordsInRange(start, end);
  final byDay = <LocalDate, DateTime>{};
  final labelByDay = <LocalDate, String>{};
  for (final record in records) {
    if (record.storedStatus != PrayerStatus.prayed) continue;
    final changedAt = record.statusChangedAt;
    if (changedAt == null) continue;
    final day = record.prayerDate;
    final existing = byDay[day];
    if (existing == null || changedAt.isBefore(existing)) {
      byDay[day] = changedAt;
      labelByDay[day] = _titleCase(record.prayerName.name);
    }
  }
  return (byDay: byDay, modeLabel: _modeLabel(labelByDay));
}

String? _modeLabel(Map<LocalDate, String> labels) {
  if (labels.isEmpty) return null;
  final counts = <String, int>{};
  for (final label in labels.values) {
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return sorted.first.key;
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
