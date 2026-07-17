# Notifications

Highest-risk subsystem in the app — this document is intentionally the most
detailed of the twelve. Package: `flutter_local_notifications`, verified
live on pub.dev 2026-07-17: **v22.0.1**, published 2026-06-14, `is:flutter-
favorite`, 150/160 pub points, 7,327 likes, 2.35M downloads/30 days. This is
the healthiest possible dependency to build the app's single highest-risk
feature on.

## Verified platform limits and requirements (from the package's own README, not memory)

**iOS — 64 pending notification hard limit.** Confirmed directly from the
package README: *"There is a limit imposed by iOS where it will only keep
the 64 notifications that were last set on any iOS versions newer than 9.
On iOS versions 9 and older, the 64 notifications that fire soonest are
kept."* This is a hard OS ceiling, not a plugin limitation the plugin can
work around — it caps the **total** number of pending notifications across
every module combined, not per-type. This single fact drives the scheduling
window strategy below.

**Android 13+ (API 33) — `POST_NOTIFICATIONS` runtime permission.** Since
plugin v16+, the package only auto-declares the bare minimum
(`POST_NOTIFICATIONS`, `VIBRATE`) in its own manifest; the app must request
this permission at runtime before the first notification is shown (this
belongs in the FR-C-02 onboarding permission-explainer step, alongside the
location explainer for Prayer).

**Exact alarms (Android 14+ behavioral changes).** Two mutually exclusive
options, per the README:
- `SCHEDULE_EXACT_ALARM` + call `requestExactAlarmsPermission()` — user is
  prompted, can be granted/revoked like any runtime permission. **Chosen
  approach** — it's the one that gives the user visible control and doesn't
  invite store-review friction.
- `USE_EXACT_ALARM` — no user prompt, but requires targeting API 33+ and,
  per the README, "could be subject to approval and auditing by the app
  store(s)." Rejected: an unreviewed blanket exact-alarm grant is a bigger
  store-approval risk than a one-time permission prompt, for a feature
  (medicine/prayer reminders) where asking the user directly is expected
  and unsurprising.

**Doze survival — `AndroidScheduleMode.exactAllowWhileIdle`.** Per the
README, this schedule mode is what makes a notification fire at its exact
time even while the device is in Doze/idle. It requires the exact-alarm
permission above to be currently granted — if revoked, the README states
the plugin logs an error and does not schedule (recurring notifications are
silently not (re-)scheduled either). **App-level handling:** before
scheduling, check permission status; if not granted, fall back to
`AndroidScheduleMode.inexactAllowWhileIdle` and surface a persistent
Settings banner ("exact reminders are off — tap to enable") rather than
silently degrading reminder precision with no user-visible signal.

## Scheduling window strategy — two separate windows, not one

**Window 1 — data materialization (D-13, `database-design.md`):** 30 days
of `medicine_doses`/`prayer_records` rows, generated ahead for UI/stats
purposes (calendars, "upcoming" lists, adherence calculations). This window
is unconstrained by the iOS 64-limit because these are just DB rows, not
OS-registered notifications yet.

**Window 2 — OS-registered notifications:** a much smaller sliding window,
**N = 3 days**, of the rows from Window 1 that actually get handed to
`flutter_local_notifications` as scheduled OS notifications at any given
moment.

