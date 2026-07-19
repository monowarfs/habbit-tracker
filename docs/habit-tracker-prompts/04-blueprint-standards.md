# 04 — ENGINEERING STANDARDS & PHASE PLAN (documentation only — NO code)

**Inputs:** `00-project-context.md`, `docs/technical/*`, `docs/strategies/*`
**Outputs:** files under `docs/engineering/`

## 1. `coding-standards.md`
- Lint baseline: `flutter_lints` or `very_good_analysis` — compare,
  recommend, include the exact `analysis_options.yaml`
- Immutability rules, no logic in widgets beyond composition, provider
  naming, error propagation conventions, doc-comment expectations on public
  APIs, generated-file handling (`*.g.dart`/`*.freezed.dart` committed or
  not — decide and justify)

## 2. `naming-conventions.md`
Files (snake_case + suffix conventions: `_screen`, `_controller`,
`_repository`, `_provider`), classes, providers, DB collections, ARB keys
(`moduleName_screen_element`), route names, test file mirroring rule.

## 3. `git-strategy.md`
Solo-developer-appropriate: trunk-based with short-lived feature branches
(`feat/water-module`), conventional commits, tags per milestone
(`v0.5-scaffold`). Explicitly reject GitFlow for a solo project and say why.

## 4. `cicd.md`
GitHub Actions (developer already knows it): PR workflow = format check +
analyze + test; tag workflow = build signed Android AAB; note iOS signing
requires macOS runner + Apple Developer account — outline, mark as
later-phase. Cache pub + gradle. Include workflow YAML skeletons.

## 5. `packages.md`
Every dependency with: purpose, why this over alternatives, and a maintenance
health note. **Verify each against pub.dev now** (last release date, null
safety, platform support) — do not state versions from memory. Flag any
package that looks stale and give a fallback.

## 6. `phases-and-dod.md`
For each implementation run 05–13 define:
- Entry criteria (which docs/runs must exist)
- Scope (in / explicitly out)
- **Definition of Done**, always including: `flutter analyze` zero issues,
  `dart format` clean, named test suites passing, app boots on Android
  emulator + iOS simulator, feature demo checklist (exact taps to verify),
  docs updated, one conventional commit, no TODOs without a linked issue
- Rollback note: each run must leave `main` shippable

## 7. `agent-workflow.md`
Rules for AI-assisted implementation runs (this is meta but important):
- One run = one prompt file = one fresh session; attach 00 + the run file +
  listed input docs only
- The agent states its plan (file list + test list) BEFORE writing code and
  waits for approval
- The agent never edits files outside its run's declared scope
- On any blueprint conflict discovered mid-run: stop, report, propose an
  amendment to `decisions.md`
