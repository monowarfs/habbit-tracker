# Loyalty Milestone Cosmetic Rewards

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
By year two, most of the achievements a user has already earned reward specific behaviors — streaks, totals, adherence rates. None of them say "thank you for still being here," and that gap matters more the longer someone stays, because tenure itself stops being reflected back to the user at exactly the point it becomes most true. A free, tenure-based cosmetic unlock — a themed app icon at two years, say — costs nothing to give, is never pay-to-win, and reads purely as a thank-you rather than a mechanic, which is precisely the tone this app has kept throughout (no guilt, no manipulation, no pressure). It's a small gesture, but small free gestures compound into the feeling that the app remembers the relationship.

## Goals
- Grant free, purely cosmetic unlocks (e.g. an alternate app icon or theme accent) at long-tenure milestones (e.g. two years).
- Make clear the reward is a gift, not tied to any streak, performance, or payment.
- Reuse the achievements engine's existing evaluation/award mechanism rather than building a parallel rewards system.

## Non-goals / out of scope
- No pay-to-unlock-faster option — that would undercut the "thank you, not a mechanic" framing the atlas explicitly calls for.
- No functional rewards (extra features, unlocked modules) — cosmetic only, by design.
- No large cosmetic catalog in this pass — start with a single milestone and a single reward type (e.g. one alternate icon), expand later if wanted.

