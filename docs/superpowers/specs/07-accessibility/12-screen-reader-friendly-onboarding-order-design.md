# Screen-Reader-Friendly Onboarding Order

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is an audit-and-fix item, targeted specifically at the module-enable checklist step of onboarding (the Water/Medicine/Prayer toggle screen), rather than the whole onboarding flow. This screen is the exact moment a "minimal-setup" persona decides which modules to turn on — including the option to skip most of setup entirely — and it needs to read and operate correctly under TalkBack from the very first run, since a screen-reader user who can't tell what each toggle does or can't tell whether a toggle is on/off at this step is blocked before they ever reach the rest of the app.

## Goals

- Verify (and fix as needed) that the module-enable checklist screen announces each module toggle's name, current state (on/off), and purpose clearly under TalkBack, in an order that matches the visual list.
- Confirm the "skip setup" path (however it's exposed) is itself reachable and clearly labeled for a screen-reader user, not just visually discoverable.
- Confirm toggling a switch announces its new state immediately, so a screen-reader user gets the same instant confirmation a sighted user gets from seeing the switch move.

## Non-goals / out of scope

- The rest of the onboarding flow beyond the module-toggle checklist screen — this item is scoped to that one screen, since it's the specific step named in the atlas item.
- The full app-wide screen-reader audit (that's item #1) — this item is a narrower, earlier check specifically because onboarding is the very first thing a new screen-reader user encounters, and is worth verifying in isolation even before the broader audit runs.
- Any redesign of the onboarding flow's content or ordering of module choices — only the accessibility operability of the existing/planned flow is in scope.

## Proposed approach (high-level)

Once the onboarding module-toggle checklist exists (it's currently a placeholder per CLAUDE.md), walk it with TalkBack enabled and confirm each toggle row announces the module name, its on/off state, and enough context to know what enabling it does, with focus order matching the visual list top to bottom. Verify the skip/continue affordance is labeled clearly enough that a screen-reader user recognizes it as the way to finish setup without configuring individual modules. This reuses the same `Semantics`-labeling approach item #1 establishes for the rest of the app — the reason to call this out as its own item rather than folding it into item #1 is sequencing: it's the first screen any new screen-reader user meets, so it's worth a standalone check the moment the onboarding flow itself is built, rather than waiting for the full app-wide audit later.

## Dependencies & prerequisites

- Depends on the onboarding module-toggle checklist screen actually being built — today it's still a placeholder per CLAUDE.md, so this item's audit portion can't run until that screen exists.
- Should reuse whatever `Semantics`-labeling conventions item #1's audit establishes, so the two don't produce inconsistent labeling patterns for the same kind of toggle control used elsewhere in the app (e.g. Settings toggles).
- No new dependency — this is Flutter's built-in `Semantics`/`Switch` accessibility behavior, verified and, if needed, made explicit.

## Open questions for the implementation round

- Does the "skip setup" affordance already exist in the onboarding design, or does this item need to wait on that design decision being made first?
- Should this be verified as part of the onboarding feature's own definition of done (built in from the start) rather than as a separate follow-up audit — likely yes, given how cheap it is to check while the screen is being built versus retrofitting later?
- Are there other first-run screens (e.g. a permissions-explainer screen, already noted in CLAUDE.md's notification engine) that should be checked in the same pass since they're also part of a new user's first experience?

## Effort & sequencing notes

Complexity S — one screen, reusing item #1's labeling approach rather than inventing a new one. Sequence: wait for the onboarding module-toggle screen to be built, then check it immediately (ideally as part of that screen's own implementation, not a deferred follow-up), rather than waiting for the full app-wide audit in item #1 to reach it.

## Database schema

No database changes. This is an audit of an existing (future) screen's
accessibility behavior.

## Localization

No new ARB keys needed. The audit verifies that existing toggle labels
and skip/continue buttons are properly announced by screen readers.
The `Semantics` labels should use existing localized strings from
`app_en.arb`/`app_bn.arb`.

## Edge cases & error handling

- **Toggle state announcement:** verify that toggling a switch
  announces its new state immediately (e.g. "Water, on" / "Water, off").
- **Skip path accessibility:** the "Skip Setup" button must be reachable
  by keyboard/tab and clearly labeled for screen readers.
- **Empty state:** if the user skips all modules, the dashboard's
  empty state must also be accessible.
- **Notification permission screen:** if a permission explainer screen
  exists (per CLAUDE.md), it should be checked in the same pass.

## Cross-references

- Onboarding: currently a placeholder (per CLAUDE.md). This audit runs
  when the onboarding screen is built.
- Related: Spec 07-accessibility/01 (TalkBack audit) — this is a
  targeted subset of the full audit.
- Related: Spec 07-accessibility/11 (captioned onboarding) — both
  concern onboarding accessibility.

## Test strategy

- Widget test: verify toggle announces name and state under semantics.
- Widget test: verify skip button is reachable and labeled.
- Manual audit: walk the onboarding screen with TalkBack enabled.
