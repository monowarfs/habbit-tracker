# Implementation Order: 57 Specs Across 5 Directories

**Created:** 2026-07-25
**Total specs:** 57 (11 premium + 11 community + 12 gamification + 12 accessibility + 11 analytics)

---

## Dependency Graph Summary

### Foundational (no dependencies, implement first)
These specs establish infrastructure that other specs depend on.

### Wave 1: Independent specs (can be implemented in parallel)
### Wave 2: Depends on Wave 1
### Wave 3: Depends on Wave 2
### Blocked: Requires external decisions (backend, accounts, future features)

---

## Implementation Order

### Wave 0: Foundational IAP Infrastructure
| # | Spec | Directory | Effort | Why first |
|---|---|---|---|---|
| 1 | 07-lifetime-unlock-pricing-tier | 04-premium | 2-3 days | Establishes entitlement system all premium features use |
| 2 | 06-icon-packs-advanced-theming | 04-premium | 2-3 days | First premium feature, validates IAP flow |

**Rationale:** These two specs establish the `core/premium/entitlement_service.dart` and `premium_gate_widget.dart` that all other premium features depend on. Must ship together.

---

### Wave 1: Zero-dependency features
| # | Spec                                      | Directory | Effort | Dependencies |
|---|-------------------------------------------|---|---|---|
| 3 | 03-external-community-link                | 05-community | 0.25 day | None |
| 4 | 10-in-app-feedback-feature-request-board  | 05-community | 0.25 day | None |
| 5 | 04-haptic-feedback-on-log-complete        | 07-accessibility | 0.5 day | None |
| 6 | 07-reduce-motion-respect                  | 07-accessibility | 0.5 day | None |
| 7 | 09-rtl-readiness-structural-audit         | 07-accessibility | 0.5 day | None |
| 8 | 05-badge-rarity-tiers                     | 06-gamification | 0.5 day | None |
| 9 | 11-achievement-almost-there-progress-bars | 06-gamification | 1 day | None |
| 10 | 04-trend-arrows                           | 08-analytics | 0.5 day | None |
| 11 | 03-day-of-week-breakdown                  | 08-analytics | 0.5 day | None |
| 12 | 09-goal-attainment-rate                   | 08-analytics | 0.5 day | None |
| 13 | c                                         | 08-analytics | 0.5 day | None |

---

### Wave 2: Depends on Wave 1 or foundational
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 14 | 01-google-drive-backup-restore | 04-premium | 3-4 days | Local export/import (existing) |
| 15 | 05-exportable-pdf-csv-reports | 04-premium | 3-4 days | Reports module (existing) |
| 16 | 08-extended-stats-range | 04-premium | 1-2 days | Reports module (existing) |
| 17 | 09-priority-support | 04-premium | 1 day | Spec 07 (entitlements) |
| 18 | 10-advanced-widget-layouts | 04-premium | 4-5 days | Existing widget infrastructure |
| 19 | 11-exclusive-cosmetic-badge-sets | 04-premium | 2-3 days | Spec 07 (entitlements) |
| 20 | 01-share-a-streak-image | 05-community | 1 day | `share_plus`, streak use cases |
| 21 | 02-invite-a-friend-deep-link | 05-community | 0.5 day | `share_plus`, `app_links` |
| 22 | 08-community-habit-template-marketplace | 05-community | 1 day | Module creation forms |
| 23 | 05-mosque-finder-jamaah-times | 05-community | 2 days | Prayer location resolver |
| 24 | 01-streak-freeze-grace-token | 06-gamification | 2 days | Streak calculators |
| 25 | 02-cross-module-xp-level-system | 06-gamification | 3 days | Achievements engine |
| 26 | 06-same-day-multi-module-combo-bonus | 06-gamification | 1 day | Dashboard completion |
| 27 | 07-milestone-certificate-image | 06-gamification | 2 days | Image renderer |
| 28 | 01-talkback-voiceover-navigation-audit | 07-accessibility | 2 days | All screens complete |
| 29 | 03-colorblind-safe-streak-heatmap | 07-accessibility | 0.5 day | AppSemanticColors |
| 30 | 05-dynamic-text-scaling-stress-test | 07-accessibility | 1 day | All screens complete |
| 31 | 08-audio-cue-alternative-notification-actions | 07-accessibility | 1 day | Notification handler |
| 32 | 01-adherence-heatmap | 08-analytics | 2 days | dayStatus() per module |
| 33 | 02-personal-record-tracking | 08-analytics | 1 day | longestStreak() |
| 34 | 08-adherence-by-medicine | 08-analytics | 1 day | calculateAdherence |
| 35 | 05-consistency-score | 08-analytics | 2 days | dayStatus() per module |
| 36 | 10-prayer-on-time-vs-late | 08-analytics | 2 days | PrayerStatus schema change |

---

### Wave 3: Depends on Wave 2
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 37 | 02-multi-device-sync | 04-premium | 8-10 days | Spec 01 (Drive backup) |
| 38 | 04-additional-habit-modules-pack | 04-premium | 10-12 days | Spec 07 (entitlements) |
| 39 | 04-weekly-quest-chains | 06-gamification | 3 days | Achievements engine extension |
| 40 | 03-virtual-companion | 06-gamification | 3 days | Art assets |
| 41 | 10-avatar-customization | 06-gamification | 3 days | Art assets, overlaps with 03 |
| 42 | 02-chart-data-table-fallback | 07-accessibility | 1 day | Spec 01 (TalkBack audit) |
| 43 | 10-focus-order-keyboard-navigation-pass | 07-accessibility | 1 day | Spec 01 |
| 44 | 06-simple-mode-large-button-layout | 07-accessibility | 3 days | Specs 01, 03, 05 |
| 45 | 06-comparison-to-past-self | 08-analytics | 1 day | 1 year of data |

---

### Wave 4: Depends on Wave 3
| # | Spec | Directory | Effort | Dependencies |
|---|---|---|---|---|
| 46 | 03-family-multi-profile | 04-premium | 8-10 days | Spec 02 (sync) |
| 47 | 08-point-shop-cosmetic-unlocks | 06-gamification | 2 days | Spec 02 (XP system) |
| 48 | 09-weekly-boss-milestone-challenge | 06-gamification | 2 days | Specs 04, 02 |

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

**Phase 1 (Wave 0 + Wave 1):** ~5-6 days
Specs 1-13: Foundational IAP + zero-dependency features

**Phase 2 (Wave 2):** ~15-20 days
Specs 14-36: Features depending on Wave 1

**Phase 3 (Wave 3):** ~12-15 days
Specs 37-45: Features depending on Wave 2

**Phase 4 (Wave 4-5):** ~12-14 days
Specs 46-50: Features depending on Wave 3

**Blocked specs (51-57):** Deferred until blockers clear

**Total estimated effort:** 44-55 days of implementation work
