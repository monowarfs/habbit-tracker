# Functional Requirements

Numbering: `FR-W-##` Water, `FR-M-##` Medicine, `FR-P-##` Prayer, `FR-C-##`
Common/cross-module. Each requirement is independently testable. Decisions
referenced as `D-##` are logged in `decisions.md`.

---

## Water Intake (FR-W)

**FR-W-01** — User sets a daily water goal (in ml, stored canonically in ml
per D-01), editable at any time. Default goal on first setup: 2000 ml
(user must confirm or change during onboarding, not silently applied).

**FR-W-02** — User may switch display unit between ml and fl oz in Settings
(D-01). Changing the unit changes only the display/entry formatting; the
stored goal and all logged entries remain in ml. Conversion: 1 fl oz =
29.5735 ml, displayed values rounded to nearest whole unit.

**FR-W-03** — User logs water intake via quick-add buttons (configurable
presets, default 250 ml / 500 ml / 750 ml) and a custom-amount entry. Each
log entry stores: amount (ml), timestamp (device local time at time of
entry), and an optional "logged for" date/time if backdated (FR-W-05).

**FR-W-04** — **Goal changed mid-day.** If the user changes their daily
goal after already logging intake today, today's progress bar recalculates
against the new goal immediately; past days' completion status (for streak
purposes) is evaluated against whatever goal was active on that day, not
retroactively against the new goal. Rationale: a day is "complete" or not
based on the goal that applied when it happened.

**FR-W-05** — **Retroactive logging.** User can add a water entry for an
earlier time today or a previous date (date picker, cannot select a future
date/time). Backdated entries recalculate that day's total and streak
status immediately. A backdated entry cannot push a day's log past the
current wall-clock time (no logging "for later today").

**FR-W-06** — Daily progress view shows: current total / goal, a visual
progress indicator, and remaining amount to reach goal (or "goal reached"
state, which remains reachable/editable — logging more after goal is met
still records the entry).

**FR-W-07** — Streak = consecutive calendar days (local timezone) where
total logged ≥ that day's goal. A day with zero entries breaks the streak
at day rollover, not retroactively — the app does not walk back and edit
history, it evaluates streak length forward from stored daily totals.

**FR-W-08** — Stats view shows: current streak, longest streak, average
daily intake (last 7/30 days), and a calendar/bar view of daily totals vs.
goal for at least the last 30 days.

**FR-W-09** — User can delete or edit an individual log entry; deleting/
editing recalculates that day's total, streak, and stats immediately.

**FR-W-10** — Optional reminder notifications at user-configured intervals
(e.g. every 2 hours between 8am-10pm) to log water; disabled by default
until user opts in during or after onboarding (avoid notification fatigue
from day one).

---

## Medicine Schedule (FR-M)

**FR-M-01** — User creates a medicine with: name, optional dosage note
(free text, e.g. "500mg"), optional stock count, optional low-stock
threshold, and one or more schedules (D-02).

**FR-M-02** — **Overlapping schedules.** A medicine may have multiple
schedules active over overlapping date ranges (D-02). Each schedule
independently defines: frequency pattern, times of day, start date,
optional end date. The daily view flattens all active schedules for a
medicine into one deduplicated list of dose instances; if two schedules
would generate a dose at the same time on the same day, only one dose
instance is shown (most-recently-created schedule wins) and this
collision is surfaced to the user at schedule-creation time as a warning,
not silently.

**FR-M-03** — Supported frequency patterns: fixed times daily (e.g.
8am/8pm), every N days (including "every other day," anchored to
`startDate` per D-03), specific weekdays (e.g. Mon/Wed/Fri), and as-needed
(PRN, no scheduled notifications, manual log only).

**FR-M-04** — **Stock tracking.** If stock count is enabled, each dose
marked "Done" decrements stock by the dose's configured consumption amount
(default 1 unit). When stock reaches the low-stock threshold, a persistent
in-app indicator and one notification fire (not repeated daily — one
notification per threshold crossing).

