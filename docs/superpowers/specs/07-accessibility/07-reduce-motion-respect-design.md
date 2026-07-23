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
