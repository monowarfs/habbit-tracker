# Non-Functional Requirements

Concrete, testable targets. Where a target depends on a reference device
class, that class is specified rather than left vague.

## Reference device classes

- **Low-mid Android:** 4GB RAM, e.g. Samsung Galaxy A14 / Xiaomi Redmi 12
  class hardware, Android 12+.
- **iOS baseline:** iPhone SE (2nd/3rd gen) or newer, current-minus-2 iOS
  version.

## Performance

- **NFR-01 Cold start:** App reaches interactive dashboard in < 2.0s on the
  low-mid Android reference device (measured via `flutter drive` timeline
  or manual stopwatch across 10 runs, median reported), < 1.5s on iOS
  baseline.
- **NFR-02 List scroll performance:** All scrollable lists (medicine dose
  history, water log history, prayer history) sustain 60fps (no dropped
  frames > 16.7ms per Flutter DevTools frame timeline) with up to 5,000
  rows, using lazy/paginated list widgets — never loading a full table into
  memory for display.
- **NFR-03 Interaction latency:** Any tap-to-visual-feedback (button press,
  checkbox toggle, quick-add) responds within 100ms; any action that writes
  to the local database completes and reflects in UI within 300ms on the
  reference device.

## Data & storage

- **NFR-04 Max DB size behavior:** App remains fully responsive (NFR-01/02
  targets hold) with up to 5 years of daily data across all three modules
  at maximum realistic logging frequency (~50MB-100MB estimated database
  size). Beyond that, the app must degrade gracefully (pagination, not a
  crash or unbounded memory growth) — no hard ceiling that blocks logging.
- **NFR-05 Data durability:** No data loss on force-quit mid-write, OS
  update, or app update, verified via the D-04-adjacent test: populate →
  kill process mid-transaction → relaunch → verify. Database writes use
  transactions; the app never leaves a record in a partially-written
  state.
- **NFR-06 Storage footprint:** Installed app size < 50MB on both
  platforms (excludes user data growth, which is covered by NFR-04).

## Notifications

- **NFR-07 Delivery reliability:** ≥ 95% of scheduled notifications
  (medicine, prayer) fire within 60 seconds of scheduled time, tested
  across a device matrix covering: stock Android (Pixel), Samsung
  (OneUI), Xiaomi (MIUI), OnePlus (OxygenOS), and iOS — the five
  environments with materially different background-execution/battery
  management behavior.
- **NFR-08 Doze/App Standby survival:** Scheduled notifications continue
  firing on schedule after the device has been idle (screen off, no
  charging) long enough to enter Doze mode (verified via `adb shell dumpsys
  deviceidle force-idle` or equivalent), using exact-alarm APIs, not
  inexact/best-effort scheduling.
- **NFR-09 Reboot survival:** 100% of pending notifications re-registered
  within 60 seconds of device boot completing, without requiring the user
  to open the app.
- **NFR-10 Action reliability:** Done/Snooze/Skip notification actions
  execute their intended state change even when the app process is not
  running, with no more than 1% observed failure rate in manual test
  matrix.

## Accessibility

- **NFR-11 Screen reader support:** All interactive elements have
  meaningful labels for TalkBack (Android) and VoiceOver (iOS); core
  flows (log water, mark dose done, mark prayer done, view stats)
  fully operable with a screen reader enabled, verified by manual pass,
  not just automated scanning.
- **NFR-12 Touch targets:** Minimum 48x48dp (Android) / 44x44pt (iOS) for
  all tappable elements, verified via layout inspection, no exceptions for
  "small" icon buttons.
- **NFR-13 Text scaling:** UI remains usable (no clipped/overlapping text,
  no broken layout) up to 200% system font scale, verified on both
  reference device classes.
- **NFR-14 Color contrast:** All text meets WCAG AA contrast ratios (4.5:1
  normal text, 3:1 large text) in both light and dark theme.

## Localization

- **NFR-15** Zero hard-coded user-facing strings; enforced by a lint check
  (custom `flutter analyze` rule or a CI grep-based check) before merge.
- **NFR-16** Bangla numerals (০-৯) render for numeric displays where the
  Bangla locale is active and numeral substitution is locale-appropriate
  (dates, counts, stats) — using `intl`'s locale-aware number formatting,
  not manual string replacement.

## Reliability / stability

- **NFR-17 Crash-free rate:** ≥ 99.5% crash-free sessions post-launch,
  measured via store console crash reporting (opt-in on-device, no
  third-party network SDK required to hit this NFR since it's measurable
  from store consoles alone).

## Battery

- **NFR-18** Background refresh work (prayer time recompute, notification
  scheduling) consumes no more than "low" battery usage classification in
  both Android's Battery Settings and iOS's Battery screen over a 24h test
  period — verified manually, not simulated.
