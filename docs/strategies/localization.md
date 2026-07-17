# Localization

## ARB workflow

- Source of truth: `lib/core/l10n/app_en.arb` (template, drives key
  extraction) and `app_bn.arb`, generated into typed `AppLocalizations`
  classes via Flutter's built-in `gen_l10n` (configured in `l10n.yaml`, not
  a third-party codegen package — this is a stdlib-first choice: Flutter's
  own localization tooling covers everything this app needs, so no
  `easy_localization`/`intl_utils`-style dependency is added for what the
  SDK already does).
- Every ARB entry carries a `@key` metadata block with a `description` —
  required, not optional, since a translator working from `app_bn.arb`
  alone needs context a bare key like `doneLabel` doesn't provide.
- No string is ever hard-coded in a widget — enforced by NFR-15's lint
  check (a CI grep for string literals inside `Text(...)` calls not routed
  through `AppLocalizations.of(context)`).

## Pluralization in Bangla

ARB pluralization uses standard ICU `{count, plural, ...}` MessageFormat
syntax, the same mechanism for every locale — this app has very few
plural-sensitive strings to begin with (mostly "N day streak," "N doses
missed," "N prayers remaining"), so the plural-form burden is small
regardless of locale. **Bengali's CLDR plural category set should be
confirmed against `package:intl`'s generated plural-rules table at
implementation time** rather than asserted here from memory — pluralization
rules are locale data that changes with CLDR updates, and this is a
documentation-only run with no code to run `intl`'s rule table against.
What's certain and actionable now: every ARB plural entry must supply
whichever categories the target locale's CLDR rule actually defines (for
many South Asian languages including Bengali, `one` and `other` are the
only two categories in use, with `zero`/`two`/`few`/`many` not applicable —
but confirm this per-string at implementation time rather than assuming
every plural string only ever needs two branches).

## Bangla digit rendering policy

**Rule: any numeral shown to the user must be produced by `package:intl`'s
locale-aware formatters (`NumberFormat`, `DateFormat`), never by
interpolating a raw `int`/`double` directly into a `Text` widget.**
`NumberFormat`/`DateFormat` constructed with the `bn` locale render digits
in the Bangla numbering system (০১২৩৪৫৬৭৮৯) automatically; a bare
`'$count'` string interpolation does not, and is the specific bug this
rule prevents (NFR-16). This applies uniformly to: water ml/fl oz amounts,
streak counts, stats percentages, Qadha counters, and all date/time
displays. The one deliberate exception: raw numeric **input** (a text
field where the user types a goal in ml) still accepts Western Arabic
digits from the device keyboard — converting input digits is unnecessary
complexity for a value the user is actively typing, not reading.

## Date/number formatting

All via `package:intl`'s `DateFormat`/`NumberFormat`, constructed with the
app's active locale (from `app_settings.locale`, not the device locale,
since FR-C-06 makes language an explicit in-app setting independent of OS
language) — never manual date-string building (`"$day/$month/$year"`),
which is both a locale-correctness bug magnet and exactly the kind of
hand-rolled logic the stdlib-first principle rules out.

## Pseudo-locale testing

Flutter has no built-in pseudo-locale mechanism (unlike Android's native
`en-XA`/`ar-XB`). Practical substitute for this app: a small **build-time
script** generates `app_qps-ploc.arb` (borrowing Android's pseudo-locale
naming convention for familiarity) from `app_en.arb` by wrapping every
string in brackets and padding length (`"Save"` → `"[Śàvéé!!]"`) — this
catches two classes of bug before real Bangla translations exist: (1) any
hard-coded string that skips the ARB pipeline entirely (it won't get
wrapped, and will stand out immediately against the bracketed pseudo-text
around it), and (2) layout overflow from a translation that's longer than
its English source (Bangla script commonly runs 20-35% longer than
English for the same meaning). This pseudo-locale is added to
`supportedLocales` only in debug/profile builds, never shipped.

## Adding a new language — checklist

1. Create `app_<locale>.arb` with every key from `app_en.arb` translated
   (a CI check diffs keys between the template and every other ARB file to
   catch missing entries before merge).
2. Run `flutter gen-l10n` (or let `build_runner`/the IDE trigger it) to
   regenerate typed accessors.
3. Add the locale to `supportedLocales` in the root `MaterialApp`/
   `CupertinoApp` config.
4. Add the locale to the in-app language picker's option list
   (`/onboarding/language`, `/settings/language`).
5. If the new locale has a natural regional default for Prayer's
   calculation method/Asr juristic setting (D-06 established this pattern
   for `bn`/Bangladesh → Karachi/Hanafi), add that locale-to-default
   mapping — otherwise it falls back to the global default (MWL/Standard).
6. Confirm the target locale's CLDR plural category set against `intl`'s
   rule table and adjust any plural ARB entries missing a required
   category.
7. Confirm font coverage for the locale's script (see below) — pick a
   Noto-family fallback if the current font choice doesn't cover the new
   script.
8. If the new locale is RTL (Arabic, Urdu, Farsi are realistic future
   candidates given the app's Islamic-practice user base) — Flutter's
   `Directionality` follows locale automatically, but this still needs a
   manual QA pass on every screen, since RTL bugs (icon mirroring, padding
   direction, text alignment) are visual and don't show up in automated
   tests.
9. Manual QA pass at 200% text scale (NFR-13) for the new locale
   specifically, since translated string length varies per language.

## Font choice for Bangla — verified via Google Fonts' live catalog (2026-07-17)

Confirmed available Bengali-script families in the current Google Fonts
catalog (checked against `fonts.google.com`'s own metadata endpoint, not
memory): **Noto Sans Bengali, Noto Serif Bengali, Hind Siliguri, Anek
Bangla, Tiro Bangla.**

**Recommendation: Noto Sans Bengali** for UI body text, paired with Noto
Sans (or the platform default — Roboto/San Francisco) for Latin text. The
Noto family is specifically designed for consistent metrics (x-height,
weight, spacing) across scripts, which is what keeps English and Bangla
text feeling like the same typeface family rather than two visually
mismatched fonts sitting next to each other in the same UI (e.g. a
bilingual settings screen, or a Bangla numeral next to an English label).

**Delivery mechanism — bundled assets, not runtime HTTP fetch.** Verified
directly from the `google_fonts` package's own docs (v8.2.0, checked
2026-07-17): *"Font bundling in assets. Matching font files found in
assets are prioritized over HTTP fetching. Useful for offline-first apps."*
This is not optional for this app — `google_fonts`' default behavior is to
fetch font files over the network on first use, which would silently
violate FR-C-01 (100% offline, no feature may block on connectivity) for
any user who opens a Bangla-locale screen before ever having network
access. **Policy: Noto Sans Bengali's font files are bundled as local
assets in `pubspec.yaml` from day one** — `google_fonts`' asset-priority
behavior then means the font simply loads locally, and the same API
(`GoogleFonts.notoSansBengali()`) is used in code either way, so this is a
build-configuration decision, not a code-path branch.
