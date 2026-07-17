# Git Strategy

## Trunk-based, not GitFlow

**Three long-lived branches already exist**, set up before this
documentation run: `dev` (default, active development, direct pushes
allowed, force-push/deletion blocked), `staging` (PR-required, no direct
push, pre-release verification), `main` (PR-required, no direct push,
what's actually shippable/tagged). Feature work happens on short-lived
branches off `dev` (`feat/water-module`, `fix/prayer-timezone-bug`),
merged back via PR (small fixes may push directly to `dev` given its
lighter protection, but a PR is preferred by default even solo, since it's
the one place a reviewable diff and CI run exist before something lands).

**GitFlow is explicitly rejected for this project.** GitFlow's `develop`/
`release/*`/`hotfix/*` branch ceremony exists to coordinate multiple teams
shipping multiple parallel release trains against the same codebase —
solving the problem of "team A needs to keep working on the next release
while team B patches the current one, without either blocking the other."
**This project has no parallel-release-train problem to solve:** one
developer, one app, shipping to two stores from one version at a time.
Adopting GitFlow's extra branch types and merge-back ceremony here would
be pure process overhead — time spent maintaining branch conventions that
exist to solve a coordination problem this project structurally doesn't
have. The three-branch setup already in place gives everything actually
needed: `dev` for daily integration, `staging` for pre-release
verification, `main` for what's shipped — with none of GitFlow's
additional bookkeeping.

## Conventional commits

Already the convention in use (`feat:`, `fix:`, `docs:`, `chore:` prefixes,
as seen in this project's own commit history). Continue it for every
commit, including implementation-run commits per `phases-and-dod.md`'s
Definition of Done (each run ends in exactly one conventional commit).

## Feature branch naming

`<type>/<short-description>`, matching the conventional-commit type that
will land it: `feat/water-module`, `fix/prayer-timezone-bug`,
`docs/run-05-engineering-standards`. Kept short-lived — a feature branch
exists for the duration of one implementation run (`phases-and-dod.md`),
not as a long-running parallel line of development.

## Tags per milestone

One tag per `../product/roadmap.md` v0.x milestone, applied to the `main`
commit once that milestone's work has been promoted through
`dev → staging → main`: `v0.1-scaffold`, `v0.2-water`, `v0.3-medicine-
domain`, `v0.4-medicine`, `v0.5-prayer-domain`, `v0.6-prayer`,
`v0.7-dashboard-pin`, `v0.8-rc`, and `v1.0.0` at actual store release —
matching the milestone table in `roadmap.md` exactly, so a tag always
answers "what was true in the codebase when this milestone was declared
done" without needing to cross-reference a separate changelog.

## Promotion flow

```
feat/* branch → PR → dev (lighter protection: direct push also allowed)
                        │
                        ▼  (periodic, once a milestone's work is stable)
                     PR → staging (PR required, no direct push)
                        │
                        ▼  (once verified against staging)
                     PR → main (PR required, no direct push) → tag
```

`dev`'s lighter protection exists specifically so day-to-day solo work
isn't slowed by a self-approval formality; `staging`/`main`'s stricter
protection exists so nothing reaches "shippable" or "shipped" without at
least a PR diff review pass — even reviewing your own diff in PR form
before merging catches things a direct push doesn't.
