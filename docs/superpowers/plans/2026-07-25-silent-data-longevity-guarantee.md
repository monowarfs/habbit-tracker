# Silent Data-Longevity Guarantee — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/11-silent-data-longevity-guarantee-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

This is primarily a **documentation and copy task** — an audit of actual retention behavior plus a reassurance card on the Data settings screen. No new domain logic.

```
┌──────────────────────────────────────────────────────────┐
│  1. Retention audit (docs/engineering/)                  │
│  → list every table, its retention behavior              │
│  → confirm no silent pruning/capping                     │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  2. DataLongevityGuaranteeCard widget (new)              │
│  placed on Data settings screen (same as Spec 08)        │
│  plain-language commitment about data retention          │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  3. Notification ledger cleanup (optional)               │
│  FIFO eviction of entries older than 90 days             │
│  if not already bounded                                  │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| Data settings reassurance card (Spec 08) | Ships first — this spec adds adjacent copy |
| About screen | Exists at `lib/features/settings/presentation/screens/about_screen.dart` |

---

## Implementation tasks

### T1: Retention audit document

**Files:**
- `docs/engineering/retention-audit.md` — **new file**

**Content — one row per table:**

| Table | Retention behavior | Under guarantee? |
|-------|-------------------|-----------------|
| `app_settings` | Permanent (singleton row, never pruned) | Yes |
| `water_goals` | Permanent (append-only history) | Yes |
| `water_logs` | Permanent (all entries kept) | Yes |
| `water_settings` | Permanent (singleton row) | Yes |
| `medicines` | Permanent (all medicines kept) | Yes |
| `medicine_schedules` | Permanent (soft-delete via `deleted_at`) | Yes |
| `medicine_doses` | **Rolling 30-day window** (materialized for upcoming doses) | Partially — dose history is permanent, upcoming-dose projection is regenerated |
| `medicine_stock_events` | Permanent | Yes |
| `prayer_settings` | Permanent (singleton row) | Yes |
| `prayer_records` | Permanent (all records kept) | Yes |
| `prayer_qadha_counters` | Permanent | Yes |
| `achievements` | Permanent | Yes |
| `notification_ledger` | **Operational metadata** — should have bounded cleanup | No (excluded from guarantee) |
| `habit_stack_suggestions` | Permanent (soft-delete via `deleted_at`) | Yes |
| `pause_ranges` | Permanent | Yes |
| `recaps` | Permanent (capped at 5 by app code) | Yes |
| `cosmetic_unlocks` | Permanent (append-only) | Yes |

**Key finding:** `medicine_doses` has a rolling window for upcoming-dose materialization, but historical dose records are permanent. The `notification_ledger` is operational metadata, not user content.

**Also add to `docs/engineering/schema-migration-checklist.md`:**
```
- Verify new tables/changes against the data-longevity guarantee.
- Flag any rolling-window or capped tables for explicit exclusion.
```

---

### T2: Data longevity guarantee card widget

**Files:**
- `lib/features/settings/presentation/widgets/data_longevity_guarantee_card.dart` — **new file**
- `lib/features/settings/presentation/screens/data_settings_screen.dart` — add widget below the privacy reassurance card (Spec 08)

**Widget design:**
```dart
class DataLongevityGuaranteeCard extends StatelessWidget {
  const DataLongevityGuaranteeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(l10n.dataLongevityGuaranteeTitle,
                style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            Text(l10n.dataLongevityGuaranteeBody),
            const SizedBox(height: 8),
            Text(l10n.dataLongevityGuaranteeMedicineCaveat,
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

**Tests:** Widget test — card renders, text content correct.

---

### T3: Notification ledger bounded cleanup

**Files:**
- `lib/core/notifications/notification_ledger_repository.dart` — add `cleanupOlderThan(Duration age)` method

```dart
/// Evicts ledger entries older than [age]. Called periodically to bound
/// notification_ledger growth. User-facing data is unaffected.
Future<int> cleanupOlderThan(Duration age) async {
  final cutoff = clock.now().subtract(age).toUtc().millisecondsSinceEpoch;
  return (_db.delete(_db.notificationLedgerTable)
    ..where((t) => t.createdAt.isSmallerThanValue(cutoff))).go();
}
```

**Wire:** Call `cleanupOlderThan(Duration(days: 90))` in `planAndApplyNotifications` (runs on every app resume — cheap delete of stale rows).

**Tests:** Verify old entries are deleted, recent entries preserved.

---

### T4: Schema migration checklist update

**Files:**
- `docs/engineering/schema-migration-checklist.md` — add longevity guarantee check

**Add to checklist:**
```markdown
## Data longevity guarantee
- [ ] New tables/changes verified against data-longevity guarantee
- [ ] Any rolling-window or capped tables explicitly documented
- [ ] Guarantee copy updated if new table changes retention behavior
```

---

### T5: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~5 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `dataLongevityGuaranteeTitle` — "Your data is never pruned"
- `dataLongevityGuaranteeBody` — "Your habit history, logs, and settings are permanently stored on your device. App updates never delete or cap your data."
- `dataLongegrityGuaranteeMedicineCaveat` — "Your dose history is always saved. Short-term forecasts of upcoming doses are regenerated as needed — these are not your history."
- `dataLongevityGuaranteeNotificationNote` — "Notification scheduling records are automatically cleaned up after 90 days."
- `dataLongevityGuaranteeExportNote` — "Your data can be exported at any time from the export option above."

---

## Task sequencing

```
T1 (audit) ──→ T2 (card widget) ──→ T5 (i18n)
T3 (ledger cleanup) ──→ T1 (audit documents behavior)
T4 (checklist) ──→ T1
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `docs: add retention-audit.md documenting every table's retention behavior` |
| 2 | T2 | `feat(settings): add data longevity guarantee card to Data settings` |
| 3 | T3 | `feat(notifications): add bounded cleanup for notification_ledger (90-day FIFO)` |
| 4 | T4 | `docs: add data longevity check to schema migration checklist` |
| 5 | T5 | `feat(i18n): add en/bn strings for data longevity guarantee` |
