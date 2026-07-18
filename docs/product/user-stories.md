# User Stories

**Assumption:** implementation run numbers (05-14) referenced here follow the
sequencing proposed in `roadmap.md` (Run 05 = app shell/common, 06 = core
infrastructure, 07 = Water, 08-09 = Medicine, 10-11 = Prayer, 12 =
notification hardening, 13 = dashboard/plugin contract/PIN, 14 =
polish/a11y/store prep). Not specified in the input brief, so proposed
here and reused consistently across documents — flag if a different
scheme already exists.

**Renumbered during Run 06 implementation:** a "Core infrastructure" run
was inserted as Run 06 (not anticipated when this document's phase tags
were first written) — every run from the old "Run 06" (Water) onward
shifted down by one. The phase tags below reflect the actual executed
sequence.

Format: As a [persona-type] / I want / So that. AC = acceptance criteria.
Phase = target implementation run and/or release milestone.

---

## Common (Run 05, 12, 13, 14)

**US-C-01** — As a first-time user, I want to pick my language before
anything else, so that the rest of setup is in a language I understand.
- AC: Language picker is the first screen on first launch; selecting
  English or Bangla immediately re-renders all subsequent UI in that
  language.
- Phase: Run 05 / v0.1.

**US-C-02** — As a new user, I want to choose which modules I care about
during onboarding, so that I'm not forced to configure a medicine schedule
if I only want to track water.
- AC: Onboarding presents three module toggles (Water/Medicine/Prayer),
  all off by default; only enabled modules prompt for their setup step;
  user can finish onboarding with zero modules enabled and land on an
  empty dashboard with an "add a module" CTA.
- Phase: Run 13 / v0.7.

**US-C-03** — As a returning user, I want a single dashboard showing
today's status across every module I've enabled, so that I don't have to
open three separate screens every morning.
- AC: Dashboard shows water progress ring, next/overdue medicine dose (if
  any), and current/next prayer (if enabled) in one scroll-free view on a
  standard phone screen.
- Phase: Run 13 / v0.7.

**US-C-04** — As a privacy-conscious user, I want an optional PIN lock, so
that someone picking up my phone can't see my health data.
- AC: Settings toggle enables 4-digit PIN with a configurable re-lock
  timeout; enabling it shows a one-time warning that there is no
  recovery path other than resetting app data.
- Phase: Run 13 / v0.7.

**US-C-05** — As a user on a low-battery device, I want notifications to
fire reliably even when my phone has been idle for hours, so that I don't
miss a medicine dose because my phone "went to sleep."
- AC: Notifications fire within 60s of scheduled time after device has
  entered Doze mode in test matrix (NFR-08).
- Phase: Run 12 / v0.6.

**US-C-06** — As a user, I want to tap a notification action (Done/Snooze/
Skip) without opening the app, so that logging is a one-tap action from
the lock screen.
- AC: All three actions work with the app process fully killed and
  survive a device reboot beforehand.
- Phase: Run 12 / v0.6.

---

## Water (Run 07)

**US-W-01** — As a user building a water habit, I want to set a daily
goal in ml, so that I have a clear target.
- AC: Goal input accepts 250-10,000 ml range, defaults to 2000 ml
  suggestion which the user must confirm or change.
- Phase: Run 07 / v0.2.

**US-W-02** — As a user who prefers imperial units, I want to view my
water intake in fl oz, so that the numbers mean something to me.
- AC: Settings unit toggle switches all displayed values (goal, log
  amounts, stats) between ml and fl oz without altering stored data (D-01).
- Phase: Run 07 / v0.2.

**US-W-03** — As a user, I want one-tap quick-add buttons for common
amounts, so that logging water takes under 2 seconds.
- AC: Three configurable quick-add presets on the main water screen; tap
  logs an entry immediately with no confirmation dialog.
- Phase: Run 07 / v0.2.

**US-W-04** — As a user who forgot to log earlier, I want to backdate an
entry to an earlier time today, so that my stats reflect reality.
- AC: Custom entry screen has a date/time picker capped at "now"; backdated
  entries immediately update that day's total and streak.
- Phase: Run 07 / v0.2.

**US-W-05** — As a user who changes my goal mid-day, I want today's
progress to reflect the new goal immediately, without rewriting yesterday's
completed streak day.
- AC: Matches FR-W-04 exactly; verified via test: log to 100% of old goal,
  raise goal, confirm progress bar drops below 100% today but yesterday's
  streak day (evaluated against the old goal) stays marked complete.
- Phase: Run 07 / v0.2.

**US-W-06** — As a user, I want to see my current and longest streak plus
a 30-day history view, so that I stay motivated.
- AC: Stats screen shows both streak numbers and a calendar/bar chart for
  at least 30 days, loads in < 300ms on reference device (NFR-03).
