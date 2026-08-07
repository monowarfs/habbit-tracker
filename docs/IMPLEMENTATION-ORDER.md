# Implementation Order: Remaining Specs

**Created:** 2026-07-25
**Updated:** 2026-08-07 — 7 specs removed, merged to dev in parallel (PRs
#83-#89): #35 (05-consistency-score), #31 (08-audio-cue-alternative-
notification-actions), #32 (01-adherence-heatmap), #33 (02-personal-
record-tracking), #28 (01-talkback-voiceover-navigation-audit), #27
(07-milestone-certificate-image), #30 (05-dynamic-text-scaling-stress-
test). Several agents found and fixed real bugs along the way: a race
between the personal-record live check and its resume-time backfill, an
orphaned duplicate PNG in the certificate cache, two hardcoded-English
accessibility strings (Medicine's Skip/Done tooltips, Prayer's unlabeled
toggle button), and 5 layout-overflow bugs at 2.0x text scale (Water's
add-entry form, `PeriodBarChart` axis labels, `streak_card`, `TrendArrow`,
and the personal-record "New Record!" chip). `app_database.dart` schema
now at v32 (`personal_records` + `audio_cues_enabled` added this batch).
Prior update 2026-08-06 — #29 (03-colorblind-safe-streak-heatmap, PR #81)
removed: merged to dev. Palette-agnostic streak/heatmap indicators
(shape/pattern, not color-only) verified against AppSemanticColors.
Prior update 2026-08-06 — #47 (08-point-shop-cosmetic-unlocks, PR #82)
removed: merged to dev. XP-purchase cosmetic shop; extended
`palettePacks`/`iconPacks` with the 4 shop items so a purchase can
actually apply through the existing theme-selection pipeline.
Prior update 2026-08-05 — #26 (06-same-day-multi-module-combo-bonus, PR
#80) removed: merged to dev. Uses `XpValues.comboBonus`, reserved by
spec 02 since PR #79.
Prior update 2026-08-05 — #25 (02-cross-module-xp-level-system, PR #79)
removed: merged to dev. Retrofits weekly-quest/boss-claim copy to show
real XP amounts (`+{amount} XP`), closing the gap #39/#48 shipped
without. #47 (point-shop) is now unblocked — its "Spec 02 (XP system)"
dependency is satisfied.
Prior update 2026-08-05 — #39 (04-weekly-quest-chains, PR #77) and #48
(09-weekly-boss-milestone-challenge, PR #78) removed: both merged to dev.
Prior update 2026-08-04 — 20 of 57 done: Wave 0, Wave 1 in full, plus
#14-17/36/38/40/41 from Wave 2-3 (see git log `--merges` and direct
commits, PRs #54-76), including `04-additional-habit-modules-pack`
(Sleep/BP/Mood/Exercise modules, PRs #73-76).
**Remaining specs:** 24

---

## Dependency Graph Summary

### Wave 2: Depends on Wave 1 or foundational
### Wave 3: Depends on Wave 2
### Blocked: Requires external decisions (backend, accounts, future features)

---

## Implementation Order

### Wave 2: Depends on Wave 1 or foundational
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 18 | 10-advanced-widget-layouts | 04-premium | 4-5 days | Existing widget infrastructure |
| 19 | 11-exclusive-cosmetic-badge-sets | 04-premium | 2-3 days | Spec 07 (entitlements) |
| 20 | 01-share-a-streak-image | 05-community | 1 day | `share_plus`, streak use cases |
| 21 | 02-invite-a-friend-deep-link | 05-community | 0.5 day | `share_plus`, `app_links` |
| 22 | 08-community-habit-template-marketplace | 05-community | 1 day | Module creation forms |
| 23 | 05-mosque-finder-jamaah-times | 05-community | 2 days | Prayer location resolver |
| 24 | 01-streak-freeze-grace-token | 06-gamification | 2 days | Streak calculators |
| 34 | 08-adherence-by-medicine | 08-analytics | 1 day | calculateAdherence |

---

### Wave 3: Depends on Wave 2
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 37 | 02-multi-device-sync | 04-premium | 8-10 days | Spec 01 (Drive backup) |
| 42 | 02-chart-data-table-fallback | 07-accessibility | 1 day | Spec 01 (TalkBack audit) |
| 43 | 10-focus-order-keyboard-navigation-pass | 07-accessibility | 1 day | Spec 01 |
| 44 | 06-simple-mode-large-button-layout | 07-accessibility | 3 days | Specs 01, 03, 05 |
| 45 | 06-comparison-to-past-self | 08-analytics | 1 day | 1 year of data |

---

### Wave 4: Depends on Wave 3
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 46 | 03-family-multi-profile | 04-premium | 8-10 days | Spec 02 (sync) |

---

### Wave 5: Depends on Wave 4
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 49 | 04-household-shared-device-leaderboard | 05-community | 2 days | Multi-profile (04-premium/03) |
| 50 | 12-household-leaderboard | 06-gamification | 2 days | Multi-profile (04-premium/03) |

---

### Blocked (requires external decisions)
| # | Spec | Directory | Blocker |
|---|---|---|---|
| 51 | 06-cloud-accountability-groups | 05-community | Backend/account decision |
| 52 | 07-global-city-prayer-participation-stat | 05-community | Backend decision |
| 53 | 09-ramadan-community-challenge | 05-community | Requires spec 06 |
| 54 | 11-caregiver-read-only-view-link | 05-community | Backend/token relay decision |
| 55 | 11-opt-in-usage-analytics | 08-analytics | 6-point product/legal gate |
| 56 | 11-captioned-onboarding | 07-accessibility | Future onboarding feature |
| 57 | 12-screen-reader-friendly-onboarding-order | 07-accessibility | Future onboarding feature |

---

## Implementation Sequence (recommended)

**Wave 2 (8 specs):** premium/community/gamification/analytics features
depending only on Wave 0-1 foundations, which are already live.

**Wave 3 (5 specs):** depends on Wave 2 items landing first. Specs 42/43
(chart-data-table-fallback, focus-order-keyboard-navigation-pass) are now
unblocked — spec 01 TalkBack audit landed 2026-08-07 — and can start any
time; 44 (simple-mode) still needs specs 03/05 too.

**Wave 4-5 (5 specs):** depends on multi-device sync (#37) and family
multi-profile (#46) — the two heaviest remaining specs (8-10 days each).

**Blocked (7 specs):** deferred until backend/account/legal decisions clear.

**# column values are preserved from the original 57-spec numbering** for
traceability back to `docs/superpowers/specs/`; they are not sequential in
this trimmed file.
