# Implementation Plan: Prayer On-Time vs. Late-but-Completed Split

**Spec:** `10-prayer-on-time-vs-late-design.md`
**Complexity:** S · **Estimated effort:** 2 days
**Depends on:** `effectivePrayerStatus`, `prayer_records` table

---

## IMPORTANT: Schema Change Required

The current `PrayerStatus` enum only has `upcoming`, `due`, `missed`,
`prayed`. This spec requires adding `prayedLate`.

---

## Task 1: Add `prayedLate` to PrayerStatus enum

**File:** `lib/features/prayer/domain/entities/prayer_record.dart`

```dart
enum PrayerStatus {
  upcoming, due, prayed, prayedLate, missed
}
```

---

## Task 2: Modify `effectivePrayerStatus`

**File:** `lib/features/prayer/domain/usecases/effective_prayer_status.dart`

Add timing check:
```dart
if (status == 'prayed' && statusChangedAt != null && scheduledFor != null) {
  final delay = statusChangedAt.difference(scheduledFor);
  if (delay > Duration(minutes: prayerSettings.graceWindowMinutes)) {
    return PrayerStatus.prayedLate;
  }
}
return PrayerStatus.prayed;
```

---

## Task 3: Update `calculateAdherence`

**File:** `lib/features/medicine/domain/usecases/calculate_adherence.dart`

Handle `prayedLate` in the adherence calculation — count as "completed"
for overall adherence, but track separately for the three-way split.

---

## Task 4: Update notification action handler

**File:** `lib/core/notifications/notification_action_handler.dart`

Prayers actioned via notification's Done button are always marked
`prayed` (on time), not `prayedLate`.

---

## Task 5: Add three-way split to stats screen

**File:** `lib/features/prayer/presentation/screens/prayer_stats_screen.dart`

Add section showing:
- On Time: X (Y%)
- Late but Completed: X (Y%)
- Missed: X (Y%)

---

## Task 6: Backfill existing records

Existing `prayed` records in the DB are treated as "on time" by default.
No migration needed — the new status only applies to new records.

---

## Task 7: Add localization strings

```json
"prayerOnTimeLabel": "On Time: {count} ({percent}%)",
"prayerLateLabel": "Late but Completed: {count} ({percent}%)",
"prayerMissedLabel": "Missed: {count} ({percent}%)",
"prayerOnTimeRate": "On-time rate: {percent}%"
```

---

## Performance considerations

- **Status check:** O(1) comparison per prayer record. Fast.
- **No migration:** existing records unchanged.

## Testing

- Unit test: `effectivePrayerStatus` with new `prayedLate` status.
- Unit test: grace window boundary conditions.
- Unit test: notification action always marks as `prayed`.
- Widget test: three-way split display.
- Migration test: existing records handled correctly.

## Localization

ARB keys listed in Task 7.
