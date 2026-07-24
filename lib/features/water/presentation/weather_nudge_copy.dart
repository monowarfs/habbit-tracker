/// A short weather clause appended to Water's reminder body when
/// weather-aware copy is enabled and a fresh-enough cached reading
/// exists (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`). Plain, non-localized
/// template text — matches this module's own pre-existing notification
/// title/body convention (`'Time to drink water'`/`'Keep your water goal
/// on track.'` are likewise hardcoded English, not routed through
/// `gen_l10n`; the `weatherNudgeClauseHot` ARB key documents this exact
/// English wording for translators/future use but isn't itself called
/// from `pendingNotifications()`, which has no `BuildContext`/locale to
/// resolve against — a known, already-accepted gap this one clause
/// doesn't newly introduce).
String weatherNudgeClause(double temperatureCelsius) =>
    "It's ${temperatureCelsius.round()}°C today.";
