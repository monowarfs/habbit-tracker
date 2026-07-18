# Accessibility

Targets already set as testable NFRs in
`../technical/non-functional-requirements.md` (NFR-11 through NFR-14) —
this document specifies how they're met concretely, screen by screen.

## Semantics labels

Every interactive element gets an explicit `Semantics`/`semanticLabel`
(via the standard Flutter widget properties — `Tooltip`, `IconButton`'s
`tooltip`, or an explicit `Semantics` wrapper where a custom widget has no
built-in slot for one), not left to whatever text happens to be visually
present. Icon-only controls (quick-add water buttons, dose action icons)
are the specific pattern that needs this most — a screen-reader user gets
nothing useful from an unlabeled icon.

**One thing this app gets "for free":** the notification action buttons
(Done/Snooze/Skip, `../strategies/notifications.md`) are rendered by the
OS's own notification shade UI, not a custom Flutter overlay — TalkBack
and VoiceOver already know how to announce native system notification
actions correctly. No additional accessibility work is needed for that
specific surface; it only matters for the in-app equivalent controls (the
dose/prayer detail screen's own Done/Snooze/Skip buttons).

## Touch targets ≥ 48dp / 44pt

Enforced as a fixed minimum size on every tappable widget
(`IconButton`'s default is already 48dp on Material, but custom tap
targets — quick-add preset buttons, dose-list row action icons, the Qadha
screen's per-prayer "−1" control — are explicitly sized, not left to
shrink to their icon's natural size). Verified by layout inspection during
Run 14's polish pass (`../product/roadmap.md`), no exceptions carved out
for "it looks cleaner smaller."

## Text scaling to 200% — the three densest screens, named

Every screen must reflow without clipping or overlap at 200% system text
scale (NFR-13), but three screens are the real test of that, by density:

1. **Dashboard** — aggregates all three modules' summary tiles in one
   screen (FR-C-03); at 200% scale, each tile's text must wrap/grow
   without pushing another module's tile off-screen or truncating its
   content silently.
2. **Medicine home screen** — the flattened cross-schedule dose list
   (FR-M-02's most complex UI surface): each row carries a medicine name,
   dosage note, scheduled time, status label, and (when expanded) three
   action buttons — the row with the most simultaneous text elements in
   the app.
3. **A stats screen** (Water/Medicine/Prayer stats, `../product/
   navigation-map.md`) — combines a calendar/bar chart with numeric
   labels (percentages, streak counts) at the highest information density
   in the app; charts are also the UI element most likely to silently
   overflow or become illegible rather than throw a visible layout error,
   so this needs an explicit manual check, not just an automated overflow
   assertion.

## Color contrast, both themes

WCAG AA (4.5:1 normal text, 3:1 large text, NFR-14) checked against both
the light and dark `ColorScheme`s generated in `theme.md`, including the
per-module accent colors and the custom `success` semantic color — a
custom `ThemeExtension` color is exactly the kind of addition that can
silently fail a contrast check if not verified explicitly alongside the
standard M3 roles (which Flutter's own seed-generation algorithm already
tunes for AA compliance).

## Screen-reader flow: logging a dose (TalkBack/VoiceOver)

The concrete flow, walked end to end, per FR-M-07/`../product/
navigation-map.md`:

1. On the Medicine home screen, each dose row announces as one semantic
   unit: *"Lisinopril, 10mg, 8:00 AM, due now"* — not four separate,
   disconnected announcements for name/dosage/time/status.
2. Activating the row (double-tap in TalkBack/VoiceOver's touch-explore
   gesture) navigates to Dose Detail (`/medicine/dose/:id`) and the screen
   reader immediately announces the screen's heading (medicine name) plus
   the current status.
3. Three actions are reachable by swipe-navigation, each with an
   unambiguous label: *"Done, button"*, *"Snooze, button"*, *"Skip,
   button"* — never just an icon with no label, and never a single merged
   "actions" region a screen-reader user would have to explore blindly.
4. Activating "Done" triggers an immediate spoken confirmation ("Marked as
   taken") **and** a visual confirmation — never audio-only or
   visual-only, so the same action is confirmed correctly whether or not
   a screen reader is active.
5. Navigating back to the Medicine home screen, the just-updated row's
   re-announcement reflects the new status ("...8:00 AM, taken") —
   verifying the screen-reader experience updates reactively
   (`../technical/state-management.md`'s stream-provider pattern) the same
   way the visual UI does, not left stale until a manual refresh.