**FR-M-05** — **End date vs. stock exhaustion (D-04).** A schedule ends
when its explicit end date is reached, or immediately if the user manually
stops it. Reaching zero stock does NOT end the schedule unless the
per-medicine `stopWhenStockDepleted` toggle is enabled (default off); by
default, zero stock only shows an out-of-stock banner and blocks marking
new doses "Done" (user can still log "Taken from other source" to keep
the schedule running without stock deduction).

**FR-M-06** — **Missed-dose definition (D-05).** A dose is "upcoming" before
its scheduled time, "due" from scheduled time through `scheduledTime +
graceWindow` (default 30 min, editable per medicine 0-180 min), and
"missed" after the grace window elapses without being marked Done/Skipped,
until end of day. Missed doses are visually distinct and counted separately
in adherence stats from "skipped" (explicitly dismissed) doses.

**FR-M-07** — Each scheduled dose supports three notification actions
inline (no app open required): **Done** (marks taken, decrements stock),
**Snooze** (re-notifies after a configurable delay, default 10 min, max 3
snoozes per dose before it's forced to due/missed state), **Skip**
(marks explicitly skipped, does not decrement stock, does not count as
missed).

**FR-M-08** — Adherence stats per medicine: % doses taken on time (within
grace window) vs. late vs. missed vs. skipped, over 7/30/all-time windows.

**FR-M-09** — User can edit a medicine's schedule at any time; edits apply
to future dose instances only, never rewrite past dose history.

**FR-M-10** — User can archive (soft-delete) a medicine; archived
medicines stop generating doses/notifications but retain history for
stats; can be restored.

---

## Prayer Tracking (FR-P)

**FR-P-01** — **Calculation method (D-06).** User selects a prayer time
calculation method from a standard list (MWL, ISNA, Egyptian, Umm al-Qura,
Karachi, Tehran, Dubai, Kuwait, Qatar, Singapore). Default is chosen by
device locale/region at first launch, changeable any time in Settings;
changing it recalculates all future prayer times immediately, does not
alter historical checklist records.

**FR-P-02** — **Asr juristic method (D-06).** Independent setting: Standard
(Shafi'i/Maliki/Hanbali) or Hanafi. Default determined by locale
(Hanafi for Bangladesh/South Asia locales, Standard otherwise).

**FR-P-03** — **Jumu'ah setting (D-07).** Boolean `observesJumuah` setting,
default off. When enabled, Friday's Dhuhr checklist entry is labeled
"Jumu'ah," uses the same computed Dhuhr time window, and contributes to
the same Dhuhr streak/Qadha bucket. When disabled, Friday behaves exactly
like any other day (labeled Dhuhr).

**FR-P-04** — **Qadha starting balance (D-08).** During onboarding (or
later from Settings), user may optionally enter a starting Qadha count per
prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) to represent missed prayers before
using the app. Defaults to 0 for all five if skipped.

**FR-P-05** — **Ongoing Qadha accounting (D-08).** A prayer not marked
"Prayed" by its cutoff (the start of the next prayer's window; for Isha,
a configurable day-rollover time, default midnight local) auto-increments
that prayer's Qadha counter by 1 and marks that day's checklist entry as
"Missed" (not "Qadha" — Qadha is the running balance, not a per-day label).
A dedicated Qadha screen lists all five counters with a "−1" (mark one
made up) control per prayer; counters cannot go below 0. Qadha counters
are excluded from streak calculations.

**FR-P-06** — **Travel / timezone change (D-09).** Prayer times recompute
automatically from device location + timezone on app foreground and on a
background refresh at local midnight. If location permission is denied,
user sets a fixed city/coordinates manually in Settings; a persistent
Settings banner indicates "using manual location" so the user is never
unknowingly relying on a stale location.

**FR-P-07** — Daily checklist shows all five prayers plus (conditionally)
Jumu'ah, with current status per prayer (Upcoming / Current window / Prayed
/ Missed) and one-tap "Prayed" marking.

**FR-P-08** — Scheduled notification at each prayer's start time (and
optionally an adjustable pre-prayer reminder, e.g. 10 min before), with
Done (mark Prayed) / Snooze / Skip actions inline, same interaction model
as FR-M-07.

