# Prayer Times

## Offline calculation library

**Recommendation: `adhan_dart`.** Verified live on pub.dev 2026-07-17:
**v2.0.1**, published 2026-05-11 (2 months before this document), MIT
license, tagged with topics `prayer-times`/`islamic`/`adhan`/`salah`,
150/160 pub points. It is a Dart port of the widely-used `adhan` algorithm
family (the same underlying published astronomical method implemented
across the batoulapps `Adhan` libraries for Swift/Kotlin/JS/etc.), fully
offline (pure computation from latitude/longitude/date/timezone, no network
call).

**Explicitly checked and rejected:** the plain `adhan` package (no suffix)
— last published **2023-09-24**, essentially 3 years stale versus
`adhan_dart`'s 2-month-old release. Same situation as `isar` vs.
`isar_community` in `database-decision.md` — the ecosystem has a clear
active successor and this document follows the live data, not the more
familiar/older package name.

**Calculation methods supported (must include, per D-06):** Muslim World
League (MWL), ISNA, Egyptian General Authority, Umm al-Qura (Makkah),
University of Islamic Sciences Karachi, plus the smaller regional presets
(Tehran, Dubai, Kuwait, Qatar, Singapore) already enumerated in
`../product/decisions.md` D-06 and `functional-requirements.md` FR-P-01.
`adhan_dart`'s method enum covers this standard set directly — no custom
astronomical implementation is required.

**Default for Bangladesh: Karachi method**, per D-06 — chosen because it is
the method whose calculated times most closely match what mosques in
Bangladesh/South Asia commonly announce, minimizing the "why is this app's
Asr time different from my mosque's" trust problem flagged as the top risk
in `../product/prd.md`.

**Asr juristic method (Madhab):** `adhan_dart` exposes Standard (Shafi'i/
Maliki/Hanbali shadow-length ratio) vs. Hanafi as a parameter to the same
calculation call — this is exactly D-06's `asr_method` setting
(`prayer_settings.asr_method`), not a separate library concern.

## Location without internet

No network geocoding dependency anywhere in this flow — every path below
resolves to raw coordinates + an IANA timezone id without a network call:

1. **Manual city list (primary, recommended default UX):** a small,
   bundled static dataset — `city name → {latitude, longitude, IANA
   timezone id}` — biased toward Bangladesh (divisional cities plus major
   districts) and a broader set of major world cities for travelers/other
   markets. Bundled as a JSON asset shipped in the app, not fetched. The
   user picks from this list during onboarding (`/onboarding/prayer-
   settings`) or Settings.
2. **Manual lat/long entry** for the (rare) user not in the bundled list —
   a plain two-field numeric entry, resolved to an IANA timezone via the
   `timezone` package's bundled tz database (v0.11.1, verified active,
   2026-06-29), not a network reverse-geocoding call.
3. **Optional one-shot GPS fix** via `geolocator` (v14.0.3, verified
   `is:flutter-favorite`, active, 2026-06-12) — returns raw
   latitude/longitude only, entirely on-device, no network round-trip.
   Device timezone (for converting calculated UTC prayer times to local
   display) comes from `flutter_timezone` (v5.1.0, verified active,
   2026-05-28), which reads the OS's own timezone setting — again no
   network call. **No reverse-geocoding to a place name is attempted**
   when using GPS — offline reverse-geocoding would require either a
   network API (violates the offline requirement) or bundling a large
   geo-boundary dataset for marginal cosmetic benefit (showing a city name
   instead of coordinates); the GPS path is for *accuracy*, not for
   *labeling*, so the location badge simply reads "Current location
   (GPS)" rather than resolving to a place name.

This three-tier design is exactly D-09/FR-P-06's manual-city fallback
requirement, with GPS layered on top as a convenience, never a dependency.

## Madhab, Hijri date, midnight/qiyam — scope boundary

- **Madhab (Asr method):** in scope, D-06, covered above.
- **Hijri date display:** **out of scope for v1.0.** Not present in any FR
  in `../product/functional-requirements.md`; adding it would be
  unrequested scope. If added later, it's a display-only concern (a Hijri
  calendar conversion, e.g. the Umm al-Qura algorithm) layered on top of
  the Gregorian `prayer_records.prayer_date` — no schema change required,
  since `prayer_date` is already a plain calendar-date value
  (`data-models.md`), and a Hijri label would be computed from it at
  render time.
- **Midnight/qiyam calculation:** **out of scope for v1.0**, per this run's
  explicit instruction — `adhan_dart` and the broader adhan algorithm
  family do support computing Islamic midnight and the last-third-of-night
  window (used for qiyam/tahajjud reminders), but nothing in
  `functional-requirements.md` asks for this, so it is not built, and the
  library capability existing is noted here only so a future run doesn't
  need to re-evaluate library support if this scope is ever requested.
