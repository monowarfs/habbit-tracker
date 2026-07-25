# Implementation Plan: Gamification Features (06-gamification)

**Specs:** 12 files | **Total estimated effort:** 20-25 days
**Created:** 2026-07-25

---

## Dependency Graph

```
Spec 01 (Streak Freeze)           — standalone
Spec 02 (XP/Level System)         — standalone (foundational)
Spec 03 (Virtual Companion)       — standalone, art assets needed
Spec 04 (Weekly Quest Chains)     — extends achievements engine
Spec 05 (Badge Rarity Tiers)      — standalone
Spec 06 (Combo Bonus)             — standalone
Spec 07 (Milestone Certificate)   — needs image renderer
Spec 08 (Point Shop)              — HARD depends on Spec 02
Spec 09 (Boss Challenge)          — HARD depends on Spec 04 + Spec 02
Spec 10 (Avatar Customization)    — overlaps with Spec 03
Spec 11 (Progress Bars)           — standalone
Spec 12 (Household Leaderboard)   — HARD depends on multi-profile
```

## Recommended Implementation Order

### Wave 1: Foundation (no cross-dependencies)
| Spec | Effort | Notes |
|---|---|---|
| 02 XP/Level System | 3 days | Foundational — other features depend on it |
| 01 Streak Freeze | 2 days | Extends existing streak calculators |
| 05 Badge Rarity Tiers | 0.5 day | Pure metadata on achievements |
| 11 Progress Bars | 1 day | Surfaces existing progress data |
| 06 Combo Bonus | 1 day | Uses existing completion data |

### Wave 2: Depends on Wave 1
| Spec | Effort | Notes |
|---|---|---|
| 04 Weekly Quest Chains | 3 days | Extends achievements engine |
| 07 Milestone Certificate | 2 days | Needs image renderer (shared with 05-community/01) |
| 03 Virtual Companion | 3 days | Art/animation asset pipeline |
| 10 Avatar Customization | 3 days | Art assets, overlaps with 03 |

### Wave 3: Depends on Wave 2
| Spec | Effort | Notes |
|---|---|---|
| 08 Point Shop | 2 days | Consumes XP from Spec 02 |
| 09 Boss Challenge | 2 days | Variant of weekly quests |

### Blocked
| Spec | Effort | Notes |
|---|---|---|
| 12 Household Leaderboard | 2 days | Blocked on multi-profile (Premium) |

---

## Per-Spec Task Breakdown

### 01 Streak Freeze / Grace Token
1. Create `lib/core/gamification/grace_token_repository.dart`
2. Add `grace_tokens` Drift table to `AppDatabase`
3. Implement token consumption logic (calendar-month scoped)
4. Extend each module's streak calculator to check for grace tokens
5. Add shield icon to dashboard and history calendar
6. Add en/bn ARB keys
7. Tests

### 02 XP/Level System
1. Create `lib/core/gamification/xp_repository.dart`
2. Add `xp_ledger` and `xp_balance` Drift tables
3. Define level curve formula (recommended: quadratic)
4. Listen to achievements engine event stream for XP events
5. Add XP gain toasts on qualifying actions
6. Add level display to dashboard
7. Define XP values per action type per module
8. Add en/bn ARB keys
9. Tests

### 03 Virtual Companion
1. Design mood-state machine (5 states, thresholds)
2. Commission art/animation assets (Lottie)
3. Create `lib/core/gamification/companion_state.dart`
4. Implement mood derivation from day-status data
5. Add companion widget to dashboard
6. Respect Reduce-Motion (Spec 07-accessibility/07)
7. Add en/bn ARB keys
8. Tests

### 04 Weekly Quest Chains
1. Create `lib/core/gamification/weekly_quest_repository.dart`
2. Add `weekly_quests` Drift table
3. Implement quest generation per module
4. Extend achievements engine for recurring/resettable objectives
5. Build quest list UI with progress bars
6. Add weekly reset logic (ISO 8601 week boundaries)
7. Add en/bn ARB keys
8. Tests

### 05 Badge Rarity Tiers
1. Add `rarity` field to `AchievementDefinition` class
2. Define `BadgeRarity` enum (common, rare, legendary)
3. Update each module's `achievementDefinitions` with rarity values
4. Update badge gallery to render rarity visual treatment
5. Add screen reader labels for rarity
6. Add en/bn ARB keys
7. Tests

### 06 Same-Day Combo Bonus
1. Implement combo detection from day-status data
2. Award bonus XP (when Spec 02 exists) or visual celebration
3. Add combo celebration animation
4. Handle single-module users (hide combo)
5. Add en/bn ARB keys
6. Tests

### 07 Milestone Certificate Image
1. Create `lib/core/widgets/image_renderer.dart` (shared with 05-community/01)
2. Design certificate template
3. Implement certificate generation from achievement data
4. Wire to share sheet via `share_plus`
5. Cache rendered certificates
6. Add en/bn ARB keys
7. Tests

### 08 Point Shop
1. Create `lib/core/gamification/shop_repository.dart`
2. Add `shop_unlocks` Drift table
3. Define v1 cosmetic catalog (themes, icons)
4. Implement purchase flow (deduct XP, mark owned)
5. Build shop catalog UI
6. Wire to theme/icon system
7. Add en/bn ARB keys
8. Tests

### 09 Weekly Boss Challenge
1. Extend `weekly_quests` table with `is_boss` column
2. Implement boss selection logic (module rotation)
3. Define difficulty thresholds per module
4. Build boss challenge UI (distinct from regular quests)
5. Award scaled XP reward
6. Add en/bn ARB keys
7. Tests

### 10 Avatar Customization
1. Create `lib/core/gamification/avatar_repository.dart`
2. Add `avatar_unlocks` and `avatar_equipped` Drift tables
3. Commission base avatar + unlockable pieces (art assets)
4. Implement unlock detection from achievement events
5. Build avatar display on dashboard
6. Build customize screen with slot selection
7. Add en/bn ARB keys
8. Tests

### 11 Achievement Progress Bars
1. Verify `AchievementDefinition.currentProgress` exposes continuous progress
2. Add progress bar to badge gallery cards
3. Sort unearned achievements by proximity
4. Handle binary achievements (target == 1)
5. Add screen reader progress labels
6. Add en/bn ARB keys
7. Tests

### 12 Household Leaderboard
1. **BLOCKED:** Wait for multi-profile (Spec 04-premium/03)
2. Implement cross-profile aggregation query
3. Build leaderboard UI with ranks
4. Add privacy opt-out per profile
5. Add en/bn ARB keys
6. Tests
