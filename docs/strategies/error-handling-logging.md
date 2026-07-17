# Error Handling & Logging

## Failure taxonomy

A sealed `AppException` (Freezed union, `domain/` layer, zero Flutter
imports per `architecture.md`'s dependency rule):

```dart
sealed class AppException implements Exception {
  const factory AppException.validation(String field, String message) = ValidationException;
  const factory AppException.notFound(String entity, String id) = NotFoundException;
  const factory AppException.storage(String operation, Object cause) = StorageException;
  const factory AppException.permission(String permission) = PermissionException;
  const factory AppException.unexpected(Object cause, StackTrace trace) = UnexpectedException;
}
```

Repositories and use cases return a small hand-rolled `Result<T>`
(`Success(T value)` / `Failure(AppException error)`, itself a Freezed
union) rather than throwing arbitrary exceptions across the
domain/presentation boundary. **Not a third-party functional-programming
package** (`fpdart`/`dartz` and similar `Either` implementations) —
Freezed already generates the exhaustive-`switch`-friendly sealed class
this needs, so a two-variant `Result` is a same-file, ~10-line addition,
not a dependency: adding a whole FP-style library for one sum type would
be exactly the kind of unrequested abstraction `00-project-context.md`
rules out.

## What users see vs. what gets logged

| `AppException` variant | User sees (localized, via ARB) | Logged |
|---|---|---|
| `validation` | The specific field-level message (e.g. "Goal must be between 250 and 10,000 ml") | `warning` level — this is expected user-input feedback, not a bug |
| `notFound` | A generic "that item no longer exists" message, screen navigates back | `warning` level |
| `storage` | A generic "couldn't save, please try again" message — never the raw DB error string | `error` level, full cause + stack trace |
| `permission` | The specific permission-explainer screen relevant to what was denied (location, notifications, exact alarms) | `info` level (not a failure, an expected user choice) |
| `unexpected` | A generic "something went wrong" message with a "share diagnostic logs" action (below) | `error` level, full cause + stack trace |

The user-facing message is always a fixed, localized string mapped from
the exception **variant**, never the raw exception's `.toString()` or
message — this is what prevents a raw DB/plugin error string (which could
itself contain table/column names or other internal detail) from ever
reaching the UI.

## Logger setup and redaction rules

Package: `logger` (verified active on pub.dev 2026-07-17: v2.7.0, published
2026-03-15, 150/160 pub points, 2.49M downloads/30 days).

**The rule, stated once, applied everywhere, at every log level — not just
"info":** log calls may reference an entity's **type and stable ID only**
(e.g. `"failed to update medicine_dose id=<uuid>"`), never its **content**
(medicine name, dosage note, prayer type, Qadha count, water amount).
Health/practice data is exactly what a support-shared log file could leak
if this rule were only enforced at "info" and above — since a debug-level
log a developer adds during troubleshooting is just as capable of leaking
a medicine name via a domain object's Freezed-generated `toString()`, this
document treats the redaction rule as **unconditional across all log
levels**, stricter than the letter of "never log ... at info level" this
run's brief specified, because the weaker version doesn't actually protect
the thing it's meant to protect once a debug build's logs are shared.
**Concretely enforced by convention:** call sites build an explicit,
pre-sanitized string; passing a raw domain object directly to a log call
(`logger.d(medicine)`) is the specific pattern this rule forbids, since
Freezed's generated `toString()` would include every field.

**Level policy:** release builds set the logger's minimum level to
`Level.warning` (verbose/debug output never ships); this is a build
configuration, not a per-call-site decision, so it can't be forgotten at
one call site while remembered at another.

## In-app "share logs" for support

A rotating on-disk log file (capped at ~1MB, oldest entries dropped) fed
by a custom `LogOutput` for the `logger` package above. Reachable from
Settings ("Share diagnostic logs") and shared via `share_plus` (verified
active: v13.2.1, published 2026-07-15, 2 days before this document) through
the OS share sheet — email to support, a messaging app, etc. **This is
strictly user-initiated, per-incident, and opt-in** — the log file never
leaves the device on its own; it only leaves when the user explicitly taps
"share" and picks a destination, which is the concrete difference between
this feature and the automatic background telemetry this app's offline/
no-analytics promise rules out (see `analytics-future.md`).

## No crash reporting SaaS in v1 — the trade-off, stated

Firebase Crashlytics, Sentry, and similar vendor SDKs would give proactive,
aggregated visibility into production crashes — directly useful for
`../product/prd.md`'s crash-free-rate success criterion (NFR-17 in
`../technical/non-functional-requirements.md` — cross-referenced there as
NFR-17 in this project's numbering). **Not included in v1.0** because every
one of these SDKs phones home automatically over the network, which
conflicts directly with FR-C-01 (100% offline, no feature may depend on
connectivity) and this app's explicit privacy positioning — the caregiver
persona (`personas.md`'s Farida) specifically distrusts cloud-integrated
health-adjacent apps after a prior privacy scare, and a background
crash-telemetry SDK is exactly the kind of always-on network dependency
that would undermine that trust even if the crash data itself were
anonymous.

**How the trade-off is actually threaded:** `prd.md`'s crash-free-rate
success criterion is measured via each **store's own built-in** crash
reporting (Google Play Console / App Store Connect) — this is a
platform-level facility, not a third-party SDK the app integrates or a
network call the app makes; it's the OS/store layer observing crashes the
way it already does for every app on the platform, not an addition to this
app's own network footprint. This gives real production crash visibility
without adding a vendor SDK or a background network dependency to the app
itself.
