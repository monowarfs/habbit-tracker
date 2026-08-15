# Session Retrospective — Jul 27 → Aug 15, 2026

Analysis of all recorded Claude Code sessions on this project (claude-mem
history, ~90+ sessions, ~5,500 observations). Covers what got built, real
mistakes, and concrete rules to avoid repeating them.

## What happened (summary)

- **Jul 27–29**: Recovery session (247 `flutter analyze` errors at start —
  broken imports, stale codegen, missing l10n keys), then Flutter SDK
  upgrade, then Wave-1 roadmap review, prayer on-time/late feature (PR #69),
  seed-data generator.
- **Aug 3**: Virtual Companion, Avatar Customization, Sleep, Blood Pressure,
  Exercise, Mood modules — five feature modules in one day via 8-agent
  parallel code review per PR. Sleep module review found **5 critical
  premium-gate bypasses**. Exercise/Mood reviews each needed a second pass.
- **Aug 4–5**: 57-spec roadmap audit (tracking doc was out of sync with
  actual code), Weekly Quest Chains (PR #77, high-severity week-rollover
  bug + concurrency race found post-review), Weekly Boss Milestone (PR
  #78), Cross-Module XP/Level (PR #79).
- **Aug 6**: Point-shop, colorblind-safe streak heatmap — first run of two
  specs in parallel worktrees, hit a working-tree collision. README/roadmap
  doc updates. Four separate flutter-test-hang incidents, each resolved by
  killing stuck processes and falling back to `analyze` + manual review.
- **Aug 7**: Family/Multi-Profile (PR #90) — 28 tables threaded with
  `profileId`; review caught **UPDATE statements missing the profileId
  filter** (cross-profile data leakage) in Medicine's repository. Household
  Leaderboard (PR #91). Then 7 accessibility/analytics specs run in
  parallel — this took **~15 session restarts** (S567→S584) across ~4
  hours from repeated context overflow.
- **Aug 7 (cleanup)**: Discovered `git worktree remove` doesn't delete the
  branch it was on — orphaned `worktree-agent-*` branches had to be swept
  twice.

Net: the project moved fast (dozens of modules/features shipped in under
three weeks) using a heavy parallel-agent + PR + multi-angle-review
pipeline. The pipeline caught almost everything — but only *after* the bug
was written, at review time, not before.

## Real mistakes (with root cause)

### 1. Premium gating bolted on after the fact, not built in
Sleep module (PR #73) shipped with **5 confirmed premium-gate bypasses
across 6 surfaces**, including a data export/import path that leaked
premium content to free users. This wasn't a typo — the module was written
without a single shared gate check, so every new surface (list screen,
detail screen, export, import, stats) had to individually remember to gate
itself, and most didn't.
**Root cause**: no reusable "premium-gated widget/route" pattern was
established before the second premium module was written — Blood
Pressure right after it needed the same fix pattern applied manually again.

### 2. Multi-tenant filters added to some queries, not the shared path
Family/Multi-Profile (PR #90) added `profileId` to repository method
*signatures* across the board, but four UPDATE statements
(`markDoseDone`, `markDoseSkipped`, `undoDose`, `updateDoseNotes` in
`medicine_repository_impl.dart`) kept the old `WHERE id = ?` and dropped
the profileId into the parameter list without adding it to the `WHERE`
clause. That means a stale dose id (or one profile's own dose id colliding
in a shared range) could be mutated regardless of which profile the
request claimed to be. Caught by review, not by the person adding the
`required String profileId` parameter in the first place.
**Root cause**: threading a parameter through a signature is not the same
as using it — nothing forced every WHERE clause to actually reference it.

### 3. Copy-pasted logic instead of reusing a shared helper
Exercise module's stats chart and its aggregation usecase each computed
"start of week" independently, and one of the two copies was wrong
(non-Monday-aligned), producing 9 buckets instead of 8 on 6 of 7 weekdays.
**Root cause**: `weekStartFor()` already existed as a shared utility;
the second call site was written from scratch instead of calling it.

### 4. Force-unwraps on theme extensions
`VirtualCompanion._moodColor()`, `PrayerTile`, and `GlobalMonthCalendar`
all did `theme.extension<AppSemanticColors>()!` — crashes in any context
that builds a bare `MaterialApp` (every widget test that doesn't route
through `AppTheme.light()/dark()`). Found in production via a crash
report equivalent, fixed in one file, then had to be found and fixed in
two more files that had the identical pattern.
**Root cause**: the unsafe pattern wasn't caught in the first file's own
review; once caught, no repo-wide grep was done immediately to catch the
siblings — that happened in a follow-up session.

### 5. Fire-and-forget async on a destructive action
Mood module's delete button didn't await/catch the delete future — a
failed delete would silently show success. Needed two separate review
passes on the same PR to land the full three-part fix (await, catch,
user-visible error).

### 6. Tracking docs drift from actual code state
`docs/IMPLEMENTATION-ORDER.md` (the 57-spec roadmap) fell out of sync with
reality in both directions — some specs marked "placeholder" were already
fully implemented, others marked done had partial implementations. Needed
a dedicated audit session to reconcile before work could safely continue.
**Root cause**: the doc was updated by whichever session happened to touch
the relevant spec, with no single point where "mark complete" was
enforced as part of the merge step for a while.

### 7. Retrying hung tests instead of root-causing them
At least 4 separate incidents (Aug 6 alone) of `flutter test` hanging,
each handled by killing the process and falling back to `analyze` +
manual review — a fallback, not a fix. The actual causes were found later
and were consistent and fixable: multiple `AppDatabase` instances sharing
one `QueryExecutor` (Drift explicitly warns this causes races/corruption),
and Drift stream timers not cancelled in test teardown. Once found, the
fix was a few lines (shared DB instance / `disposeTree()` / `runAsync()`
wrapping). The pattern repeated for days before someone treated it as a
root-cause bug instead of environment flakiness.

### 8. Parallel worktrees collided and left orphaned branches
Running two specs in parallel worktrees hit a working-tree collision on
the main session (Aug 6). Separately, `git worktree remove` was assumed to
also delete the branch it pointed at — it doesn't. Orphaned
`worktree-agent-*` branches accumulated across sessions and needed manual
sweeps (Aug 7, twice) to find and delete both local and remote copies.

### 9. Over-parallelizing past what one context window can supervise
The "7 specs in parallel" push on Aug 7 produced ~15 near-duplicate
session summaries in ~4 hours (S567 through S584) — the driving session
kept overflowing context and having to resume, re-discover which of the 7
branches were where, and re-verify state. The specs themselves weren't
wrong; running all 7 at once with one supervising session was more
coordination overhead than the parallelism saved.

## How not to make these mistakes again

1. **Gate once, at the boundary, not per-screen.** Before writing a second
   premium (or otherwise access-controlled) module, extract a single
   gate — a route guard, a wrapping widget, or a repository-level check —
   that every surface of a gated module goes through by construction. A
   new screen that forgets to gate itself should be *structurally
   incapable* of shipping ungated, not reliant on the author remembering.

2. **A scoping parameter is not "handled" until it's in every WHERE
   clause.** When threading `profileId` (or any tenant/scope key) through
   a repository, grep every `UPDATE`/`DELETE`/raw query in that file
   before calling the task done — a parameter that reaches the method
   body but not the query is worse than no parameter, because it *looks*
   scoped in review of the signature.

3. **Before writing date/week/period math, grep for an existing helper
   first.** This codebase already has `weekStartFor()` /
   `localDayKey()` / `LocalDate` utilities specifically to avoid
   reimplementing DST- and week-boundary-sensitive logic. Two
   implementations of the same calculation is itself the bug, independent
   of which one is "more correct."

4. **When a force-unwrap on shared theme/context state is fixed in one
   widget, grep the whole repo for the same pattern before closing that
   task.** `grep -rn "extension<AppSemanticColors>()!"` takes seconds and
   would have caught all three sites at once instead of three separate
   sessions.

5. **Destructive async actions (delete, undo, discard) always need
   await + try/catch + user-visible failure state** — treat this as a
   checklist item on any button that mutates or removes data, not
   something code review discovers after the fact.

6. **Update the roadmap/tracking doc as part of the merge step for that
   spec, not as a separate later pass.** Add it to the same commit or PR
   that completes the spec — a stale roadmap is a discovery cost paid by
   whichever future session has to reconcile it.

7. **A hanging test is a bug report, not noise.** The second time the same
   test (or same category — "any Drift-backed widget test") hangs, stop
   killing-and-retrying and go find the root cause. In this project it was
   always one of: multiple `AppDatabase` instances on one executor, or an
   uncancelled Drift stream/timer in teardown — check those two first.

8. **`git worktree remove` does not delete the branch.** After removing a
   worktree, explicitly `git branch -d`/`push origin --delete` the branch
   too, or schedule a periodic sweep — don't rely on worktree cleanup
   alone. Before deleting, verify with
   `git merge-base --is-ancestor <branch> dev`.

9. **Cap parallel agent/worktree fan-out to what one supervising session
   can track without losing state.** If a batch of specs needs more than
   ~3–4 truly parallel branches, either split it across separate
   supervising sessions/conversations (not one session juggling all of
   them) or run them in smaller sequential batches — the coordination
   overhead of tracking many branches in one context is what caused the
   Aug 7 session churn, not the specs themselves.

## What worked and should keep happening

- **Multi-angle parallel code review (8 finder agents + verification
  agents) before every merge** caught every mistake listed above. None of
  these bugs reached `dev` unreviewed — the review pipeline is the reason
  this list is a retrospective and not an incident report. Keep it
  mandatory for every PR, especially ones you feel confident about.
- **Root-causing before merging**, e.g. verifying the palette test
  failure was pre-existing (not caused by the current branch) by checking
  out the baseline commit before assuming blame — avoided wasted debugging
  on the wrong branch.
- **Killing stuck processes and moving on with a fallback plan
  (`analyze` + manual review)** kept sessions from stalling completely,
  even though the underlying test hangs should have been root-caused
  sooner (see #7 above).
