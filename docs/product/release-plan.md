# Release Plan — v1.0

See `roadmap.md` for the internal v0.x milestone sequence leading here.

## v1.0 store release contents

Exactly: Water, Medicine, Prayer modules, common shell (dashboard, PIN
lock, theme, en/bn localization), full offline operation, reliable
notifications with reboot/Doze survival. Nothing from the PRD Non-Goals
list ships — no cloud sync, no backup, no family profiles, no fourth
module.

## Platforms

Android (Play Store) and iOS (App Store), simultaneous launch. Minimum OS
versions to be confirmed against the technical blueprint (run 02); this
document assumes recent-enough versions to support
`flutter_local_notifications` exact-alarm scheduling and boot receivers
without workarounds.

## Store submission checklist

- **Privacy policy** (required even for a fully offline app — both stores
  require one; must explicitly state: no account, no data leaves the
  device, no analytics SDK, list the on-device permissions requested and
  why).
- **Data-safety form (Google Play) / App Privacy details (App Store):**
  answer "no data collected," "no data shared with third parties," since
  the app has no network calls; still must declare the permissions used
  (notifications, location [optional, Prayer only], boot-completed
  receiver [Android, for notification rescheduling]).
- **iOS permission usage strings** (`Info.plist`):
  - `NSLocationWhenInUseUsageDescription` — explain it's used only to
    calculate accurate prayer times locally, never transmitted.
  - Notification permission uses the standard system prompt (no custom
    Info.plist string required, but the in-app explainer screen per
    `app-flow.md` step 5 precedes it).
- **Android manifest declarations:** `RECEIVE_BOOT_COMPLETED`,
  `SCHEDULE_EXACT_ALARM` (or equivalent per current Android target SDK
  policy at build time — verify against the Android version current when
  Run 11 is implemented, since exact-alarm permission requirements have
  changed across Android releases), `POST_NOTIFICATIONS` (Android 13+).
- **Store listing assets:** screenshots for both languages (en/bn),
  short/long description, feature graphic; no mention of features not in
  v1.0 scope (avoid describing sync/backup/family profiles as "coming
  soon" unless actually committed).
- **Age rating / content rating questionnaire:** answer accurately for a
  health/lifestyle utility app with no user-generated content, no ads
  (v1.0), no in-app purchases (v1.0).
- **Support contact:** an email or form must be listed on both store
  listings even without a backend — required by both stores regardless
  of app complexity.

## Rollout

- Phased rollout on Google Play (e.g. 20% → 50% → 100% over the first
  week) to catch any device-specific notification-delivery regression
  (NFR-07/08) before full exposure, given how OEM-dependent that risk is.
- iOS has no phased-rollout mechanism at the same granularity; mitigate
  by ensuring the Run 13 device test matrix explicitly includes iOS
  before submission, since there's no post-launch staged fallback.

## Success gate before wider marketing push

Do not invest in any user-acquisition effort until the `prd.md` Success
Criteria table (crash-free rate, notification delivery reliability) shows
stable numbers from real store console data over at least 2 weeks
post-launch — avoids scaling acquisition against an app that's still
shaking out reliability issues.