**FR-P-09** — Streak = consecutive calendar days where all five
obligatory prayers (or four + Jumu'ah per FR-P-03 on Fridays) are marked
Prayed before their respective cutoffs. Missing one prayer breaks the
streak for that day.

**FR-P-10** — Stats view: current streak, longest streak, per-prayer
on-time percentage (7/30/all-time), and current Qadha balance summary.

---

## Common / Cross-Module (FR-C)

**FR-C-01** — App functions fully with zero network connectivity at all
times; no feature may block, spinner-wait, or degrade due to absent
connectivity.

**FR-C-02** — First-launch flow: language selection (English/Bangla) →
optional short onboarding (module opt-in: user picks which of the three
modules to set up now, can add the others later from a "modules" screen) →
dashboard. Skipping onboarding entirely lands on an empty dashboard with
a clear "add a module" CTA, never a broken/blank screen.

**FR-C-03** — Dashboard aggregates today's status across all enabled
modules (water progress, next/overdue medicine dose, next/current prayer)
in one glanceable screen; disabled modules are simply absent, not shown
as greyed-out placeholders.

**FR-C-04** — Optional PIN lock (4-digit, app-level, not OS biometric-only)
to open the app; if enabled, required after a configurable timeout
(immediately / 1 min / 5 min / 30 min since backgrounded). Forgotten-PIN
recovery is a full app data reset (documented explicitly to the user before
enabling PIN, since there is no account/cloud recovery path).

**FR-C-05** — Theme setting: System / Light / Dark, Material 3, applied
app-wide including all three modules consistently.

**FR-C-06** — Language setting changeable any time from Settings (not just
first launch), takes effect immediately without app restart.

**FR-C-07** — All notification actions (Done/Snooze/Skip, any module) work
correctly when tapped from the notification shade with the app fully
closed (not just backgrounded), including after a device reboot.

**FR-C-08** — Notifications survive device reboot: all pending scheduled
notifications (medicine doses, prayer times) are re-registered via a boot
receiver without requiring the user to open the app first.

**FR-C-09** — Deep links from notification taps open directly to the
relevant record (e.g. tapping a medicine notification opens that dose's
detail, not just the app home) — see `navigation-map.md` for route targets.

**FR-C-10** — A module (Water/Medicine/Prayer, and any future module) can
be fully disabled/hidden from the dashboard and navigation without deleting
its underlying data, and re-enabled later with data intact.

**FR-C-11** — Dashboard shows, in addition to each enabled module's
existing summary tile (FR-C-03): an overall day-completion indicator
(complete modules / enabled modules, evaluated for today), an upcoming-
items strip (next dose, next prayer, water pace — one entry per module
that has something upcoming), and a quick-actions row (one-tap actions
each enabled module chooses to expose, e.g. Water's quick-add). A module
with nothing upcoming or no quick action contributes nothing to that
strip/row, not an empty placeholder.

**FR-C-12** — Reports screen aggregates every enabled module's daily data
into weekly/monthly/yearly views, with period navigation (previous/next)
and empty states for periods before a module's earliest recorded data
(not a zero-filled chart).

**FR-C-13** — An achievement engine evaluates module-contributed
achievement definitions (first log, 7/30/100-day streaks, perfect week,
etc.) after relevant writes; progress and unlock state persist in the
`achievements` table (`database-design.md`). A badge gallery screen shows
locked (progress) and unlocked (with unlock date) badges. Unlocking shows
a subtle, non-blocking moment (e.g. a snackbar on the screen that
triggered it) — never an intrusive modal popup.

**FR-C-14** — Reports surfaces each module's longest-streak record
alongside its current streak.

**FR-C-15** — A cross-module search (accessible from the dashboard) finds
named user-entered data across modules (e.g. medicine names/dosage notes)
and deep-links to the matching record. A module with no free-text-
searchable data (e.g. Water, Prayer) simply contributes no results, not
an error or empty-but-present section.

**FR-C-16** — A global calendar (month view) merges every enabled
module's per-day status into one combined coloring per day (all modules
complete / some incomplete / all missed / no data), with day drill-down
to see the per-module breakdown for that day.
