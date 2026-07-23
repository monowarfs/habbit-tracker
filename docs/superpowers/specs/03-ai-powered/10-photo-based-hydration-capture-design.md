# Photo-Based Hydration/Meal Capture (Optional)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water logging today is either a preset-amount button or a manual number
entry — reliable, but it asks the user to already know and enter an
exact volume. MyFitnessPal-class apps have popularized photo-based
capture (snap what you're drinking/eating, get an estimated quantity) as
a lower-friction, more novel entry point, particularly appealing to
users who find manual number entry tedious or who simply enjoy a more
visual/tactile logging experience. This is explicitly a novelty/optional
entry point in the atlas, not a replacement for existing quick-add.

## Goals
- Let a user optionally photograph a glass/bottle/container and have the
  app estimate a volume to pre-fill Water's log-entry amount.
- Keep this strictly opt-in and always show the estimate as an editable,
  confirmable value before logging — never auto-log without user
  confirmation.
- Keep all image processing on-device — no photo ever leaves the device,
  consistent with the app's offline/no-account/no-cloud posture.

## Non-goals / out of scope
- No cloud vision API of any kind — strictly on-device vision inference.
- No meal/food-identification or calorie-counting feature — scoped to
  container-volume estimation for Water only, per the atlas item; a
  broader nutrition-tracking feature is out of scope for this app
  entirely.
- Not a primary logging path — this supplements, never replaces, the
  existing quick-add buttons and manual entry, since photo capture is
  inherently slower and less reliable for a fast, frequent action like
  logging water.
- Photos themselves are not retained/stored after the estimate is
  produced and confirmed, avoiding turning this into an implicit photo
  library feature.

## Proposed approach (high-level)
An on-device vision model (bundled with the app or downloaded once and
cached locally, never a live cloud inference call) takes a camera
capture of a container and produces a rough volume estimate — the
model's job is narrowly scoped to "how big is this container," not
open-ended image understanding. That estimate flows into the exact same
`LogWaterEntryUseCase` every other Water logging path already uses (its
amount > 0 / no-future-timestamp validation applies identically), with
the estimated number shown in an editable field the user confirms or
adjusts before it's saved — the photo itself is discarded once the
estimate is produced, unless the user explicitly wants to retry the
capture. This is additive to Water's existing logging UI: a camera-icon
entry point alongside the current quick-add grid, not a new screen
replacing it.

## Dependencies & prerequisites
- An on-device vision/object-size-estimation model — a new, non-trivial
  dependency (model size, on-device inference performance across a wide
  range of device hardware, and platform packaging both need real
  evaluation before committing).
- Camera permission handling, with a clear rationale prompt consistent
  with how other permission asks are handled in this app.
- A decision on whether the model ships bundled in the app binary
  (larger app size, works fully offline immediately) or downloaded
  on first use (smaller initial install, but a first-run network
  dependency that cuts against the offline-first story unless handled
  carefully).

## Open questions for the implementation round
- Which on-device vision approach is realistic given Flutter's plugin
  ecosystem and the need for this to work consistently across a wide
  range of Android/iOS device capability tiers?
- How accurate does the estimate need to be to be trustworthy enough that
  users don't immediately distrust and abandon the feature — is a rough
  small/medium/large container-size classification (mapped to typical
  volumes) sufficient instead of a precise ml estimate?
- Bundled-in-app vs. download-on-first-use for the model, and how that
  interacts with the app's offline-first framing if download is chosen?
- Is this worth the model-size/complexity cost given it's explicitly a
  novelty entry point rather than a primary flow — is a much simpler
  "tap a container-size icon" (no vision at all) most of the value at a
  fraction of the effort?

## Effort & sequencing notes
Complexity M as scoped in the atlas, though the open question above about
whether a non-vision container-size-icon shortcut captures most of the
value at far lower cost is worth revisiting before committing to on-
device vision infrastructure. Lowest-priority item to sequence relative
to on-device-arithmetic items in this category given the dependency and
accuracy risk.
