# Reduce-Motion Respect

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a mostly-preventive audit-and-fix item: it matters most as a guardrail against future work. Neither the current codebase nor the atlas's Delightful/Gamification categories have shipped streak-save or companion animations yet, but once they do, any animation that isn't checked against the OS-level reduce-motion setting is a WCAG 2.1 gap for users who rely on that setting to avoid discomfort (vestibular disorders, motion sensitivity) or distraction. Catching this now, as a standing check applied to each new animation, is cheaper than retrofitting it across several animations later.

## Goals

- Establish a standing rule: any animation added anywhere in the app (streak-save celebration, companion/mascot animation, or any future micro-interaction) checks `MediaQuery.of(context).disableAnimations` (the Flutter-level reflection of the OS reduce-motion setting) and substitutes an instant state change when it's set.
- Apply this rule retroactively to any animation that already exists today, if any is found during implementation.
- Keep the fallback behavior equivalent in information, not just faster — the end state (streak saved, action confirmed) must still be conveyed, just without the animated transition.

## Non-goals / out of scope

- Building a custom in-app "reduce motion" toggle separate from the OS setting — respect the OS-level signal, don't duplicate it.
- Designing the animations themselves — those belong to the Delightful/Gamification features that introduce them; this item only adds the reduce-motion guard around whatever they build.
- Any audio/haptic equivalent for the removed animation — that's a separate concern from motion.

## Proposed approach (high-level)

Treat this as a lightweight convention rather than a feature: wherever a new animated widget is introduced, wrap its animated build path in a check against `MediaQuery.disableAnimations` and provide a non-animated fallback that jumps straight to the end state. Because no streak-save or companion animation exists yet in the codebase per the current project state, the practical first step is documenting the convention (e.g. in the coding standards or a short note alongside the theme/animation-related code) so whichever run implements Delightful/Gamification animations builds this in from the start, rather than needing a follow-up audit later.

## Dependencies & prerequisites

- Depends on the Delightful/Gamification category's streak-save and companion animation features actually being scheduled — this item has no code to change today if none of those exist yet; it's a convention to enforce going forward.
- If any animation is found to already exist somewhere in the app during implementation, treat that as an in-scope fix, not a scope change.
- No new dependency — `MediaQuery.disableAnimations` is part of Flutter.

## Open questions for the implementation round

- Should this be enforced by a lint rule / code-review checklist item, or is a documented convention plus spot-checking sufficient?
- Do streak-save/companion animations get built with reduce-motion in mind from day one (preferred), or does this item become a follow-up pass after they ship?
- Are there existing transitions (e.g. route transitions, `AnimatedContainer` uses already in the app) that should be swept for this now, independent of future Delightful/Gamification work?

## Effort & sequencing notes

Complexity S — a small, mechanical check applied per-animation, not a standalone body of work. Sequence this as a standing convention to apply whenever Delightful/Gamification's animation features are implemented, rather than a one-time task with a fixed start date; revisit as a real audit once those animations exist.

## Localization

- No new ARB keys are needed for the reduce-motion convention itself — the non-animated fallback is the same state shown after an animation completes, just without the transition.
- If a future settings toggle for in-app reduce-motion is added (beyond the OS-level setting), it would need:
  - `settings_reduce_motion_label` — "Reduce Motion" / "মোশন কমান"
  - `settings_reduce_motion_description` — explanatory text.
- For the current scope (respecting `MediaQuery.disableAnimations`), no user-facing strings change.

## Edge cases & error handling

1. **Existing route transitions** — Flutter's default route transitions (slide, fade) are animations that should respect reduce-motion; if the app uses `MaterialPageRoute` or `GoRouter` transitions, verify these honor `disableAnimations` or replace them with instant transitions when the setting is active.
2. **`AnimatedContainer` / `AnimatedOpacity` in existing widgets** — scan for any existing uses of implicit animation widgets in the codebase (stats screen number counters, streak animations, progress indicators) and wrap them in the `disableAnimations` check.
3. **Lottie/Rive animations (if added later)** — if future gamification features use Lottie or Rive for complex animations, the convention must extend to those libraries' play/pause APIs, not just Flutter's built-in animation widgets.
4. **Partial animation reduction** — some users may want to reduce but not eliminate motion (e.g. shorter duration vs. instant); the initial scope should keep it binary (animate or instant) per the OS setting, with duration reduction as a potential future enhancement.
5. **Transition from animated to non-animated state** — when reduce-motion is active, the app must still convey the same end-state information (streak saved, action confirmed) — the non-animated path must reach the identical final state, just without the transition.

## Cross-references

- `docs/superpowers/specs/07-accessibility/04-haptic-feedback-on-log-complete-design.md` — haptics provide non-visual confirmation independent of motion; complementary to reduce-motion.
- `docs/superpowers/specs/07-accessibility/08-audio-cue-alternative-notification-actions-design.md` — audio earcons are another non-motion confirmation channel.
- `lib/core/theme/app_theme.dart` — if any theme-level transitions exist, they must respect `disableAnimations`.
- `lib/core/router/app_router.dart` — route transitions are the most likely existing animation to check.
- Delightful/Gamification spec files (future) — any streak-save or companion animation must include reduce-motion as a first-class requirement.

## Test strategy

- **Widget tests**: Create `test/accessibility/reduce_motion_test.dart` that:
  - Pumps a widget with `MediaQuery(disableAnimations: true)` and verifies no `AnimationController` is running (or that the non-animated fallback state is rendered).
  - Pumps the same widget with `disableAnimations: false` and verifies the animation plays.
- **Unit tests**: Once Delightful/Gamification animations exist, unit test the animation helper/wrapper to confirm it checks `disableAnimations` and branches to the non-animated path correctly.
- **Regression-prevention strategy**: Add a lint rule or code-review checklist item: "Any new `AnimationController`, `Tween`, `AnimatedContainer`, `AnimatedOpacity`, `Lottie`, or `Rive` usage must include a `disableAnimations` check." Document this in `docs/engineering/coding-standards.md`.
- **Manual verification**: When animations are added, manually test with the OS reduce-motion toggle enabled on both iOS and Android to confirm the non-animated fallback is visually correct.
- **No golden tests** — reduce-motion is a behavioral check (does the animation play or not), not a visual snapshot.
