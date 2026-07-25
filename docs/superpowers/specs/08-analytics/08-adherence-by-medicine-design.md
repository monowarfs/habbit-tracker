# Adherence-by-Medicine Breakdown

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Medicine's stats screen today likely shows an overall adherence
percentage, but a caregiver or a user managing several medicines needs to
know which specific medicine is the one actually slipping — an overall
blended number can look fine (e.g. 85%) while one particular medicine is
being missed constantly and another is perfect. Medisafe's per-medicine
breakdown is the proven pattern here, and this is exactly the kind of gap
that matters most for the users with the highest stakes (multiple
medicines, caregiver oversight), which is why this item carries high
retention impact despite being small in scope.

## Goals

- Break down adherence percentage per individual medicine, not just as
  one blended figure across all of a user's medicines.
- Make it easy to spot the worst-performing medicine at a glance (sort by
  adherence ascending, or otherwise visually foreground the low outlier).
- Keep this on Medicine's existing stats screen — an addition, not a new
  screen.

## Non-goals / out of scope

- Not changing how adherence itself is calculated per medicine — this
  reuses the existing calculation, just reports it segmented rather than
  blended.
- Not a caregiver-specific multi-user feature (shared accounts, remote
  caregiver view) — this is still a single-device, single-user stat,
  just segmented more usefully within that scope.
- Not extending to per-dose-time breakdown (e.g. morning vs. evening dose
  of the same medicine) in this pass — per-medicine is the requested
  granularity.

## Proposed approach (high-level)

Medicine's existing adherence calculation (`calculateAdherence`) already
presumably operates over dose records that are tied to a specific
medicine/schedule — the breakdown is a matter of running or grouping that
same calculation per medicine rather than only once across all of a
user's medicines combined. The stats screen would then show a small
per-medicine list/table (medicine name plus its adherence percentage)
alongside whatever overall figure it already shows today, most
naturally sorted so the lowest-adherence medicine is immediately visible
rather than buried in the middle of a list.

## Dependencies & prerequisites

- `calculateAdherence`'s existing logic, invoked or grouped per medicine
  rather than only in aggregate — need to confirm it already accepts a
  medicine-scoped input or can easily be adapted to.
- Medicine's existing dose/schedule data model, which already associates
  each dose with a specific medicine.
- Medicine's stats screen as the presentation surface.

## Open questions for the implementation round

- Does the existing `calculateAdherence` use case already operate
  per-medicine internally (and just get summed/blended for display), or
  does it need restructuring to expose a per-medicine breakdown?
- What's the right period for this breakdown — same period selector as
  the overall stats screen (week/month/year), presumably, but worth
  confirming.
- How should a medicine with very few scheduled doses (e.g. a short PRN
  course) be handled so a tiny sample size doesn't produce a misleadingly
  low percentage?

## Effort & sequencing notes

Atlas complexity: S. Likely a grouping/re-presentation of an adherence
calculation that already exists per-medicine under the hood — low
implementation risk if that's confirmed true; slightly higher if the
existing calculation needs restructuring to expose that granularity.
Independent of every other item in this batch.

## Database schema

No new tables. The per-medicine breakdown is computed by grouping
`medicine_doses` by `medicine_id` and calling `calculateAdherence` per
group. The current `calculateAdherence` use case in
`lib/features/medicine/domain/usecases/calculate_adherence.dart` takes
a flat `List<MedicineDose>` — the caller must group by `medicine_id`
before passing.

## Localization

New ARB keys (en/bn):
- `adherenceByMedicineTitle` — "Adherence by Medicine"
- `adherenceByMedicineRate` — "{name}: {percent}%"
- `adherenceByMedicineSorted` — "Sorted by adherence (lowest first)"
- `adherenceByMedicineInsufficientData` — "Not enough doses yet for {name}"

## Edge cases & error handling

- **PRN medicines:** PRN (as-needed) medicines don't have a scheduled
  adherence concept. Show them separately with "As-needed" framing
  rather than a percentage.
- **Short courses:** if a medicine has fewer than 7 scheduled doses,
  show "Not enough data" instead of a potentially misleading percentage.
- **Sorted by ascending adherence:** the worst-performing medicine is
  at the top, making it immediately visible.
- **Single medicine:** if only one medicine exists, the breakdown is
  redundant with the overall stats. Show it anyway for consistency.

## Cross-references

- Calculate adherence: `lib/features/medicine/domain/usecases/calculate_adherence.dart`.
- Medicine stats screen: `lib/features/medicine/presentation/screens/medicine_stats_screen.dart`.
- Medicine data model: `lib/features/medicine/domain/entities/`.
- Related: Spec 08-analytics/03 (day-of-week) — Medicine's partial
  adherence granularity.

## Test strategy

- Unit test: per-medicine grouping and adherence calculation.
- Unit test: PRN medicine handling.
- Unit test: short-course minimum sample enforcement.
- Widget test: per-medicine breakdown list sorted by adherence.
