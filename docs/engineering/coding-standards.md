# Coding Standards

## Lint baseline: `very_good_analysis`, not bare `flutter_lints`

**Comparison** (versions verified in `packages.md`): `flutter_lints` (6.0.0,
the official Flutter-team baseline, stable but comparatively permissive)
vs. `very_good_analysis` (10.3.0, actively released a month before this
document, built on top of the same foundation but meaningfully stricter —
notably `public_member_api_docs`, which requires a doc comment on every
public class/member, and a set of stricter style/safety rules like
`avoid_print` and preferring `const` aggressively).

**Recommendation: `very_good_analysis`.** This project's own stated bar
(`00-project-context.md`: "production-quality... SOLID... doc-comment
expectations on public APIs" per this run's own brief) is exactly what
`very_good_analysis`'s `public_member_api_docs` rule enforces at the tooling
level rather than leaving to reviewer discipline — for a solo developer
with no second reviewer, a lint rule that can't be forgotten is worth more
than a stricter ruleset most teams would find punishing to onboard onto.

## `analysis_options.yaml`

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/core/l10n/**"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    public_member_api_docs: true
```

**Generated files are excluded from analysis, not just from doc-comment
requirements** — `*.g.dart`/`*.freezed.dart` are machine-written, holding
them to hand-written-code lint rules would produce noise the project has
no ability to fix (the generator, not the developer, controls that code's
shape). `lib/core/l10n/**` (the generated `AppLocalizations` classes) is
excluded for the same reason.

## Immutability rules

Every domain and data-layer model is a `@freezed` class — no mutable
fields, no setters, no `late` fields used as a workaround for delayed
initialization of what should just be a constructor parameter. Drift's own
generated row classes are already immutable value types, so this rule is
consistent top to bottom: nothing in `domain/` or `data/` is ever mutated
in place, a "change" is always a new value replacing the old one (a new
row inserted into `water_goals`, a new `Result` returned from a use case).

## No business logic in widgets beyond composition

A `build()` method may contain layout/composition and simple presentational
branching (`color: isDone ? theme.success : theme.outline`), never a
calculation an FR describes (grace-window missed-status logic, streak
counting, Qadha cutoff evaluation). This is not a rule a lint config can
mechanically enforce — no static analyzer can distinguish "simple
presentational ternary" from "business logic that happens to be short" —
so it's enforced by the architecture itself (`../technical/architecture.md`'s
layer rule: a widget reads a provider's already-computed value, it never
recomputes anything the domain layer is responsible for) plus review
discipline at PR time.

## Provider naming

Full convention lives in `naming-conventions.md`; the principle stated
here: **a provider's name describes what it exposes, never how it's
implemented.** `todaysWaterEntriesProvider`, not
`waterLogsTableStreamProvider` — a caller shouldn't need to know the data
comes from a Drift stream vs. anything else to use the provider correctly.

## Error propagation conventions

Two different error representations exist at two different layers, on
purpose, not redundantly:

- **`domain/`/`data/` layers:** use cases and repositories return a
  hand-rolled `Result<T>` (`Success`/`Failure(AppException)`, per
  `../strategies/error-handling-logging.md`) — this layer has no Flutter/
  Riverpod dependency (`architecture.md`'s dependency rule), so it can't
  use Riverpod's own `AsyncValue`.
- **`presentation/` layer:** a Riverpod controller calls the use case,
  pattern-matches the returned `Result`, and translates it into Riverpod's
  own `AsyncValue` (`AsyncData`/`AsyncError`/`AsyncLoading`) for the
  widget tree to consume. This is not double-bookkeeping of the same
  concept — `Result<T>` is domain's Flutter-agnostic error channel;
  `AsyncValue` is presentation's own, and the controller is exactly the
  translation point between them, matching the layer boundary
  `architecture.md` already draws.

## Doc-comment expectations

`public_member_api_docs` (above) is enforced strictly for `domain/`
(entities, repository interfaces, use cases) and for shared `core/`
abstractions (`HabitModule`, `BackupTarget`, `AnalyticsService`) — this is
the layer a Laravel-background developer would recognize as needing real
docblocks, since these are the actual "API" other code depends on.
Presentation-layer screens/widgets are held to a lighter bar in practice
(a well-named `WaterHomeScreen` widget is self-explanatory and consumed
only within its own feature folder, never treated as a contract another
module depends on) — the lint rule still requires *a* doc comment there,
but it can be a one-liner restating the screen's purpose, not a full
docblock.

## Generated files: not committed

Decided in `../strategies/performance.md`'s "build_runner hygiene"
section — restated here for completeness: `*.g.dart`, `*.freezed.dart`,
and Drift's generated database code are `.gitignore`d, not committed.
They regenerate deterministically from source via `build_runner`, which
CI runs before every check (`cicd.md`) — committing them would create
merge-conflict noise on every model/schema change and a real risk of a
committed generated file silently drifting from its source.
