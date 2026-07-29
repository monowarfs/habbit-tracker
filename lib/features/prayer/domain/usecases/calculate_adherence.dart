import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';

/// Per-prayer adherence breakdown (FR-P-10). `prayed` is on-time
/// completions only; `prayedLate` is completions past the grace window
/// (08-analytics/10-prayer-on-time-vs-late) — `prayed + prayedLate` is
/// the overall "completed" count.
typedef PrayerAdherenceStats = ({
  int prayed,
  int prayedLate,
  int missed,
  int total,
});

/// Classifies [records] by persisted status, grouped per [PrayerName]
/// (FR-P-10's per-prayer on-time percentage, plus the on-time/late split).
/// `upcoming`/`due` records (not yet resolved) are excluded from every
/// count. Trusts `storedStatus` directly rather than re-deriving via
/// `effectivePrayerStatus` for the prayed/missed split: adherence windows
/// are always past/completed ranges, and `sweepMissedPrayers` (run on
/// every app-resume via `PrayerModule.pendingNotifications()`) keeps
/// `missed` current well before any stats screen reads it. `prayed`
/// records are further split into on-time vs late via [isPrayedOnTime].
/// Every [PrayerName] gets an entry, even an all-zero one, if [records]
/// has none for it.
Map<PrayerName, PrayerAdherenceStats> calculateAdherence({
  required List<PrayerRecord> records,
}) {
  final prayedCounts = <PrayerName, int>{};
  final prayedLateCounts = <PrayerName, int>{};
  final missedCounts = <PrayerName, int>{};
  for (final record in records) {
    switch (record.storedStatus) {
      case PrayerStatus.prayed:
        final onTime = isPrayedOnTime(
          scheduledFor: record.scheduledFor,
          statusChangedAt: record.statusChangedAt,
        );
        final counts = onTime ? prayedCounts : prayedLateCounts;
        counts[record.prayerName] = (counts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.missed:
        missedCounts[record.prayerName] =
            (missedCounts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.upcoming:
      case PrayerStatus.due:
      case PrayerStatus.prayedLate:
        break;
    }
  }
  return {
    for (final name in PrayerName.values)
      name: (
        prayed: prayedCounts[name] ?? 0,
        prayedLate: prayedLateCounts[name] ?? 0,
        missed: missedCounts[name] ?? 0,
        total:
            (prayedCounts[name] ?? 0) +
            (prayedLateCounts[name] ?? 0) +
            (missedCounts[name] ?? 0),
      ),
  };
}
