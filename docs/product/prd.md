# Product Requirement Document — Habit Tracker v1.0

## 1. Problem Statement

People trying to build health-adjacent habits — drinking enough water, taking
medicine on a complex schedule, keeping up with daily prayers — currently
juggle 2-4 separate single-purpose apps (a water-reminder app, a pill
reminder, a prayer-times app), most of which require an account, phone
number, or constant connectivity, and none of which share a single dashboard
or notification model. Existing medicine-reminder apps rarely handle
real-world schedules (tapering doses, "every other day," stock-driven
refills). Existing prayer apps rarely combine prayer times with Qadha
tracking and streaks in one place. Users end up either overwhelmed by
notifications from multiple apps, or abandoning tracking altogether.

Habit Tracker consolidates three specific, high-frequency daily habits into
one offline-first app with a consistent interaction model (log → streak →
stats) and a single, coherent notification system, without requiring any
account, login, or network connection to function.

## 2. Target Users

- Users managing a chronic condition requiring scheduled medicine
  (hypertension, diabetes, etc.) who also want to track water intake and/or
  prayers in the same app.
- Practicing Muslims who want accurate, localized prayer times plus
  adherence tracking (streaks, Qadha) beyond a bare prayer-times display.
- Anyone building a simple water-intake habit who doesn't want an
  account-gated, ad-heavy, or subscription app for it.
- Caregivers tracking a dependent's (parent's, child's) medicine schedule
  on the caregiver's own device (v1: single-profile only — see Non-Goals).
- Bangla- and English-speaking users, with a strong initial focus on
  Bangladesh/South Asia (locale defaults, Hanafi Asr default, Bangla
  numerals) without excluding other English-speaking markets.

See `personas.md` for three concrete personas.

## 3. Goals (v1.0)

1. Ship three fully-functional offline modules: Water Intake, Medicine
   Schedule, Prayer Tracking — each usable independently (a user who only
   cares about water should never be forced through medicine/prayer setup).
2. Deliver reliable, actionable local notifications (Done / Snooze / Skip)
   for medicine and prayer, surviving device reboot and Doze/App Standby,
   with no network dependency.
3. Ship with English and Bangla fully localized (UI strings, and Bangla
   numerals where locale-appropriate), architected so additional languages
   are a translation-only addition (no code changes).
4. Ship an architecture where a fourth habit module (exercise, sleep, blood
   pressure, mood, expenses, etc.) can be added later as a self-contained
   plugin, without modifying Water/Medicine/Prayer module code.
5. Be usable entirely without an internet connection, forever, for every
   feature in scope for v1.0 (see Non-Goals for what explicitly needs
   connectivity later).
6. Be accessible (TalkBack/VoiceOver, scalable text, minimum touch targets)
   and performant on low-to-mid-range Android devices, not just flagship
   hardware.

## 4. Non-Goals (v1.0)

Explicitly out of scope for v1.0. Each of these may become a v1.1+ candidate
(see `roadmap.md`), but none may be assumed or half-built in v1.0:

- **Cloud sync / multi-device sync** of any kind. Architecture must not
  preclude it (repository pattern, stable export-safe IDs), but no sync
  code ships.
- **Backup/restore to Google Drive** (or any cloud storage). Local
  export/import to a file may be a v1.0-adjacent utility if trivial, but
  is not a committed v1.0 feature — see `feature-breakdown.md`.
- **Family / multiple profiles** in a single app instance. v1.0 is
  single-user, single-profile. A caregiver tracks one dependent's medicine
  by using the app as if it were their own — no profile switcher.
- **Any habit module beyond Water, Medicine, Prayer.** The plugin
  architecture must support adding one later without touching existing
  module code, but no fourth module ships in v1.0.
- **Analytics / telemetry / crash reporting that requires network.**
  Success criteria below are measured via local instrumentation and manual
  QA, not a shipped analytics SDK (see `non-functional-requirements.md`).
- **Social features** (sharing, leaderboards, friend streaks).
- **Wearable companion app** (Wear OS / watchOS).
- **Web or desktop as a real target.** Multi-platform folders exist from
  `flutter create` scaffolding; only Android and iOS are supported
  platforms for v1.0.

## 5. Success Criteria (v1.0)

Chosen to be measurable without a shipped analytics pipeline (offline-first
constraint) — verified via crash-reporting-on-opt-in, QA test plans, and
store console data, not DAU/retention dashboards:

| # | Criterion | Target | How measured |
|---|-----------|--------|---------------|
| 1 | Crash-free sessions | ≥ 99.5% | Play Console / App Store Connect crash reports (store-provided, no custom SDK) |
| 2 | Cold start time | < 2s on a mid-tier device (see NFR) | Manual benchmark on reference device set, pre-release |
| 3 | Notification delivery reliability | ≥ 95% of scheduled medicine/prayer notifications fire within 1 minute of scheduled time, across Doze/App Standby | Manual device-lab test matrix (see NFR) across top 5 OEM battery-management variants (Samsung, Xiaomi, stock Android, OnePlus, iOS) |
| 4 | Reboot survival | 100% of pending scheduled notifications re-registered after device reboot in test matrix | Manual test: schedule → reboot → verify |
| 5 | Store review acceptance | Approved on first or second submission to both stores | Submission outcome |
| 6 | Accessibility baseline | Passes automated a11y scan (flutter accessibility guideline / Xcode Accessibility Inspector) with zero critical issues | Automated scanner + manual TalkBack/VoiceOver pass on core flows |
| 7 | Localization completeness | 100% of user-facing strings present in both `en` and `bn` ARB files, zero hard-coded strings | `flutter analyze` / lint rule + manual string audit |
| 8 | Data durability | Zero data loss across app update, OS update, or force-quit during write, in test matrix | Manual test: populate data → force-quit mid-write → relaunch → verify |

## 6. Constraints

- 100% offline for all core features (hard requirement, not aspirational).
- Two languages at launch, architecture supports unlimited languages later.
- Android + iOS only.
- No backend, no accounts — nothing to build or operate server-side.

## 7. Key Risks

- **Notification reliability across OEM battery managers** is the single
  highest product risk — Android OEM battery optimization (Xiaomi MIUI,
  Samsung, etc.) is notorious for killing scheduled alarms. Mitigated by
  using exact alarms (`AlarmManager` equivalent via
  `flutter_local_notifications`) + boot receiver, and by explicit device
  test matrix in NFRs, not by assuming the plugin "just works."
- **Prayer time accuracy** is a trust-critical feature — a wrong Asr time
  by the wrong juristic method erodes trust in the whole app. Mitigated by
  making calculation method and Asr juristic method explicit, locale-defaulted
  settings (see D-06).
- **Scope creep into the plugin architecture** — building it too generic
  before a second module ever ships risks over-engineering. Mitigated by
  building the contract only after Water is fully implemented once
  concretely (see `roadmap.md` sequencing).
