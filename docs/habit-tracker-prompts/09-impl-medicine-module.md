# 09 — IMPLEMENTATION: MEDICINE TRACKER MODULE

**Inputs:** `00-project-context.md`, FR-M-* requirements,
`docs/technical/database-design.md` (dose materialization decision),
run 08's engine
**The most complex domain logic in the app. State plan first.**

## Scope

Complete module in `lib/features/medicine/` + registry entry. Same
contract-purity rule as run 07.

### Domain
- Medicine entity: name, type (tablet/capsule/syrup/injection/drops/other),
  dosage (amount + unit as structured data, not a free string), instruction
  (before/after meal/any time), start/end date, notes
- **Repeat-rule engine** — the heart of this run. Rules: daily, every N days
  (anchored to start date), weekly (weekday set), monthly (day-of-month with
  31st/Feb clamping — define behavior), specific dates. Expansion function:
  rule + date range → dose instances. This must be pure, clock-injected, and
  covered by exhaustive tests including month-end and every-other-day-across-
  year-boundary cases.
- Dose lifecycle: scheduled → taken / skipped / missed (missed = grace window
  from FR doc elapsed, evaluated lazily — no background job needed; justify
  in code docs)
- Stock: decrement on taken, stock-event history, low-stock threshold,
  refill action

### Data
Tables per design doc; if doses are materialized, the generator maintains the
same rolling window pattern as the notification planner and they must stay
consistent (single planner, two outputs — recommend this shape).

### Presentation
- Medicine tab: today's dose timeline grouped by time, tap to take/skip,
  overdue highlighted
- Medicine list: active/ended, add/edit form (multi-step form — keep each
  step simple; this form is where UX quality shows), delete = soft-delete
  with confirm
- Detail screen: schedule preview (next 7 days), stock card with refill,
  per-medicine history + adherence %
- History & stats: adherence charts (reuse core chart widgets), missed list
- Notifications: per-dose reminders through the run 08 engine; Done marks
  taken + decrements stock; Skip marks skipped; low-stock triggers a
  notification
- Full en + bn localization

## Definition of Done
- Unit tests: repeat-rule expansion (the exhaustive suite above), stock
  arithmetic, missed-dose evaluation, adherence calculation
- Repository + widget tests for the dose timeline states
- Manual script: create medicines covering every repeat type, verify 7-day
  previews match expectation, take/skip/miss flows, stock hits low threshold
  → notification, end-date behavior, Bangla pass
- Analyze clean, tests pass, commit:
  `feat(medicine): complete medicine tracking module`
