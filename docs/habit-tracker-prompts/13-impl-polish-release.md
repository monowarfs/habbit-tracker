# 13 — IMPLEMENTATION: HARDENING, ACCESSIBILITY, RELEASE PREP

**Inputs:** `00-project-context.md`, `docs/strategies/accessibility.md`,
`docs/strategies/performance.md`, `docs/product/release-plan.md`

## Scope

1. **Accessibility sweep** per strategy doc: semantics labels on all
   interactive elements, 48dp touch targets, 200% text-scale check on the
   three densest screens with fixes, contrast verification both themes,
   TalkBack walkthrough of the three core logging flows — record findings
   and fixes in `docs/testing/a11y-report.md`
2. **Performance pass**: cold-start measurement against budget, chart
   rendering with a seeded year of data, jank check on dose timeline and
   calendar scrolling, `flutter build --analyze-size` review; apply the
   pre-aggregation strategy if raw queries miss budget (per strategy doc)
3. **Test-gap sweep**: coverage report; close gaps in the 10 named
   high-value suites from the testing strategy; add one integration test:
   fresh install → onboard → log one item in each module → verify dashboard
4. **Empty/error/loading states audit**: every screen handles all three
   deliberately (no infinite spinners, no raw exceptions)
5. **First-run experience**: language selection, brief 3-screen onboarding
   (skippable), notification pre-permission explainer placement
6. **Release engineering**:
   - Android: app id finalization, adaptive icon, splash, signed AAB via the
     CI tag workflow, ProGuard/R8 rules verified for the DB and
     notifications packages
   - iOS: icons, launch screen, permission usage strings (notifications,
     optional location for prayer times) with honest wording
   - Store metadata drafts (en + bn): descriptions, screenshots list,
     Play data-safety answers (all data local, no collection — verify each
     answer is truthful against the actual code), privacy policy document
7. Version `1.0.0+1`, changelog, tag `v1.0.0`

## Definition of Done
- All previous runs' DoD checks still green (full regression)
- a11y report + perf numbers committed to `docs/testing/`
- Signed release AAB built by CI; iOS archive builds locally
- Commit + tag: `chore(release): v1.0.0`

## After this run
v1.1 candidates (Google Drive backup via the BackupTarget seam, next module
via the plugin recipe) each get their own new prompt file following the same
template: Inputs → Scope → Out of scope → DoD.
