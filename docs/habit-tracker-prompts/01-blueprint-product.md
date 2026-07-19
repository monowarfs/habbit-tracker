# 01 — PRODUCT BLUEPRINT (documentation only — NO code)

**Inputs:** `00-project-context.md`
**Outputs:** write each document as a separate file under `docs/product/`

Produce the following documents. Write like a professional PM/architect, not
like marketing copy. Be specific to THIS app — no generic filler.

## 1. `prd.md` — Product Requirement Document
- Problem statement, target users, goals, non-goals
- Success criteria for v1.0 (measurable, offline-appropriate — e.g. crash-free
  sessions, notification delivery reliability, not DAU/retention metrics that
  require analytics we don't ship)
- Explicit scope boundary: what v1.0 does NOT include (cloud sync, backup,
  family profiles, any module beyond the three)

## 2. `functional-requirements.md`
Number every requirement (FR-W-01, FR-M-01, FR-P-01, FR-C-01 for common).
Cover, per module, every feature listed in the project context, including
edge cases:
- Water: goal changes mid-day, retroactive logging, unit handling (ml only in
  v1 or ml+oz — decide and justify)
- Medicine: overlapping schedules, "every other day" anchored to start date,
  end-date vs. stock-exhaustion, missed-dose definition (grace window)
- Prayer: travel/timezone change, calculation method selection, Qadha
  accounting rules, Friday (Jumu'ah) replacing Dhuhr for men — make this a
  user setting, don't assume

## 3. `non-functional-requirements.md`
Concrete and testable: cold start budget, list scroll performance target,
max DB size behavior, notification delivery expectations under Doze mode,
accessibility (TalkBack/VoiceOver, minimum touch targets, text scaling).

## 4. `personas.md` — 3 personas
Ground them realistically (e.g. a Dhaka office worker managing hypertension
medicine + prayers; a student building a water habit; a caregiver tracking a
parent's medicine). Each: goals, frustrations, phone habits, connectivity
reality.

## 5. `user-stories.md`
Grouped per module + common. Format: As a / I want / So that, with acceptance
criteria for every story. Mark each story with its release phase.

## 6. `app-flow.md`
Text-based flow descriptions: first launch (language pick → optional
onboarding → dashboard), daily logging flows for each module, notification
action flows (Done/Snooze/Skip from the notification shade, app not open),
PIN unlock flow.

## 7. `navigation-map.md`
Full screen inventory with GoRouter route paths, which screens are tabs vs.
pushed, deep-link targets needed for notification taps
(e.g. `/medicine/dose/:id`).

## 8. `feature-breakdown.md`
Every feature decomposed into buildable units, tagged with the implementation
run (05–13) where it will be built.

## 9. `roadmap.md` + `release-plan.md`
- v0.x internal milestones mapped to runs 05–13
- v1.0 store release contents
- v1.1+ candidates (backup, sync, next modules) — sequence them by user value
- Store release checklist (privacy policy for an offline app, data-safety
  form answers, required iOS permission strings)

## Rules
- Where a product decision is genuinely open (e.g. ml vs. oz, Qadha counting
  method), present the options, recommend one, and record it in a
  `decisions.md` log with reasoning.
- Do not write any Dart code in this run.