**Why N = 3, worked from the actual limit:** the 64-notification ceiling is
shared across every module. A realistic worst-case daily volume for one
user: 6 prayer slots (5 + Jumu'ah on Fridays), up to ~7 water reminders if
enabled at the densest interval setting, and — for a caregiver persona
(Farida) managing several medicines with multiple daily doses — plausibly
10-12 medicine notifications/day. That's roughly 20-25 notifications/day in
a genuinely dense but realistic configuration. `64 / 25 ≈ 2.5` days of full
headroom; **N = 3** is picked as the largest window that still leaves
margin below the hard ceiling for that worst case, while being generous
enough that a lighter, single-module user (e.g. Nusrat, water-only) never
notices the window at all. Android has no equivalent hard cap, but using
the same N on both platforms keeps one code path instead of a
platform-branching scheduler, which is the right trade for a limit that
only actually binds on iOS.

**Re-planning triggers (when Window 2 is recomputed and topped up):**
1. **App foreground/resume** — always. Cheapest, most reliable trigger on
   both platforms; the single trigger this design can actually depend on
   for iOS, since iOS background execution is not reliably schedulable (see
   below).
2. **Immediately after a notification fires or is actioned** (Done/Snooze/
   Skip) — a "conveyor belt": the slot that just resolved is replaced by
   scheduling the next not-yet-scheduled instance at the far edge of the
   window, keeping exactly N days registered at all times without waiting
   for the next app-open. Implemented from the same background-isolate
   handler that processes the action (see below).
3. **Android-only periodic top-up via WorkManager** (`workmanager` package,
   v0.9.0+3, verified active on pub.dev, fluttercommunity.dev publisher) —
   roughly every 6-12 hours, re-tops the window for users who don't open
   the app often. **This trigger does not exist on iOS** — `BGTaskScheduler`
   is opportunistic (the OS decides if/when it runs, no delivery
   guarantee), so it is not treated as a reliable mechanism here. This is a
   deliberate, documented platform asymmetry, not an oversight: an iOS user
   who doesn't open the app for more than ~3 days will see their reminder
   window run dry until they next open it. This is an accepted limitation
   of iOS's execution model industry-wide, not something a plugin
   workaround can fix, which is also why NFR-07 targets 95% delivery, not
   100%.

## Reboot handling

`flutter_local_notifications` ships its own boot-recovery mechanism —
verified from the README: declaring `RECEIVE_BOOT_COMPLETED` plus the
package's `ScheduledNotificationBootReceiver` (with `BOOT_COMPLETED`,
`MY_PACKAGE_REPLACED`, and `QUICKBOOT_POWERON` intent filters, for OEM
variants like HTC's quickboot broadcast) in `AndroidManifest.xml` is
sufficient for the plugin to automatically re-register whatever was still
pending at last shutdown. **This means FR-C-08 is largely a manifest
configuration task, not custom Dart reboot-handling code.** The one
app-level safety net still needed: because the plugin can only restore what
it already knew about, a device that stayed off longer than Window 2's
span needs the normal app-foreground top-up (trigger 1 above) to run once
the app is next opened — this is the same trigger already firing on every
open, not additional reboot-specific logic.

## Action buttons — Done / Snooze / Skip

Flow: notification action tap → **background isolate handler**
(`onDidReceiveBackgroundNotificationResponse`, a top-level/static function,
per the plugin's requirement that this callback be usable without the main
isolate running) → write via a Drift `NativeDatabase.createInBackground`
connection (`database-decision.md`) → update the source row
(`medicine_doses.status` / `prayer_records.status`) and
`notification_ledger.action`/`action_at` → conveyor-belt re-plan (trigger 2
above).

**Snooze, defined precisely (FR-M-07/FR-P-08):**
- Duration: 10 minutes default, not user-configurable in v1 (a fixed,
  simple default; per-notification snooze-duration configuration is
  explicitly not a requirement in `functional-requirements.md` and would be
  unrequested scope).
- Mechanism: reschedules a **new OS notification instance** at `now + 10min`
  referencing the **same** `medicine_doses`/`prayer_records` row (no new row
  is created) and increments `notification_ledger.snooze_count` on that same
  ledger entry.
- Limit: after the 3rd snooze, the Snooze action is omitted from the next
  notification (Done/Skip only) — enforced by checking `snooze_count` in the
  handler before building the next notification's action set.
- **Streak effect: none, directly.** Snoozing itself never marks a dose/
  prayer missed or breaks a streak — it only defers the decision. However,
  snoozing does **not** extend the grace window (D-05/FR-M-06): if a snooze
  fires past the grace window's end, the instance can still transition to
  "missed" through the normal state machine the next time it's evaluated,
  exactly as if the user had simply not responded at all. This is
  intentional — snooze is a UI convenience for "give me a nudge again
  shortly," not a mechanism for extending how late a dose can be taken and
  still count as on-time.

## Doze / App Standby / OEM battery killers — mitigation and honest limits

Stock Android Doze is handled by `exactAllowWhileIdle` (above). **OEM skins
common on devices in Bangladesh — Xiaomi (MIUI), Realme (Realme UI), Vivo
(FuntouchOS/OriginOS) — impose additional, undocumented, non-standard
restrictions** beyond stock Android: aggressive background-process killing,
"autostart" permission allowlists that silently block `BOOT_COMPLETED`
receivers for apps not on the list, and battery-optimization behavior that
can suppress `AlarmManager` deliveries even with exact-alarm permission
granted. This is a well-known, widely documented class of problem (tracked
by the community reference project dontkillmyapp.com) — **no Flutter
plugin, and no app-level code, can fully guarantee delivery against it,**
because the restriction lives in OEM firmware the app has no visibility
into.

**Mitigations shipped:**
1. Request battery-optimization exemption via the
   `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intent, with an explanatory
   screen shown first (Play Store policy scrutinizes blanket use of this
   permission, but a medicine/prayer reminder app is a legitimate,
   expected use case, and asking directly rather than requesting silently
   is what keeps this defensible on review).
2. An in-app **"Notification Reliability" guidance screen** (reachable from
   Settings, and surfaced once during Medicine/Prayer module setup) with
   device-brand-specific instructions (autostart toggle location, battery
   optimization exclusion steps) sourced from the same community reference
   above.
3. **Honest limit, stated plainly in that screen and here:** on some OEM
   configurations, even with every mitigation applied and every permission
   granted, delivery is still not 100% guaranteed. This is exactly why
   `non-functional-requirements.md` NFR-07 targets ≥95% delivery reliability
   across a device test matrix that specifically includes these OEMs,
   rather than promising 100%.

## Deep links from notification tap

Handled via the precomputed `deep_link_route` column on
`notification_ledger` (`database-design.md`) — set once, at scheduling
time, so the tap handler never needs a DB read just to know where to
navigate. `onDidReceiveNotificationResponse`'s payload carries this route
string; GoRouter navigates to it, passing through the `/lock` PIN guard
first if enabled (FR-C-09, full route table in `../product/navigation-
map.md`).