## Proposed approach (high-level)
This shares almost its entire mechanism with the anniversary-badge feature: both are achievements triggered by elapsed tenure rather than a module write path, evaluated against install-date rather than logged behavior. The distinguishing piece is what happens when the achievement is awarded — instead of (or in addition to) a badge, it unlocks a cosmetic option the user can then apply from Settings (e.g. selecting an alternate app icon, if the platform icon-changing mechanism is available, or a theme accent variant within the existing Material 3 theme system's per-module accent structure). The achievements engine's existing repository already tracks awarded achievements; a cosmetic reward just needs a small mapping from "this achievement is awarded" to "this cosmetic option becomes selectable" in Settings, gated on the achievement's presence rather than a separate entitlement system.

## Resolved Dependencies
The following must be built and merged before this spec can begin implementation:

1. **`installDate` on `AppSettings`** — A `install_date` column (nullable `DateTime`, seeded to `clock.now()` on first launch) in the `app_settings` table. The anniversary-badge feature (#6) requires this too; whichever ships first adds the column. The cosmetic-rewards spec should not introduce its own tenure-tracking — it must consume the single `installDate` from `app_settings`.
2. **Achievement engine cosmetic-unlock hook** — The current `core/achievements/` engine evaluates and writes to the `achievements` table but has no mechanism to notify the UI when a new achievement unlocks a cosmetic option. A `Stream<AchievementEvent>` (or equivalent) must be added to the engine so the Settings/Unlocks surface can reactively show newly available cosmetics. Without this, the "unlock becomes selectable" UX cannot work.
3. **Schema migration for `cosmetic_unlocks` table** (or equivalent mapping) — A new table or column linking achievement IDs to cosmetic option keys. `app_database.dart` must include it; a `schemaVersion` bump and a migration function are required. This is the cross-cutting gap: no migration strategy was called out in the original spec.
4. **Anniversary-badge feature (#6)** — Must ship first because it establishes the tenure-evaluation pattern this spec extends. Cosmetic rewards piggyback on the same `installDate`-based trigger; building both simultaneously would cause circular review.
5. **Settings screen** — The "Unlocks" or "Rewards" section lives in Settings. The settings surface must exist with at least one section to append to.

## Dependencies & prerequisites
- The achievements engine (award/evaluation/repository) and the same `installDate` tenure signal the anniversary badge needs — **cross-cutting gap: `installDate` does not exist yet**; it must be added to `app_settings` before this spec can evaluate milestones.
- **Cross-cutting gap: no cosmetic-unlock hook in the achievements engine** — the engine currently only writes to the `achievements` table; a stream/callback mechanism is needed so the Settings UI can reactively present newly available cosmetics when an achievement fires.
- **Cross-cutting gap: no schema migration strategy documented** — a new table (e.g. `cosmetic_unlocks`) linking achievement IDs to cosmetic option keys requires a `schemaVersion` bump and a Drift migration function in `app_database.dart`. This must be part of the implementation plan, not hand-waved.
- The app's existing theming system (for a theme-accent-style reward) or platform alternate-icon support (for an icon-style reward) — whichever cosmetic mechanism is chosen determines real platform-level prerequisites worth checking early (iOS/Android alternate icon support differs).
- Settings screen, as the place a user would go to apply an unlocked cosmetic.

## Edge Cases & 3-4 Year Considerations

**Edge cases:**
- **App reinstalled on a new device** — `installDate` is lost on reinstall (local-first, no cloud sync). The guarantee is that tenure is measured from the current install, not from account creation. This must be stated in the UI copy ("Since you installed the app on this device").
- **Achievement engine not yet run at install anniversary** — If the app is offline or backgrounded on the exact anniversary date, the achievement won't fire until the next app-open that triggers evaluation. Cosmetic unlock should appear on first open after the milestone, not require real-time clock precision.
- **Achievement revoked or deleted** — If the user clears app data or the achievement is removed in a future schema migration, the cosmetic unlock should remain available (it was granted, not conditional on continued tenure). The `cosmetic_unlocks` table should be append-only.
- **Multiple milestones at different tenures** — If a 1-year, 2-year, and 5-year milestone are added later, the evaluation logic must handle multiple concurrent milestones firing. The current spec limits to one milestone, but the schema should support N milestones without a redesign.
- **Theme accent vs. icon reward branching** — If the chosen cosmetic mechanism is platform alternate icon, iOS requires `setAlternateIconName` (which can fail if the icon asset is missing); Android requires adaptive icon XML. If the mechanism is theme accent, it's pure Dart and platform-agnostic. The spec should decide upfront to avoid a mid-implementation pivot.

**3-4 year scalability concerns:**
- **Achievement table growth** — At 3-4 years, a user could have 10+ tenure milestones evaluated. The achievements table should remain small (one row per milestone type), not per-day, so this is low risk — but the evaluator must not re-evaluate already-awarded milestones on every app open.
- **Cosmetic catalog growth** — If the app eventually offers 5+ alternate icons or theme accents, the Settings UI needs a gallery/picker, not just a toggle. The schema should store cosmetic option keys (strings) so new options can be added without migration.
- **Platform icon asset bloat** — Each alternate app icon adds platform-specific assets (iOS `CFBundleAlternateIcons`, Android adaptive icon). At 3-4 icons this is fine; at 10+ it warrants lazy-loading or asset-size budgets.

## Acceptance Criteria
1. `install_date` column exists in `app_settings` table, is non-null after first launch, and is included in a schema migration (version bump + migration function in `app_database.dart`).
2. A `cosmetic_unlocks` table (or equivalent) maps achievement IDs to cosmetic option keys; it is append-only and does not delete rows when achievements are revoked.
3. The achievement engine emits a `Stream<AchievementEvent>` (or equivalent callback) that the Settings UI can subscribe to for real-time unlock notifications.
4. When a user's tenure reaches a defined milestone (e.g. 2 years), a cosmetic option becomes selectable in Settings without requiring manual refresh.
5. The cosmetic option is purely cosmetic — it does not unlock functionality, and the Settings UI copy makes this clear.
6. The UI copy on the unlock state says "Since you installed the app on this device" (or equivalent) to handle reinstalls accurately.
7. The evaluator does not re-evaluate already-awarded milestones on subsequent app opens (idempotent award check).
8. `flutter test` passes for all new/modified test files; `flutter analyze` shows no new warnings.

## Open questions for the implementation round
- ~~Is the reward an alternate app icon (which has real platform-specific implementation cost, differing between Android/iOS) or a simpler in-app theme accent (cheaper, no platform icon-switching API needed)?~~ **Decision: Start with a theme accent variant** (leverages existing `ModuleAccents` system, zero platform-native work, instant cross-platform). Alternate app icons are a future enhancement gated on platform-icon API investigation.
- ~~What milestone(s) beyond two years, if any, should have their own reward — or is this a single one-off for now?~~ **Decision: Single milestone at 2 years for this spec.** The schema supports N milestones; additional milestones (1 year, 5 year) are future work and do not change the implementation.
- ~~Does this need its own small "rewards" or "unlocks" section in Settings, or does it live alongside the existing achievements display?~~ **Decision: A new "Unlocks" section in Settings**, separate from achievements. Achievements are a record of what you did; unlocks are what you can apply. The two serve different UX purposes.

## Effort & sequencing notes
Complexity S, but real effort depends heavily on which cosmetic mechanism is chosen — a theme accent is trivial given the existing per-module accent system; an alternate app icon involves native platform configuration. Build directly alongside the anniversary-badge feature (#6) since they share the entire tenure-tracking and evaluation-trigger mechanism.
