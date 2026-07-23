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

## Dependencies & prerequisites
- The achievements engine (award/evaluation/repository) and the same install-date/tenure signal the anniversary badge needs.
- The app's existing theming system (for a theme-accent-style reward) or platform alternate-icon support (for an icon-style reward) — whichever cosmetic mechanism is chosen determines real platform-level prerequisites worth checking early (iOS/Android alternate icon support differs).
- Settings screen, as the place a user would go to apply an unlocked cosmetic.

## Open questions for the implementation round
- Is the reward an alternate app icon (which has real platform-specific implementation cost, differing between Android/iOS) or a simpler in-app theme accent (cheaper, no platform icon-switching API needed)?
- What milestone(s) beyond two years, if any, should have their own reward — or is this a single one-off for now?
- Does this need its own small "rewards" or "unlocks" section in Settings, or does it live alongside the existing achievements display?

## Effort & sequencing notes
Complexity S, but real effort depends heavily on which cosmetic mechanism is chosen — a theme accent is trivial given the existing per-module accent system; an alternate app icon involves native platform configuration. Build directly alongside the anniversary-badge feature (#6) since they share the entire tenure-tracking and evaluation-trigger mechanism.
