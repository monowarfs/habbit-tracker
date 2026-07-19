# 05 — IMPLEMENTATION: PROJECT SCAFFOLD

**Inputs:** `00-project-context.md`, `docs/technical/folder-structure.md`,
`docs/technical/architecture.md`, `docs/strategies/theme.md`,
`docs/strategies/localization.md`, `docs/engineering/coding-standards.md`
**First code run. State your file plan before writing anything.**

## Scope

1. `flutter create` with correct org id (choose reverse-domain with the
   developer, e.g. `dev.<name>.habittracker`), min SDK Android 26+
   (justify the floor you pick against notification-API needs), iOS 13+.
2. Commit the exact `analysis_options.yaml` from the standards doc.
3. Dependencies: add ONLY what this run needs (riverpod, go_router, intl,
   logger + lints). DB, notifications, charts come in their own runs —
   keep the dependency diff reviewable per run.
4. Folder structure exactly per `folder-structure.md`, with `.gitkeep` or
   barrel files so the tree is real, plus `core/` skeletons:
   - `core/router/` — GoRouter with a `StatefulShellRoute` bottom-nav shell:
     Dashboard / Water / Medicine / Prayer / Settings tabs (placeholder
     screens), typed route names, redirect hook stub for future PIN lock
   - `core/theme/` — Material 3 light/dark themes from seed color, theme-mode
     controller (system default) persisted via a temporary in-memory settings
     provider (real persistence arrives in run 06 — leave a clearly marked
     seam, not a TODO comment graveyard)
   - `core/l10n/` — ARB setup with `en` + `bn`, ~10 real strings (app name,
     tab labels), locale switcher on the placeholder Settings screen,
     device-locale default
   - `core/modules/` — the `HabitModule` contract interface + a
     `moduleRegistry` list (empty registrations for now) exactly as designed
     in `architecture.md`
5. `main.dart` bootstrap: ProviderScope, localization delegates, theme wiring,
   router. Include a brief README section: how to run, how to run build_runner.

## Out of scope
Database, notifications, any real feature UI, PIN logic.

## Definition of Done
- Boots on Android emulator and iOS simulator; 5 tabs navigable
- Switching device language to Bangla changes visible strings; in-app
  switcher works
- Dark/light/system switching works
- `flutter analyze` zero issues; `flutter test` passes (include at least a
  router smoke widget test and a theme controller unit test)
- One commit: `feat: project scaffold with shell navigation, theming, l10n`
