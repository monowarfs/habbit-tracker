# Mosque-Finder / Jamaah Times Layer

**Category:** Community · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Prayer's current calculation gives a user their own personal (calculated) prayer times, but says nothing about the congregation (jamaah) times at a nearby mosque, which frequently differ from the calculated Adhan time by a fixed offset. Muslim Pro and similar apps treat this as core functionality. It's a genuine gap for the Prayer persona specifically — someone wanting to attend congregational prayer needs the mosque's actual jamaah schedule, not just the astronomically-calculated time this app already produces.

## Infrastructure implication
Zero-infra achievable for a first version, following the same pattern as Prayer's existing bundled 65-city dataset: ship a static, curated dataset of known mosques and their jamaah offsets/schedules, matched against the user's existing GPS/manual location resolver. A live, always-current, comprehensive mosque directory (arbitrary mosque anywhere, live-updated timings) would require a backend/crowdsourcing service — that's a materially bigger feature and should be scoped as a v2 if ever pursued, not assumed as part of this v1.

## Goals
- Show nearby mosques (from a bundled/curated dataset) alongside their jamaah prayer times, offset from or independent of the calculated Adhan times Prayer already shows.
- Reuse Prayer's existing GPS/manual location resolver rather than building a second location system.
- Keep the feature fully offline — no live network lookup required for the bundled dataset to work.

## Non-goals / out of scope
- Not building a live, crowdsourced, continuously-updated mosque directory in v1 — that's a backend-requiring v2 scope, explicitly deferred.
- Not letting arbitrary users submit/edit mosque data in-app (that's a moderation and data-quality problem out of scope here).
- Not replacing or changing the existing personal Adhan-time calculation (`calculatePrayerTimes` / the `adhan_dart` wrapper) — this is an additive display layer, not a recalculation.
- No mosque reviews, ratings, or social features attached to mosque listings.

## Proposed approach (high-level)
Extend Prayer's existing bundled-city-data pattern with a second curated dataset: known mosques (name, location, jamaah offsets or fixed times per prayer) for a starting set of cities/regions, likely overlapping the existing 65-city coverage. Reuse the Prayer module's existing GPS/manual location resolver to find the user's location, then match against the nearest bundled mosque entries and display their jamaah times alongside (not instead of) the calculated personal times already shown. This slots in as an additional screen or section within the Prayer module, not a new top-level module.

## Dependencies & prerequisites
- A curated mosque dataset (name/location/jamaah times) — a content/data-sourcing effort, not just an engineering one; likely the single biggest cost driver here.
- Prayer's existing GPS/manual location resolver (already built).
- Prayer's existing bundled-asset pattern (the 65-city dataset) as a structural template for shipping and loading the new dataset.

## Open questions for the implementation round
- How is the mosque dataset sourced and kept from going stale — one-time curation at ship time, or a plan for periodic app-update refreshes?
- What's the fallback UX when no bundled mosque exists near the user's location (likely the common case outside major cities)?
- Is a fixed offset-from-Adhan model suf­ficient for jamaah times, or do some mosques need fully independent schedules (e.g. differing Friday Jumu'ah slot times, which Prayer's settings already track separately)?
- Does this warrant its own screen within Prayer, or a section on an existing Prayer screen?

## Effort & sequencing notes
Medium (M) for a bundled-dataset v1 that follows Prayer's existing 65-city precedent closely. The live/crowdsourced version implied by "mosque finder" in the fullest sense would be substantially larger (effectively a backend service) and should be treated as a distinct, later decision rather than folded into this scope.

## Localization

New user-facing strings requiring en/bn ARB keys:

- `mosqueFinderTitle` — "Nearby Mosques" / "কাছের মসজিদ"
- `mosqueFinderSubtitle` — "Jamaah prayer times" / "জামাতের নামাজের সময়"
- `mosqueFinderNoResults` — "No mosques found near your location" / "আপনার অবস্থানের কাছে কোনো মসজিদ পাওয়া যায়নি"
- `mosqueFinderDistance` — "{distance} km away" / "{distance} কিমি দূরে"
- `mosqueFinderJamaahOffset` — "Jamaah: {offset} min after Adhan" / "জামাত: আজানের {offset} মিনিট পরে"
- `mosqueFinderNoLocation` — "Enable location to find nearby mosques" / "কাছের মসজিদ খুঁজে পেতে অবস্থান সক্রিয় করুন"
- `mosqueFinderPrayerTime` — "{prayer}: {time}" / "{prayer}: {time}"

Add these to `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`.

## Edge cases & error handling

1. **No mosques in bundled dataset near user's location** — This is the common case outside major cities. Show a friendly empty state: "No mosques found near your location" with no error, just an informational message. Reference `AppException.notFound`.
2. **Location permission denied** — Prayer's existing location resolver handles this. Surface the existing permission-explainer screen from `core/notifications/` or a similar permission request flow. Use `AppException.permission`.
3. **Bundled dataset is outdated** — Mosque schedules change. For v1, accept staleness and note in the UI that times may not be current. Plan periodic dataset refreshes via app updates.
4. **Multiple mosques at same distance** — Show a scrollable list sorted by distance, with ties broken alphabetically. No special error handling needed.
5. **Jamaah offset model insufficient** — Some mosques have fully independent schedules (not just an offset). For v1, if a mosque's data doesn't fit the offset model, store its times directly as fixed values rather than computing from Adhan.

## Cross-references

- `docs/superpowers/specs/05-community/07-global-city-prayer-participation-stat-design.md` — prayer participation stat shares the location resolution infrastructure.
- `lib/features/prayer/domain/usecases/` — `calculatePrayerTimes` and `effectivePrayerStatus` for the Adhan calculation this feature extends.
- `lib/features/prayer/data/repositories/` — Prayer's bundled 65-city asset pattern for dataset loading.
- `lib/features/prayer/presentation/` — Prayer module presentation layer where this screen/section is added.
- `lib/core/error/app_exception.dart` — error taxonomy for permission/storage/validation failures.

## Test strategy

- **Unit tests**: Mosque dataset parsing (bundled JSON/asset → domain entities). Distance calculation between user location and mosque locations. Jamaah offset application to Adhan times.
- **Widget tests**: Mosque list renders correctly with mock data. Empty state shows when no mosques are nearby. Distance and offset labels render correctly.
- **Golden tests**: Mosque list item card layout for consistent visual presentation.
- **Test files to create**:
  - `test/features/prayer/mosque_finder_test.dart`
  - `test/features/prayer/mosque_dataset_parser_test.dart`
  - `test/goldens/mosque_list_item_golden.png`
