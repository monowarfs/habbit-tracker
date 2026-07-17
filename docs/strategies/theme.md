# Theme

Material 3, per `00-project-context.md`. This document covers the seed
color, light/dark/system switching, per-module accent colors (fed by the
`HabitModule` contract from `architecture.md`), and the Bangla typography
adjustment.

## Seed color and M3 ColorScheme generation

**Seed color: a teal (`#006874`-family).** Generated into a full
`ColorScheme` via Flutter's built-in `ColorScheme.fromSeed(seedColor: ...,
brightness: ...)` — this is the stdlib-first M3 mechanism (no manual
per-role color picking, no third-party Material theming package). Teal is
chosen over a more literal "water blue" as the *app-wide* seed specifically
so it reads as a neutral, health/calm brand color that doesn't visually
pre-empt Water's own module accent (see below) — the seed drives
`primary`/`surface`/`background` roles used everywhere (app bar, nav bar,
buttons), while each module's own identity color is a separate, smaller
accent layered on top, not the seed itself.

Two `ColorScheme`s are generated from the one seed —
`ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light)` and
`...brightness: Brightness.dark)` — bound to `ThemeData.colorScheme`
for `MaterialApp.theme`/`.darkTheme` respectively.

## Light / dark / system switching

`ThemeMode` (Flutter's own three-value enum: `system`, `light`, `dark`)
bound directly to `app_settings.theme_mode` (FR-C-05) via a `keepAlive`
Riverpod provider (`state-management.md`) — `MaterialApp.themeMode` reads
this provider, so changing the Settings toggle rebuilds the whole app's
theme immediately, with no restart, the same reactive pattern used
throughout `state-management.md`.

## Per-module accent colors

The M3 seed's `primary`/`secondary`/`tertiary` roles are reserved for
app-wide chrome (nav bar, primary buttons, FABs) — they are deliberately
**not** reused as the "this is the Water module" visual identity, because
several M3 roles already have a specific semantic job (e.g. `error` is red,
reserved for actual errors) and overloading them with per-module meaning
would make the same color mean two different things in different contexts.

Instead, each module carries its own **accent color** as a plain field on
`ModuleMetadata` (`architecture.md`'s `HabitModule.metadata`), used only for
that module's icon, dashboard tile border/highlight, and nav-bar selected
state — never for `ColorScheme` roles:

| Module | Accent | Reasoning |
|---|---|---|
| Water | Blue (`#1565C0`-family) | Universal, immediately legible association; distinct from the teal seed so the two don't visually merge |
| Medicine | Deep purple/violet (`#5E35B1`-family) | Deliberately not red (reserved for `error`) and not green (reserved for the app-wide "success/done" extension below) — needed a third distinct hue for a module whose UI shows a lot of Done/Missed states that already use red/green semantically |
| Prayer | Amber/gold (`#B8860B`-family) | Common visual association with Islamic-practice apps without leaning on green, which is reserved for the success/done semantic below — keeps a done Fajr checkmark (green) visually distinct from Prayer's own module-identity color (gold) |

## A custom semantic color, beyond the standard M3 roles

Material 3's `ColorScheme` has no built-in "success" role (only
`error`/`primary`/`secondary`/`tertiary` and their container/on- variants).
Since every module needs a consistent "this is done/on-time" visual
(green) that must read the same way in Water, Medicine, and Prayer alike —
and must stay visually distinct from any of the three per-module accents
above — this app defines one small `ThemeExtension<AppSemanticColors>`
(Flutter's own documented mechanism for adding app-specific color roles
alongside the standard `ColorScheme`, not a workaround): a single `success`
color (green), used uniformly for "Done"/"Prayed"/"on-time" states across
all three modules, resolved through `Theme.of(context).extension<AppSemanticColors>()`
the same way any other theme color is looked up.

## Typography scale and the Bangla line-height adjustment

Base scale: Flutter's standard M3 `TextTheme` roles
(`displayLarge`...`labelSmall`) — no custom scale invented, per the
stdlib-first principle; this app has no display need (marketing-style
hero text, editorial layouts) that the standard 15-role M3 scale doesn't
already cover.

**Bangla line-height:** Bangla (Bengali) script has taller ascenders/
descenders and vertically-stacking conjunct consonant clusters than Latin
script, and reads cramped at Latin-tuned line-heights. **Policy:** the
`TextTheme` used when the active locale is `bn` applies a line-height
multiplier (`height` property on each `TextStyle`) around 1.4-1.5× instead
of the ~1.2× default tuned for Latin — applied once, at the theme level
(a locale-aware `TextTheme` builder function), not per-widget, so no
individual screen needs locale-specific styling logic. This is layered on
top of `localization.md`'s Noto Sans Bengali font choice — Noto's own
metrics are designed for reasonable cross-script harmony, but the app-level
height multiplier is still the mechanism that prevents visually cramped
Bangla text, verified during the Run 13 accessibility/localization QA pass
(`../product/roadmap.md`) rather than asserted as a fixed number here
without a real device check.
