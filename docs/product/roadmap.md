# Roadmap

**Assumption:** the run numbering below (05-14) is proposed by this
document, not supplied in the input brief — it's the sequencing referenced
throughout `feature-breakdown.md` and `user-stories.md`. If a different run
scheme already exists elsewhere in the project's planning, reconcile against
that instead of this proposal.

**Renumbered during Run 06 implementation:** a "Core infrastructure"
run (database, settings persistence, error handling, logging, clock) was
inserted as Run 06 — something this document's original pass didn't
anticipate needing as its own dedicated run. Every run from the old
"Run 06" (Water) onward shifted down by one; the table below reflects the
actual executed sequence.

## v0.x internal milestones (runs 05-14)

| Version | Run(s) | Contents | Exit criteria |
|---|---|---|---|
| v0.1 | 05 | App shell, theme, localization scaffold, onboarding skeleton, plugin contract (interface) | App launches, language switch works, onboarding reaches empty dashboard |
| v0.15 | 06 | Core infrastructure: database, settings persistence, error handling, logging, clock | Theme/language survive app restart; domain-logic clock/day-bucketing tests pass |
| v0.2 | 07 | Water module complete | Water FRs (W-01 to W-10) pass manual QA; unit tests green for domain logic |
| v0.3 | 08 | Medicine domain & data | Domain unit tests pass for every schedule pattern incl. every-other-day/DST edge case; no UI yet |
| v0.4 | 09 | Medicine presentation & notifications | Medicine FRs (M-01 to M-10) pass manual QA incl. notification actions with app killed |
| v0.5 | 10 | Prayer domain & data | Calculation engine verified against known reference times for at least 3 methods; Qadha/Jumu'ah logic unit-tested |
| v0.6 | 11, 12 | Prayer presentation, notification hardening | Prayer FRs (P-01 to P-10) pass manual QA; device test matrix (NFR-07/08/09) passes on all 5 environments |
| v0.7 | 13 | Dashboard, module toggle, PIN lock | FR-C-02/03/04/10 pass manual QA; a module can be disabled/re-enabled with data intact |
| v0.8 (RC) | 14 | Polish, a11y, localization QA, store prep | All NFRs in `non-functional-requirements.md` verified; store listing assets ready |
| v1.1 | 15 | Dashboard day-completion/upcoming/quick-actions, cross-module reports + longest-streak records, achievement engine + badge gallery, cross-module search, global month calendar | FR-C-11..16 pass manual QA; badge unlock shows a snackbar not a modal; Bangla pass on all four new surfaces |

## v1.1+ candidates, sequenced by user value

Not committed, ordered by expected user value vs. effort, for
reprioritization once real usage data (store reviews, support requests)
exists:

1. **Local export/import (file-based backup).** Highest value-per-effort:
   addresses data-loss anxiety (Farida's persona explicitly distrusts
   cloud health apps, but still wants *some* safety net) without any
   cloud infrastructure. Natural first step before real cloud sync.
2. **Google Drive backup/restore.** The architecture already anticipates
   this (repository pattern, stable export-safe IDs per project context);
   this is where that groundwork gets used. Higher value than full sync
   for most users (occasional backup vs. always-on sync).
3. **Multi-device cloud sync.** Larger effort (conflict resolution,
   backend or serverless sync target), deferred until backup validates
   real demand for going beyond single-device.
4. **Family / multiple profiles.** Directly requested by the caregiver
   persona pattern (Farida); sequenced after backup/sync because
   multi-profile is far more valuable once data can also move between
   devices (a caregiver managing a parent's data on the parent's own new
   phone, for instance).
5. **Additional habit modules** (exercise, sleep, blood pressure, mood,
   expenses). Sequenced last among these five because the plugin
   architecture is what makes them cheap *whenever* they're built — no
   urgency to rush a fourth module before the core three are proven with
   real users, and each new module is independent scope that can be
   prioritized purely by user request volume.

See `release-plan.md` for v1.0 release contents and the store submission
checklist.
