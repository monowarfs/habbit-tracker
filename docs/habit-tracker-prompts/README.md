# Habit Tracker — AI-Assisted Development Prompt Pack

A sequential prompt pack for building an offline-first Flutter habit tracker
(Water / Medicine / Prayer) with Claude Code or any coding agent.

## Why this structure

Running one giant "do everything" prompt produces shallow output and burns
context. Instead:

- **`00-project-context.md`** is the shared context file. Attach or reference it
  in EVERY run. It contains the vision, tech stack, conventions, and rules.
- **`01`–`04`** are blueprint runs. They produce architecture documents
  (no code). Their outputs become inputs for later runs — save them into
  `docs/` in your repo.
- **`05`–`13`** are implementation runs, one vertical slice each. Every run
  ends with a compiling app and a git commit.

## Execution order

| # | File | Output |
|---|------|--------|
| 00 | project-context | (context only — never run alone) |
| 01 | blueprint-product | PRD, requirements, personas, stories, flows, roadmap |
| 02 | blueprint-technical | DB design, ERD, data models, architecture, state mgmt |
| 03 | blueprint-strategies | Notifications, l10n, theme, security, backup, testing, etc. |
| 04 | blueprint-standards | Coding standards, naming, git, CI/CD, phases, DoD |
| 05 | impl-scaffold | Flutter project, folder structure, theme, router, l10n shell |
| 06 | impl-core-infra | Isar, repositories, DI, error handling, logging |
| 07 | impl-water-module | Complete Water Tracker feature |
| 08 | impl-notification-engine | Shared notification/reminder engine |
| 09 | impl-medicine-module | Complete Medicine Tracker feature |
| 10 | impl-prayer-module | Complete Prayer Tracker feature |
| 11 | impl-dashboard-stats | Dashboard, charts, streaks, badges, calendar |
| 12 | impl-settings-security | Settings, PIN lock, JSON export/import |
| 13 | impl-polish-release | Testing sweep, accessibility, perf, release prep |

## Rules for every run

1. Start a **fresh session** per prompt file. Attach `00-project-context.md`
   plus the specific numbered prompt (and any docs it lists as inputs).
2. At the end of each implementation run, require: `flutter analyze` clean,
   tests passing, app boots on Android emulator, one git commit.
3. If the agent proposes deviating from the blueprint, it must state why and
   wait for your approval before proceeding.
4. Keep generated docs in `docs/` — later prompts reference them by filename.

## A note on the database choice

The stack specifies **Isar**. Verify Isar's current maintenance status before
committing — as of early 2026 the original project had long gaps between
releases, and many Flutter teams migrated to **Drift** (SQLite-based, actively
maintained, closer to your MySQL/Laravel mental model). Prompt 02 asks the
agent to make this comparison explicitly and recommend one. Don't skip that
step; swapping databases after Module 2 is painful.
