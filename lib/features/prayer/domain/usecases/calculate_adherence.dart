import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Per-prayer adherence breakdown (FR-P-10).
typedef PrayerAdherenceStats = ({int prayed, int missed, int total});

/// Classifies [records] by persisted status, grouped per [PrayerName]
/// (FR-P-10's "per-prayer on-time percentage" — there's no "prayed-late"
/// status in this module, so `prayed` already means on-time).
/// `upcoming`/`due` records (not yet resolved) are excluded from every
/// count. Trusts `storedStatus` directly rather than re-deriving via
/// `effectivePrayerStatus`: adherence windows are always past/completed
/// ranges, and `sweepMissedPrayers` (run on every app-resume via
/// `PrayerModule.pendingNotifications()`) keeps `missed` current well
/// before any stats screen reads it. Every [PrayerName] gets an entry,
/// even `(prayed: 0, missed: 0, total: 0)` if [records] has none for it.
Map<PrayerName, PrayerAdherenceStats> calculateAdherence({
  required List<PrayerRecord> records,
}) {
  final prayedCounts = <PrayerName, int>{};
  final missedCounts = <PrayerName, int>{};
  for (final record in records) {
    switch (record.storedStatus) {
      case PrayerStatus.prayed:
        prayedCounts[record.prayerName] =
            (prayedCounts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.missed:
        missedCounts[record.prayerName] =
            (missedCounts[record.prayerName] ?? 0) + 1;
      case PrayerStatus.upcoming:
      case PrayerStatus.due:
        break;
    }
  }
  return {
    for (final name in PrayerName.values)
      name: (
        prayed: prayedCounts[name] ?? 0,
        missed: missedCounts[name] ?? 0,
        total: (prayedCounts[name] ?? 0) + (missedCounts[name] ?? 0),
      ),
  };
}
