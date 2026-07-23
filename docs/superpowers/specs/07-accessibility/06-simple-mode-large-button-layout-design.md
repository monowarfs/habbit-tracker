# "Simple Mode" Large-Button Layout

**Category:** Accessibility · **Atlas complexity:** L · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is the largest net-new feature in this category. The app's default layouts are dense, multi-column, and sized for an average user — reasonable for most people but a real barrier for an elderly or low-vision user who is also, per this app's offline-first/no-account positioning, likely to be a self-directed non-account-holder without anyone else to configure the app for them. An alternate, single-column, oversized-touch-target layout for the key screens directly serves that persona, in the spirit of senior-focused apps (the GreatCall/Jitterbug class of product) that ship a "simple mode" as a first-class, not bolted-on, option.

## Goals

- Offer an opt-in "Simple Mode" toggle (in Settings) that switches key screens — at minimum the dashboard, and each module's primary log/quick-action screen (Water quick-add, Medicine dose list, Prayer checklist) — to a single-column layout with larger touch targets and larger default text.
- Keep Simple Mode's data and logic identical to normal mode — it's a presentation-layer alternate layout, not a different feature set or a different data model.
- Make the toggle easy to find and easy to reverse from Settings.

## Non-goals / out of scope

- A separate onboarding flow or separate app icon/branding for Simple Mode — it's a layout toggle, not a different app.
- Rebuilding every screen in the app for Simple Mode in the first pass — start with the highest-traffic screens (dashboard + one primary action screen per module) and treat full coverage as a follow-up if adopted.
- Voice-control or other input-method alternatives — Simple Mode is specifically about layout density and touch-target size, not a new input modality.

## Proposed approach (high-level)

Add a `Simple Mode` setting alongside the existing theme/locale settings (same settings-persistence pattern already used for theme mode and locale), and have the key screens branch their layout based on that setting — collapsing multi-column/dense layouts into a single column with larger buttons and text, reusing the same underlying data/controllers each screen already has (this is a presentation swap, not a new domain layer). Where existing widgets already parameterize size (buttons, list tiles), prefer growing those parameters over building all-new Simple-Mode-only widgets; only build a distinct widget where the layout shape itself genuinely differs (e.g. a single big "log now" button replacing a row of quick-add chips). The existing per-module accent colors and `AppSemanticColors` extension should carry over unchanged — Simple Mode changes size and density, not color or branding.

## Dependencies & prerequisites

- Depends on the settings persistence pattern already in place (`AppSettings`/`SettingsRepository`) to add and store the new toggle the same way theme mode and locale are stored today.
- Benefits from items #1 (screen-reader audit) and #5 (text-scaling stress test) being done first, since Simple Mode's larger targets and text should build on layouts that are already known to behave correctly at scale, rather than compounding two unverified assumptions at once.
- Should follow item #3 (colorblind-safe palette) if Simple Mode introduces any new status indicators, so it inherits an already-verified palette instead of a new one.

## Open questions for the implementation round

- Which screens are "key" for a first pass — is dashboard + one screen per module sufficient, or does the persona need the full log-history/stats screens simplified too?
- Does Simple Mode also imply reduced information density (e.g. hiding secondary stats) or purely larger/single-column presentation of the same information?
- Should Simple Mode be a binary global toggle, or could it eventually be scoped per-module (e.g. only Medicine, if that's the module most used by the target persona)? Scope the first version as global unless there's a clear reason not to.

## Effort & sequencing notes

Complexity L — the largest item in this category; touches multiple screens across modules and needs a new settings toggle wired through to layout branching. Sequence after items #1, #3, and #5 (the three audits) so Simple Mode is built on already-verified accessibility foundations rather than needing its own separate audit pass afterward.
