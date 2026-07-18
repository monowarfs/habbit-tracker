# Notification Manual Test Matrix — Run 08

Manual verification results for the notification/reminder engine
(`../strategies/notifications.md`), run against the Android emulator
(`sdk gphone16k arm64`, API 36) on 2026-07-18. iOS was not exercised this
run (no iOS device/simulator available in this environment) — its
permission/scheduling code paths share the same `NotificationService`
methods, gated by `Platform.isIOS`, but are unverified until a future pass
with an iOS simulator/device.

## What was verified live

| Scenario | Result | Evidence |
|---|---|---|
| Android 13+ `POST_NOTIFICATIONS` pre-permission explainer → OS prompt → grant | ✅ Works | Screenshots: explainer dialog shown, then the real OS "Allow habit_tracker to send you notifications?" dialog; tapping Allow granted the permission (`dumpsys package` shows `POST_NOTIFICATIONS: granted=true`). |
| Android notification channel creation | ✅ Works | `dumpsys notification` shows `NotificationChannel{mId='water_reminders', ...}` created for `dev.shurjomoy.habit_tracker` after toggling the reminder switch on. |
| Scheduling window materialization (multi-day, `AndroidScheduleMode.exactAllowWhileIdle`) | ✅ Works | `dumpsys alarm` shows real `RTC_WAKEUP` alarms registered by `ScheduledNotificationReceiver` at every 2-hour reminder slot (14:00, 16:00, 18:00, 20:00, 22:00, 00:00, 02:00...) spanning into the next day — confirms the planner's 3-day window and the app-resume re-planning trigger both ran correctly against the real plugin. |
| Reboot persistence (FR-C-08) | ✅ Works | `adb reboot`, waited for `sys.boot_completed=1`. Logcat shows `ActivityManager: Start proc ... for broadcast {dev.shurjomoy.habit_tracker/com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver}` firing automatically (no app launch needed). `dumpsys alarm` afterward shows the exact same set of alarms re-registered — confirms the manifest-only reboot-recovery approach the strategy doc specifies, with no custom Dart reboot-handling code. |
| Manifest permissions/receivers present and granted | ✅ Works | `dumpsys package` confirms `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` declared and (where applicable) granted; `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver`/`ActionBroadcastReceiver` all present in the receiver resolver table. |

## What was not exercised this run (honest gaps)

- **Live notification fire + Done/Snooze/Skip action tap**, in each of foreground/
  background/killed-app states. The scheduled alarms are real wall-clock times
  (hours away); this emulator image doesn't allow `adb shell date` (non-root
  production build) and there was no time budget to wait out a real 2-hour
  interval. The background isolate action handler
  (`core/notifications/notification_action_handler.dart`) is covered instead by
  the unit tests below, which exercise the same ledger/planner/module-dispatch
  logic without the plugin's native scheduling layer.
- **Device reboot then an actual notification firing from a restored alarm** —
  reboot persistence itself was verified (alarms reappear), but not chained
  through to an actual fire, for the same wall-clock-wait reason above.
- **iOS permission flow, `BGTaskScheduler` behavior, action categories.**
- **OEM battery-killer behavior** (MIUI/Realme UI/FuntouchOS) — this emulator
  runs stock Android; `notification_reliability_screen.dart` is deliberately a
  stub pending Run 12's full device-brand guidance, per this run's own scope.
- **Time-change handling** (`strategies/notifications.md`'s "time-change
  handling" DoD item) — `flutter_local_notifications`' `zonedSchedule` is
  documented as DST-safe via the `timezone` package, and the app's own
  `localDayKey`/`local_day.dart` DST tests already cover the date-bucketing
  half; the OS-alarm half is the plugin's own responsibility and wasn't
  separately re-verified here.

## Automated coverage (compensates for the gaps above)

- `test/core/notifications/notification_planner_test.dart` — window
  clipping, the iOS 64-notification cap (schedule vs. cancel decisions),
  idempotent re-scheduling.
- `test/core/notifications/notification_ledger_repository_test.dart` —
  scheduled → fired/actioned ledger transitions, snooze-count increment
  without marking terminal, soft-delete/cancel.
- `test/features/water/water_module_test.dart` — 3-day reminder-slot
  projection, `onNotificationAction` dispatch (Done logs an entry via the
  quick-add default amount; Snooze/Skip never mutate Water data, per the
  strategy doc's "streak effect: none" rule).
