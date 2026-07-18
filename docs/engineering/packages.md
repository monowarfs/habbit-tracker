# Packages

Every dependency this project's documentation has committed to, verified
live against pub.dev on **2026-07-17** (version, last-publish date, and a
maintenance-health read) — not stated from memory, per this run's explicit
rule. Where an earlier document already made the comparison in depth
(Isar/Drift, `adhan`/`adhan_dart`), this document doesn't repeat the
reasoning, it points back and records the resolved dependency.

## Data layer

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `drift` | 2.34.2 (2026-07-14) | SQL database (D-11) | Chosen over `isar`/`isar_community`/`objectbox` — full comparison in `../technical/database-decision.md` | `is:flutter-favorite`, 160/160, ~1M downloads/30d — healthiest dependency in the whole stack |
| `sqlite3` | 3.4.0 (2026-07-12) | Native SQLite bindings Drift runs on | **Correction to an earlier open flag:** the older `sqlite3_flutter_libs` package (previously used to bundle native SQLite binaries) is now explicitly marked by its own maintainer *"not used anymore, update to version 3.x of `sqlite3` instead"* — v3.x bundles native libraries itself via Dart's build-hooks mechanism, no separate libs package needed at all | Same `simonbinder.eu` publisher as Drift, 150/160, 1.67M downloads/30d, released 5 days before this check |
| `drift_dev` | 2.34.0, pinned — **correction from Run 06 implementation**: `drift_dev >=2.34.1+1` requires `analyzer ^13.0.0`, which conflicts with `riverpod_generator`'s `analyzer ^12.0.0`; `2.34.0` is the newest `drift_dev` still on the `analyzer ^12` line both codegen tools can share (2026-07-14 originally recorded, now superseded) | Code generation for Drift tables/DAOs (dev dependency) | Required companion to `drift`, no alternative | Tracks `drift`'s own release cadence exactly |
| `path_provider` | 2.1.6 (2026-06-15) | Locates the app's on-disk documents/support directories for the SQLite file and rotating log file — **added during Run 06 implementation**, not recorded in this doc's original pass | Official `flutter.dev`-maintained plugin, no alternative needed | Active |
| `path` | 1.9.1 (2024-10-28) | Joining/normalizing file-system paths for the DB file and log files — **added during Run 06 implementation** | Official `dart.dev` path-manipulation package | Small, stable API; infrequent releases reflect a settled surface, not neglect |

