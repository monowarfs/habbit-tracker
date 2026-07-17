# Navigation Map

GoRouter-based route inventory. Bottom nav tabs are the top-level shell
routes; everything else is pushed on top. Route params in `:param` form.

## Tab shell (bottom navigation)

Tabs shown are only those for enabled modules (FR-C-10) plus Dashboard and
Settings, which are always present.

| Tab | Route | Notes |
|---|---|---|
| Dashboard | `/dashboard` | Always present, default route after onboarding/lock. |
| Water | `/water` | Hidden from nav if module disabled; route still resolvable if data exists (re-enabling later). |
| Medicine | `/medicine` | Hidden from nav if module disabled. |
| Prayer | `/prayer` | Hidden from nav if module disabled. |
| Settings | `/settings` | Always present. |

## Onboarding (pushed, one-time flow, not reachable after completion except via Settings re-run)

| Screen | Route |
|---|---|
| Language select | `/onboarding/language` |
| Module select | `/onboarding/modules` |
| Water goal setup | `/onboarding/water-goal` |
| Medicine first-add prompt | `/onboarding/medicine-first` |
| Prayer settings (method/Asr) | `/onboarding/prayer-settings` |
| Prayer starting Qadha | `/onboarding/prayer-qadha` |
| Permission explainer | `/onboarding/permission/:type` (`type` = `notifications` \| `location`) |

## Water (pushed within `/water` tab)

| Screen | Route | Deep-link target? |
|---|---|---|
| Water home (today) | `/water` | No (tab root) |
| Add/edit entry | `/water/add` | No |
| Edit existing entry | `/water/entry/:id/edit` | No |
| Stats | `/water/stats` | No |
| Goal settings | `/water/settings` | No |

## Medicine (pushed within `/medicine` tab)

| Screen | Route | Deep-link target? |
|---|---|---|
| Medicine home (today's doses, all medicines) | `/medicine` | No (tab root) |
| Medicine list (manage) | `/medicine/list` | No |
| Medicine detail | `/medicine/:medicineId` | No |
| New medicine | `/medicine/new` | No |
| Edit medicine | `/medicine/:medicineId/edit` | No |
| New schedule for medicine | `/medicine/:medicineId/schedule/new` | No |
| Edit schedule | `/medicine/:medicineId/schedule/:scheduleId/edit` | No |
| **Dose detail (notification tap target)** | **`/medicine/dose/:doseId`** | **Yes — FR-C-09** |
| Adherence stats | `/medicine/:medicineId/stats` | No |

## Prayer (pushed within `/prayer` tab)

| Screen | Route | Deep-link target? |
|---|---|---|
| Prayer home (today's checklist) | `/prayer` | No (tab root) |
| **Prayer detail (notification tap target)** | **`/prayer/:prayerName/:date`** | **Yes — FR-C-09** (`prayerName` ∈ fajr/dhuhr/asr/maghrib/isha/jumuah, `date` = ISO date so a tap always opens the correct day even after midnight rollover) |
| Qadha screen | `/prayer/qadha` | No |
| Prayer settings (method/Asr/Jumu'ah toggle) | `/prayer/settings` | No |
| Prayer stats | `/prayer/stats` | No |

## Settings (pushed within `/settings` tab)

| Screen | Route |
|---|---|
| Settings home | `/settings` |
| Modules (enable/disable) | `/settings/modules` |
| Language | `/settings/language` |
| Theme | `/settings/theme` |
| PIN lock | `/settings/pin` |
| Set/change PIN | `/settings/pin/set` |
| Notification preferences | `/settings/notifications` |
| About / version | `/settings/about` |

## Lock (top-level, intercepts all routes)

| Screen | Route |
|---|---|
| PIN entry | `/lock` |
| Forgot PIN / reset explainer | `/lock/reset` |

`/lock` is a redirect guard at the GoRouter root level (`redirect:` callback),
not a normal pushed route — it intercepts navigation to any route when the
PIN timeout has elapsed, and releases back to the originally requested route
on success, matching the PIN unlock flow in `app-flow.md`.

## Deep-link summary (notification taps, FR-C-09)

| Notification type | Deep-link route |
|---|---|
| Medicine dose | `/medicine/dose/:doseId` |
| Prayer | `/prayer/:prayerName/:date` |
| Low-stock alert | `/medicine/:medicineId` |
| Water reminder (if enabled) | `/water` |

All deep links pass through the `/lock` guard first if PIN lock is active —
a notification tap never bypasses the lock screen.
