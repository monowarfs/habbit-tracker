# Agent Workflow

Rules for AI-assisted implementation runs (05-14). This is meta relative to
the rest of `docs/` — it governs how those runs get *executed*, not what
they contain — but it's load-bearing: without it, "one run = one
well-scoped change" is just a filing convention, not something actually
enforced session to session.

## One run = one prompt file = one fresh session

Each implementation run is executed in its own fresh session, given
exactly: `00-project-context.md`, that run's own prompt file, and only the
input documents that run's own header lists — not the entire `docs/` tree.
This mirrors exactly how the documentation runs (01-04) have been executed
so far: run 01 was given `00` alone; run 02 was given `00` +
`docs/product/*`; run 03 was given `00` + `docs/technical/*` +
`docs/strategies/*`; each run's declared inputs are a deliberate, minimal
context — not "attach everything to be safe." A fresh session per run also
means no implementation run silently carries assumptions forward from a
previous run's conversation that aren't actually written down anywhere in
`docs/`; if it isn't in a doc, the next session can't see it, which is the
forcing function that keeps the documentation actually complete rather
than a partial record supplemented by tribal memory.

## The agent states its plan before writing code, and waits

Before creating or editing a single file, the agent posts: the exact file
list it intends to create/modify (matching `../technical/folder-
structure.md`'s conventions and `naming-conventions.md`'s rules), and the
test list it intends to write (matching `../strategies/testing.md`'s
pyramid and, where applicable, one of the ten named suites). **It waits
for explicit approval before proceeding.** This is the equivalent of a PR
description written *before* the PR — it catches a wrong plan while it's
still a five-line list, not after a session's worth of code has been
written against a misunderstanding.

## The agent never edits files outside its run's declared scope

A run's "scope out" section (`phases-and-dod.md`) is a hard boundary, not
a suggestion. Concretely: a Water-module run (06) does not touch
`lib/features/medicine/` or `lib/features/prayer/` (which shouldn't exist
yet at that point) or any other module's files; a later run doesn't
refactor an earlier module's code "while in the area" without that
refactor being the run's own declared scope. The one standing exception is
`../product/decisions.md` — any run may *append* a new decision entry to
it (never edit an existing one) when a genuine blueprint conflict is
discovered, per the rule below.

## On a blueprint conflict discovered mid-run: stop, report, propose

If, while implementing, an agent discovers that two documents disagree, or
that a documented decision turns out to be infeasible once actually built
(e.g. a package's actual API doesn't support what a doc assumed, or an FR
and the DB schema contradict each other) — **the agent stops immediately**,
reports the conflict plainly (what disagrees with what, and why it
matters), and **proposes a specific amendment** to append to
`decisions.md`, in the same D-## format every other entry uses. It does
**not** silently pick one side and improvise a resolution, and does not
silently deviate from the documented design while leaving the docs
unchanged — either of those would let the codebase and the documentation
quietly diverge, which defeats the entire point of having a blueprint an
agent-executed run can be checked against.

## Template for a new implementation-run prompt file

Every run 05-14 prompt file follows the same shape the documentation runs
already established:

```
# <NN> — <RUN NAME>

**Inputs:** 00-project-context.md, <exact list of docs/* files this run needs>
**Outputs:** <exact file/folder scope this run may touch>

## Scope
<what this run builds — cross-reference phases-and-dod.md's "scope in">

## Explicitly out of scope
<cross-reference phases-and-dod.md's "scope out">

## Definition of Done
<cross-reference the universal checklist in phases-and-dod.md, plus this
run's specific feature-demo checklist>
```

Keeping every run's prompt file this uniform is what makes
`phases-and-dod.md`'s per-run entries usable as a checklist rather than
prose to be re-read and re-interpreted each time.
