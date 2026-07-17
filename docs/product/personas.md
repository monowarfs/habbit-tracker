# Personas

Three grounded personas, one per primary launch persona pattern. Used to
sanity-check every FR against a real mental model, not a demographic label.

---

## 1. Rafiq — Dhaka office worker managing hypertension

- **Age/context:** 42, mid-level manager at a private bank in Dhaka.
  Diagnosed with hypertension 2 years ago, prescribed a daily
  morning/evening medicine, told by his doctor to also drink more water
  and to keep up his five daily prayers (currently inconsistent, misses
  Asr and Isha most often due to meetings and fatigue).
- **Goals:** Never miss a blood pressure dose (missing it has real health
  consequences he's felt before); build a habit of drinking water through
  a desk-bound workday; slowly rebuild prayer consistency without a
  judgmental or preachy app tone.
- **Frustrations:** Previous pill-reminder app required an account and
  nagged him to upgrade to premium; a prayer-times app he tried used the
  wrong Asr calculation for his region and he didn't understand why his
  Asr time looked "late" compared to the mosque's announced time until a
  colleague explained the Hanafi/Standard difference.
- **Phone habits:** Android (Samsung), moderate app literacy, keeps
  battery-saver aggressive because his phone is 3 years old and battery
  degrades — this makes him a real-world test case for NFR-07/08
  (notification reliability under OEM battery management).
- **Connectivity reality:** Decent 4G at work, patchy/no data at his
  parents' village on weekends. Needs the app to work identically in
  both places.
- **What matters most to him:** FR-M-06/07 (missed-dose grace + reliable
  notification actions), FR-P-02 (Hanafi Asr default), FR-P-05 (Qadha
  tracking without guilt-tripping UI copy).

---

## 2. Nusrat — university student building a water habit

- **Age/context:** 21, undergraduate in Dhaka, wants to drink more water
  because she gets frequent headaches she suspects are dehydration-related.
  No medicine to track, not currently focused on prayer tracking (may
  enable it later, doesn't want to be forced through that setup now).
- **Goals:** Build a simple, low-friction daily water habit; see visible
  progress (streaks, stats) as motivation; doesn't want an app that feels
  "medical" or heavy for something this simple.
- **Frustrations:** Tried a popular water app that required creating an
  account just to set a daily goal, and buried the "skip sign-up" option;
  found most water apps push premium subscriptions for basic stats.
- **Phone habits:** Budget Android phone (Xiaomi), very online but data-
  conscious (limited monthly data plan) — reinforces that the app must
  never require connectivity for daily use.
- **Connectivity reality:** WiFi at home/campus, deliberately limits
  mobile data use, sometimes goes hours with data off entirely.
- **What matters most to her:** FR-C-02 (onboarding lets her enable only
  Water, skip Medicine/Prayer setup entirely), FR-W-06/07/08 (visible
  streaks and stats), NFR-06 (small app size — she's careful about
  storage/data on a budget device).

---

## 3. Farida — caregiver tracking her father's medicine

- **Age/context:** 35, lives with and cares for her father (68) who takes
  four different medicines on overlapping schedules (some daily, one
  "every other day," one PRN for pain). She manages his medicine on her
  own phone since he doesn't use a smartphone.
- **Goals:** Never let her father miss a dose or run out of stock
  unexpectedly (a pharmacy run takes real planning — it's not a same-day
  errand for her); understand at a glance what's due today across all
  four medicines without opening four separate reminders in her head.
- **Frustrations:** A previous reminder app could only handle one
  schedule per medicine, so she couldn't represent the tapering schedule
  his doctor prescribed after a hospital stay; another app's stock
  tracking silently stopped reminders when stock hit zero, and her father
  went two days without his medicine before she noticed (this is the exact
  failure mode D-04 is written to prevent).
- **Phone habits:** iPhone, moderate-high app literacy, relies heavily on
  notifications and lock-screen glanceability throughout her day since
  she's managing this alongside her own job.
- **Connectivity reality:** Reliable home WiFi, decent mobile data, but
  values that the app doesn't need any of it — she's specifically wary of
  cloud-based health-adjacent apps after a data-privacy scare with an
  unrelated fitness app.
- **What matters most to her:** FR-M-02 (overlapping/multiple schedules
  per medicine), FR-M-04/05 (stock tracking that never silently disables
  reminders), FR-C-03 (dashboard aggregating all due doses at a glance),
  FR-C-01 (fully offline, no account, no cloud — addresses her privacy
  concern directly).

Note: v1.0 has no multi-profile support (see PRD Non-Goals) — Farida tracks
her father's medicine using her own single-profile instance of the app, not
a separate "Dad" profile. This is a known v1.0 limitation, not something to
work around with a hidden feature.
