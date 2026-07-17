# App Flow

Text-based flow descriptions for the flows that matter most for v1.0. Screen
names match `navigation-map.md` route names.

---

## 1. First Launch

1. App opens directly to **Language Select** (`/onboarding/language`) — no
   splash-screen dead time beyond the platform-native launch icon.
2. User picks English or Bangla → entire app UI (including this flow's
   remaining screens) renders in that language from this point forward.
3. **Module Select** (`/onboarding/modules`): three toggles (Water /
   Medicine / Prayer), all off by default. User enables any subset,
   including none.
4. For each enabled module, in order Water → Medicine → Prayer, a short
   module-specific setup step runs:
   - Water: set daily goal (`/onboarding/water-goal`), suggested default
     shown, must confirm or edit.
   - Medicine: prompt to add first medicine now (`/onboarding/medicine-
     first`) or skip and add later from the module screen — never forces
     schedule creation during onboarding.
   - Prayer: confirm/adjust calculation method + Asr juristic method
     (locale-defaulted, `/onboarding/prayer-settings`), optionally enter
     starting Qadha balances (`/onboarding/prayer-qadha`, skippable).
5. If any module needing device permissions was enabled (Prayer →
   location; any module → notifications), the OS permission prompt fires
   with a preceding in-app explanation screen (never a bare OS prompt with
   no context).
6. Lands on **Dashboard** (`/dashboard`) showing only the enabled modules'
   summaries. If zero modules were enabled, Dashboard shows an empty state
   with an "Enable a module" CTA linking to `/settings/modules`.

## 2. Daily Logging — Water

1. From Dashboard or the Water tab (`/water`), user sees today's progress
   ring + quick-add buttons.
2. Tap a quick-add preset → entry logged instantly, no confirmation
   screen, progress ring animates to new total.
3. For a custom amount or backdated entry: tap "+" → **Add Entry**
   (`/water/add`) → enter amount, optionally change date/time (capped at
   now) → Save → returns to `/water` with updated total.
4. Tap Stats tab within Water (`/water/stats`) for streak + 30-day view.

## 3. Daily Logging — Medicine

1. From Dashboard or Medicine tab (`/medicine`), user sees a flattened
   list of today's doses across all medicines, ordered by time, each
   tagged Upcoming / Due / Missed / Done / Skipped.
2. Tap a dose row → **Dose Detail** (`/medicine/dose/:id`) → three actions:
   Done (decrements stock if tracked), Snooze, Skip.
3. Adding a new medicine: `/medicine/new` → name, dosage note, stock
   toggle (+ count, threshold, stop-when-depleted toggle) → add one or
   more schedules (`/medicine/:id/schedule/new`, repeatable) → Save.
4. Editing a medicine's schedule: `/medicine/:id/edit` → changes apply to
   future doses only (existing history untouched), matching FR-M-09.

## 4. Daily Logging — Prayer

1. From Dashboard or Prayer tab (`/prayer`), user sees today's five (or
   six, if Jumu'ah applies) prayer rows with current status.
2. Tap "Prayed" on the current/due prayer → marks done, updates streak
   state immediately.
3. Tap a prayer row for detail (`/prayer/:name`) shows calculated time,
   window, and Qadha-relevant history for that prayer type.
4. Qadha screen (`/prayer/qadha`) lists all five running counters with a
   "−1" control per prayer.

## 5. Notification Action Flow (app not open)

Applies identically to Medicine dose notifications and Prayer notifications
(shared interaction pattern, FR-M-07/FR-P-08):

1. Scheduled notification fires at (or within 60s of) the scheduled time,
   showing three inline actions: Done, Snooze, Skip — regardless of
   whether the app process is running.
2. **Done** tapped: action handler runs in background (no app UI opens),
   writes the state change (mark taken/prayed, decrement stock if
   applicable) directly to the local database, notification is dismissed,
   a brief system toast/confirmation may show per platform convention.
3. **Snooze** tapped: current notification dismissed, a new one is
   scheduled `snoozeDelay` (default 10 min) later; after 3 snoozes for the
   same dose/prayer instance, Snooze is no longer offered on the next
   firing (forces Done/Skip/let it become Missed).
4. **Skip** tapped: state written as explicitly skipped (distinct from
   auto-Missed), notification dismissed, no further snooze/re-notify for
   that instance.
5. If the user instead taps the notification body (not an action button),
   the app opens directly to the relevant detail screen (`/medicine/dose/
   :id` or `/prayer/:name`) per FR-C-09, not to the Dashboard.
6. After a device reboot, any notification still pending (not yet fired,
   or fired-but-unactioned within its due window) is re-registered by a
   boot receiver before the user needs to open the app (FR-C-08).

## 6. PIN Unlock Flow

1. If PIN lock is enabled and the re-lock timeout has elapsed since the
   app was last backgrounded, app launch/foreground shows **PIN Entry**
   (`/lock`) before any other content — no data is rendered behind it.
2. Correct PIN → proceeds to whatever screen the app would have opened
   otherwise (Dashboard on cold start, or the previously active screen on
   resume-from-background).
3. Incorrect PIN → shake/error feedback, no lockout counter in v1.0 (no
   account to lock — see PRD Non-Goals for what's deliberately not built).
4. "Forgot PIN" link on the lock screen leads to a confirmation screen
   explaining that recovery requires a full app data reset (uninstall/
   clear data), since there is no cloud account to verify identity against
   (matches FR-C-04's up-front warning at enable-time).
