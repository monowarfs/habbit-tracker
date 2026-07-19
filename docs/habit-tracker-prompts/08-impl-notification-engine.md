# 08 — IMPLEMENTATION: NOTIFICATION & REMINDER ENGINE

**Inputs:** `00-project-context.md`, `docs/strategies/notifications.md`,
`docs/technical/architecture.md`
**Highest-risk run. State plan first; implement exactly per the strategy doc —
any deviation forced by platform reality goes into `decisions.md`.**

## Scope

Build the shared engine in `core/notifications/`; modules feed it via the
contract. Wire the Water module's reminders as the first consumer.

1. flutter_local_notifications setup: channels (per-module channel with
   proper importance), Android 13+ POST_NOTIFICATIONS runtime permission flow
   with a friendly pre-permission explainer screen, iOS permission flow,
   exact-alarm permission handling per the strategy doc
2. **Planner**: materializes upcoming reminder instances within the rolling
   window (N days per strategy doc), respecting the iOS pending limit;
   re-planning triggers: app launch, reminder settings change, notification
   fired/acted (and the Android reboot receiver)
3. **Ledger**: every scheduled/fired/acted notification recorded in
   `notification_ledger` — this powers "missed" detection and debugging
4. **Actions**: Done / Snooze / Skip buttons; background isolate handler
   writes to the DB safely (this is where the multi-isolate DB capability
   from the database decision gets proven — if it fails here, escalate,
   don't hack). Snooze semantics exactly per strategy doc.
5. Deep links: tapping a notification routes to the correct screen via
   GoRouter (water tab for water reminders)
6. Reboot persistence on Android; verify iOS behavior and document limits
7. Water reminders end-to-end: user sets times in Water settings →
   notifications fire → Done logs a configurable default amount → ledger
   updated
8. In-app "notification troubleshooting" screen stub (OEM battery-killer
   guidance per strategy doc; full content in run 12)

## Definition of Done
- Manual matrix (document results in `docs/testing/notification-matrix.md`):
  fire while app foreground / background / killed; action buttons from shade
  with app killed; device reboot then fire; time-change handling
- Unit tests: planner window math, snooze rescheduling, ledger transitions
- Analyze clean, tests pass
- Commit: `feat(notifications): reminder engine with actions and ledger`
