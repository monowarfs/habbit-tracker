# 07 — IMPLEMENTATION: WATER TRACKER MODULE

**Inputs:** `00-project-context.md`, `docs/product/functional-requirements.md`
(FR-W-*), `docs/technical/*`, `docs/engineering/phases-and-dod.md`
**The first real module — it validates the plugin contract. State plan first.**

## Scope

Build the complete Water module inside `lib/features/water/` and register it
in the module registry. **If you find yourself needing to edit any file
outside `features/water/` other than the registry (and, if the DB requires
it, the central schema registration), stop and report — the contract has a
hole and we fix the contract, not work around it.**

### Domain
- Entities: water log (amount, timestamp, source: quick/custom), daily goal
  (with effective-from date so goal changes don't rewrite history)
- Use cases: log intake, undo/delete a log, get day progress, compute streak
  (define: day counts if total ≥ goal for that local day), aggregate
  week/month/year series

### Data
- Water tables per `database-design.md`, repository with reactive streams

### Presentation
- Water tab: today's progress (animated ring/bar), goal display, quick-add
  buttons (user-configurable amounts, sensible defaults 200/300/500 ml),
  custom amount sheet, today's log list with delete
- History: calendar view (day-level goal-met coloring) + list drill-down
- Statistics: weekly/monthly/yearly charts with fl_chart (add the dependency
  now; build the chart widgets as reusable `core/widgets/charts/` components —
  every later module needs them), streak card
- Settings section (within module): daily goal, quick-add amounts
- Full l10n (en + bn) for every string; Bangla-locale digit policy applied

### Reminders — data only
Store water reminder times/preferences; actual scheduling lands in run 08.
Make the module expose its reminder contributions via the contract.

## Definition of Done
- Manual test script: log via quick add + custom, delete, change goal
  mid-day, verify streak over a seeded 10-day dataset, view all three chart
  ranges, switch to Bangla and repeat
- Unit tests: streak math (incl. goal-change and timezone edge cases from
  the clock helpers), aggregation series correctness on seeded data
- Repository tests on temp DB; widget test for the water tab's main states
  (empty / partial / goal met)
- Analyze clean, all tests pass, both platforms boot
- Commit: `feat(water): complete water tracking module`