- Phase: Run 07 / v0.2.

---

## Medicine (Run 08-09)

**US-M-01** — As a caregiver managing multiple medicines with different
schedules, I want to set up a tapering schedule (twice daily, then once
daily), so that the app matches my father's actual prescription.
- AC: Can create two schedules under one medicine with adjacent, non-
  overlapping date ranges; daily view shows the correct dose count for
  each day per D-02/FR-M-02.
- Phase: Run 08 / v0.3.

**US-M-02** — As a user prescribed "every other day" medicine, I want the
app to correctly alternate dose days starting from when I began the
prescription, so that I don't take it on the wrong day.
- AC: Matches D-03 exactly; verified with a schedule started on a known
  date and checked across a 14-day window including a DST transition date
  in the test matrix.
- Phase: Run 08 / v0.3.

**US-M-03** — As a user tracking pill stock, I want to be warned when I'm
running low, without the app silently stopping my reminders if I run out,
so that I never go without medicine unnoticed (Farida's exact past
failure).
- AC: Matches D-04/FR-M-04/05; low-stock banner and one notification fire
  at threshold; reminders continue past zero stock unless
  `stopWhenStockDepleted` is explicitly enabled.
- Phase: Run 08-09 / v0.3-0.4.

**US-M-04** — As a busy user, I want a grace window before a dose counts
as "missed," so that a 10-minute delay grabbing water with my pill doesn't
wreck my adherence stats.
- AC: Matches D-05/FR-M-06; default 30 min grace, editable per medicine.
- Phase: Run 08 / v0.3.

**US-M-05** — As a user, I want to mark a dose Done, Snooze, or Skip
directly from the notification, so that I don't need to open the app for
routine logging.
- AC: Matches FR-M-07; verified with app killed.
- Phase: Run 09 / v0.4.

**US-M-06** — As a user, I want to see my adherence percentage over the
last 30 days per medicine, so that I can discuss it with my doctor.
- AC: Stats screen breaks down on-time/late/missed/skipped percentages per
  medicine, 7/30/all-time windows (FR-M-08).
- Phase: Run 09 / v0.4.

---

## Prayer (Run 10-11)

**US-P-01** — As a user in Bangladesh, I want prayer times calculated with
the method and Asr juristic ruling common in my region by default, so
that times match what my local mosque announces without manual setup.
- AC: Locale-based defaults per D-06 (Karachi method, Hanafi Asr for BD
  locale); both independently changeable in Settings.
- Phase: Run 10 / v0.5.

**US-P-02** — As a user who leads/attends Jumu'ah, I want Friday's Dhuhr
replaced by Jumu'ah in my checklist, but only if I explicitly turn that on,
so that the app doesn't assume anything about my gender or practice.
- AC: Matches D-07/FR-P-03; off by default; toggling it relabels only
  Friday's entry and only going forward (does not rewrite past Fridays).
- Phase: Run 10 / v0.5.

**US-P-03** — As a user restarting my prayer tracking after a period of
inconsistency, I want to record how many missed prayers I already owe
(Qadha) before I started using the app, so that my counter starts
accurately.
- AC: Onboarding/Settings screen accepts a starting count 0-9999 per
  prayer; skipping defaults all to 0 (FR-P-04).
- Phase: Run 10 / v0.5.

**US-P-04** — As a user, I want a missed prayer to automatically add to
my Qadha count, and a dedicated screen to pay it down over time, so that
I have an accurate running total without manual daily bookkeeping.
- AC: Matches D-08/FR-P-05; auto-increment at cutoff; "−1" control per
  prayer on Qadha screen; counters floor at 0.
- Phase: Run 10-11 / v0.5-0.6.

**US-P-05** — As a frequent traveler, I want prayer times to update
automatically when I land in a new timezone, so that I don't have to
remember to change a setting manually.
- AC: Matches D-09/FR-P-06; recompute on foreground + midnight background
  refresh; manual-city fallback with a visible banner if location denied.
- Phase: Run 10 / v0.5.

**US-P-06** — As a user, I want a one-tap "Prayed" action per prayer, and
notification actions matching the medicine module's pattern, so that the
interaction model feels consistent across the app.
- AC: Matches FR-P-07/08; reuses the same Done/Snooze/Skip component used
  by Medicine (see `feature-breakdown.md` for the shared component note).
- Phase: Run 11 / v0.6.

**US-P-07** — As a user, I want to see my prayer streak and per-prayer
on-time percentage, so that I can track consistency the same way I do for
water and medicine.
- AC: Matches FR-P-09/10.
- Phase: Run 11 / v0.6.
