# Data Retention Audit

**Date:** 2026-07-25
**Status:** Current

## Purpose

This document audits every database table's retention behavior to ensure compliance with the data-longevity guarantee: user data is never silently pruned, capped, or deleted by app updates.

## Table Retention Behavior

| Table | Retention | Under Guarantee | Notes |
|-------|-----------|-----------------|-------|
| `app_settings` | Permanent | Yes | Singleton row, never pruned |
| `water_goals` | Permanent | Yes | Append-only history |
| `water_logs` | Permanent | Yes | All entries kept |
| `water_settings` | Permanent | Yes | Singleton row |
| `medicines` | Permanent | Yes | All medicines kept |
| `medicine_schedules` | Permanent | Yes | Soft-delete via `deleted_at` |
| `medicine_doses` | Rolling 30-day window | Partially | Dose history is permanent; upcoming-dose projection is regenerated |
| `medicine_stock_events` | Permanent | Yes | All stock events kept |
| `prayer_settings` | Permanent | Yes | Singleton row |
| `prayer_records` | Permanent | Yes | All records kept |
| `prayer_qadha_counters` | Permanent | Yes | All counters kept |
| `achievements` | Permanent | Yes | All achievements kept |
| `notification_ledger` | Bounded (90-day FIFO) | No | Operational metadata, not user content |
| `habit_stack_suggestions` | Permanent | Yes | Soft-delete via `deleted_at` |
| `pause_ranges` | Permanent | Yes | All pause ranges kept |
| `recaps` | Permanent (capped at 5) | Yes | App code enforces max 5 stored recaps |
| `cosmetic_unlocks` | Permanent | Yes | Append-only |
| `recalibration_markers` | Permanent | Yes | One row per module |

## Key Findings

1. **`medicine_doses`** has a rolling window for upcoming-dose materialization (30-day look-ahead), but historical dose records (done/skipped/missed) are never deleted.
2. **`notification_ledger`** is operational metadata — it stores scheduled notification details for diffing, not user content. bounded at 90 days via FIFO cleanup.
3. **`recaps`** is capped at 5 by app code (`RecapRepository.allRecaps()` uses `..limit(5)`), which is a deliberate UX choice, not silent pruning.

## Schema Migration Checklist

When adding new tables or columns:

- [ ] Verify new tables/changes against the data-longevity guarantee
- [ ] Flag any rolling-window or capped tables for explicit exclusion
- [ ] Update this document if new table changes retention behavior
- [ ] Add the table to the retention guarantee copy on the Data settings screen