## State management / routing

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `flutter_riverpod` | 3.3.2 (2026-06-10) | State management (`00-project-context.md`'s mandated stack) | No alternative considered — this is a fixed tech-stack requirement | Active, in step with `riverpod_generator`'s release |
| `riverpod_annotation` | 4.0.3 (2026-06-10) | `@riverpod` annotations for codegen | Companion to `flutter_riverpod` | Released same day as `flutter_riverpod` — good sign the ecosystem is versioned together deliberately |
| `riverpod_generator` | 4.0.4 (2026-06-10) | Generates provider boilerplate from `@riverpod` (dev dependency) | Per `00-project-context.md`'s explicit "Riverpod (code-gen with riverpod_generator)" requirement | Same release day as the two above |
| `riverpod_lint` + `custom_lint` | 3.1.4 (2026-06-10) / 0.8.1 (2025-09-09) | Riverpod-specific lint rules (e.g. catching a provider watched but never disposed correctly) | `custom_lint` is the required host framework `riverpod_lint` plugs into | `custom_lint` is older (10 months) but stable — it's an infrastructure package with a narrow, rarely-changing job (hosting analyzer plugins), not a sign of neglect |
| `go_router` | 17.3.0 (2026-06-02) | Routing (`00-project-context.md`'s mandated stack), including the `/lock` redirect guard (`../product/navigation-map.md`) | No alternative considered — fixed tech-stack requirement | Active |

## Domain modeling

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `freezed` + `freezed_annotation` | `3.2.6-dev.1` (pinned exact, not `^`), 3.1.0 (2025-07-02) — **correction from Run 06 implementation**: stable `freezed` (3.2.5) caps `analyzer <11`, incompatible with `drift_dev`/`riverpod_generator`'s `analyzer ^12`; `3.2.6-dev.1` is the only currently-published version that relaxes the analyzer cap enough to coexist with both codegen tools. Revisit and un-pin once a stable `freezed` ships against analyzer 12+ | Immutable domain models, sealed unions (`RepeatRule`, `AppException`, `Result`) | Fixed tech-stack requirement; no viable alternative gives Dart 3 sealed-class-style unions with this little boilerplate | Both actively maintained; `freezed_annotation`'s slightly older date is normal for an annotations-only companion package (annotations change far less often than the generator itself) |
| `json_serializable` + `json_annotation` | 6.14.0 / 4.12.0 (both 2026-05-15) | JSON (de)serialization for the export/import envelope (`../strategies/backup-import-export.md`) | Pairs with Freezed's `@JsonSerializable` mixin — the standard combination, no alternative needed | Released same day, actively maintained |
| `uuid` | 4.6.0 (2026-07-15) | UUID v7 generation for every table's primary key (D-12) | Verified it supports RFC 9562 v7 directly (`Uuid().v7()`) — confirmed from the package's own pub.dev description, not assumed | 160/160, 9.39M downloads/30d, released 2 days before this check — the single most-downloaded package in this entire dependency list |
| `build_runner` | 2.15.2 (2026-07-13) | Runs Freezed/json_serializable/Drift/Riverpod codegen (dev dependency) | Required by all four codegen packages above | Released the day before this check |

## Notifications & prayer times

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `flutter_local_notifications` | 22.0.1 (2026-06-14) | Scheduled local notifications, full detail in `../strategies/notifications.md` | Fixed tech-stack requirement; also simply the dominant, most-capable package for this job | `is:flutter-favorite`, 150/160, 2.35M downloads/30d |
| `adhan_dart` | 2.0.1 (2026-05-11) | Offline prayer time calculation | Chosen over the stale original `adhan` package (last released 2023-09-24) — full reasoning in `../strategies/prayer-times.md` | Active, MIT, topics `prayer-times`/`islamic`/`adhan`/`salah` |
| `geolocator` | 14.0.3 (2026-06-12) | One-shot GPS location for Prayer (`prayer-times.md`) | Dominant, most-capable location package for Flutter | `is:flutter-favorite`, 160/160, 1.97M downloads/30d |
| `timezone` | 0.11.1 (2026-06-29) | IANA timezone database, used for manual lat/long → tz resolution and by `flutter_local_notifications`' `zonedSchedule` | Standard companion to `flutter_local_notifications` for exact scheduling across DST | Active |
| `flutter_timezone` | 5.1.0 (2026-05-28) | Reads the device's current OS timezone setting (no network) | Needed alongside `timezone`'s static tz database — one gives the data, the other gives "which one is the device's" | Active |
| `workmanager` | 0.9.0+3 (2025-08-31) | Android-only periodic top-up of the notification scheduling window (`notifications.md`) | Standard Flutter-community package for Android background tasks; **not used on iOS** — `notifications.md` documents why a reliable iOS equivalent doesn't exist | 140/160, 63,953 downloads/30d — slower release cadence (~11 months since last release) than most of this list, but `fluttercommunity.dev`-maintained and still the standard choice; **flag: re-check for a newer release or a maintained fork at Run 11 implementation time**, since this is the one package in this list closest to a staleness concern worth re-verifying rather than a hard alternative recommendation now |

## Security

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `flutter_secure_storage` | 10.3.1 (2026-05-27) | OS Keychain/Keystore-backed storage for the PIN hash/salt (D-15, `../strategies/security.md`) | Dominant package for this exact job on both platforms | 150/160, 3.23M downloads/30d |
| `pointycastle` | 4.0.0 (2025-02-19) | PBKDF2-HMAC-SHA256 for PIN hashing | Chosen over `dargon2_flutter` (Argon2), which is 3+ years stale — full reasoning in `security.md` | 140/160, but 2.68M downloads/30d — high adoption despite a lower like-count, consistent with being a widely-used transitive dependency across the ecosystem, not just a directly-chosen one |
| `local_auth` | 3.0.2 (2026-07-09) | Optional biometric convenience layer over PIN | Official `flutter.dev`-maintained package, no alternative needed | `flutter.dev` publisher, 160/160, 1.14M downloads/30d, released 8 days before this check |

## Presentation / UI

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `google_fonts` | 8.2.0 (2026-07-15) | Bangla-script fonts (Noto Sans Bengali), bundled as assets not fetched (`../strategies/localization.md`) | Official `flutter.dev`-maintained package, gives access to the full Google Fonts catalog including verified Bengali-script families | `is:flutter-favorite`, 160/160, 2.76M downloads/30d, released 2 days before this check |
| `flutter_svg` | 2.3.0 (2026-05-08) | The three module-identity icons (`../strategies/performance.md`) | Standard SVG-rendering package; used sparingly (3 icons), not as a general icon system — Material Symbols cover everything else | Active |
| `fl_chart` | 1.2.0 (2026-03-13) | Stats/calendar charts (`00-project-context.md`'s mandated stack) | Fixed tech-stack requirement | Active |
| `intl` | 0.20.2, pinned — **correction from Run 05 implementation**: the Flutter SDK's `flutter_localizations` package (needed for `GlobalMaterialLocalizations` etc.) depends on exactly `intl 0.20.2`; the 0.20.3 version this doc originally recorded doesn't resolve once `flutter_localizations` is added, since Flutter pins its own transitive `intl` version rather than accepting a range | Locale-aware date/number formatting, Bangla numerals (`localization.md`) | Fixed tech-stack requirement; the official Dart/Flutter internationalization package | Active |
| `flutter_localizations` | Flutter SDK (not versioned independently) | Provides `GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations`/`GlobalWidgetsLocalizations` delegates `gen_l10n`'s generated `AppLocalizations` needs — **added during Run 05 implementation**, not recorded in this doc's original pass since it's an SDK package, not a pub.dev one | `localization.md`'s ARB/`gen_l10n` workflow doesn't function without it | N/A — ships with the Flutter SDK itself |

## Diagnostics

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `logger` | 2.7.0 (2026-03-15) | Structured logging with redaction discipline (`../strategies/error-handling-logging.md`) | Fixed tech-stack requirement | 150/160, 2.49M downloads/30d |
| `share_plus` | 13.2.1 (2026-07-15) | User-initiated "share diagnostic logs" (`error-handling-logging.md`) | Standard, dominant share-sheet package for Flutter | Released 2 days before this check |

## Testing

| Package | Version (published) | Purpose | Why this / alternative | Maintenance note |
|---|---|---|---|---|
| `clock` | 1.1.2 (2024-10-28) | Injected-clock testing for all time-dependent domain logic (`../strategies/testing.md`) | Official `tools.dart.dev` package, purpose-built for exactly this problem — no reason to hand-roll a `Clock` interface | 6.4M downloads/30d (largely as a transitive dependency of the `test` package itself); the ~1.5-year-old release date reflects a small, stable API surface that doesn't need frequent churn, not neglect |
| `mocktail` | 1.0.5 (2026-04-10) | Fakes/mocks for use-case-level domain tests (faking a repository interface, not the real DB — repository tests themselves use a real temp/in-memory Drift database per `testing.md`, not mocks) | Chosen over `mockito` — `mocktail` needs no `build_runner` codegen step for mock classes, which keeps the codegen pipeline this project already runs (Freezed/Drift/Riverpod/json_serializable) from growing a fifth generator for a job a non-codegen library already does simply | 160/160, 2.77M downloads/30d |

## Lint (dev dependency — decision recorded here, full config in `coding-standards.md`)

| Package | Version (published) | Note |
|---|---|---|
| `very_good_analysis` | 10.3.0 (2026-06-18) | **Chosen** over `flutter_lints` — comparison and reasoning in `coding-standards.md` |
| `flutter_lints` | 6.0.0 (2025-05-27) | Considered, not chosen for this project (still transitively relevant — `very_good_analysis` builds on the same lint foundation) |
