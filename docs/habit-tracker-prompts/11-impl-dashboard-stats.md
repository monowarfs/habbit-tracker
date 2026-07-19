# 11 — IMPLEMENTATION: DASHBOARD, REPORTS, ACHIEVEMENTS

**Inputs:** `00-project-context.md`, FR-C-* requirements,
`docs/technical/architecture.md` (module contract)

## Scope

This run consumes ONLY the module contract — the dashboard must not import
module internals. If it needs data the contract doesn't expose, extend the
contract (and note it in `decisions.md`), then have each module implement
the extension.

1. **Dashboard tab**: today's summary card per registered module (each module
   supplies its own summary widget via the contract), overall day-completion
   indicator, upcoming items strip (next dose, next prayer, water pace),
   quick actions
2. **Reports**: weekly / monthly / yearly cross-module views built from each
   module's stats contribution; period navigation; empty states for periods
   before install
3. **Achievements & badges**: achievement engine in core, definitions
   contributed by modules (first log, 7/30/100-day streaks, perfect week…).
   Evaluated on relevant writes; stored in the achievements table;
   badge gallery screen + a subtle unlock moment (no intrusive popups)
4. **Longest-streak records** per module, surfaced in reports
5. **Search**: cross-module search (medicine names, notes) via contract-
   provided search handlers; simple, fast, local
6. **Calendar (global)**: month view merging all modules' day statuses
7. Localize everything (en + bn)

## Definition of Done
- Proof of decoupling: temporarily comment out one module's registration →
  app compiles and dashboard renders without it (make this an actual widget
  test with a registry override, not just a manual check)
- Unit tests: achievement evaluation, cross-module aggregation
- Widget tests: dashboard with 0/1/3 modules registered
- Manual: seeded multi-week data across all modules renders sane reports;
  Bangla pass
- Analyze clean, tests pass, commit:
  `feat(dashboard): cross-module dashboard, reports, achievements`
