# Household/Family Plan Long-Term Hook — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/09-household-family-plan-hook-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation (positioning + trigger only — multi-profile and billing are separate specs)

---

## Architecture overview

This spec is primarily a **positioning spec** — it establishes when and where the household offer should be surfaced once multi-profile support exists. The implementation scope is:

1. A tenure-based trigger (reuse `installDate` from Spec 01).
2. A dismissible Dashboard banner after 12 months.
3. A Settings entry point for profile management.
4. Documentation of the intended UX for when multi-profile lands.

```
┌──────────────────────────────────────────────────────────┐
│  main.dart / HabitTrackerApp.didChangeAppLifecycle       │
│  → checkHouseholdBanner(db)                              │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/household/household_trigger.dart                   │
│  reads installDate + householdBannerDismissed            │
│  if daysSinceInstall >= 365 and !dismissed → show       │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  Dashboard: HouseholdBanner (new, dismissible)           │
│  "Add a household member" → links to profile creation   │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  Settings: "Household" section (new)                     │
│  placeholder until multi-profile lands                   │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| Schema migration v10 | Spec 01 T1 |

**Blocked on:** Multi-profile data model and Premium subscription (outside this category). This spec implements the trigger and UI surfaces; the actual profile management is a separate feature.

---

## Implementation tasks

### T1: Schema migration — `household_banner_dismissed` on `AppSettings`

**Files:**
- `lib/core/database/tables/app_settings_table.dart` — add `BoolColumn get householdBannerDismissed => boolean().withDefault(const Constant(false))();`
- `lib/features/settings/domain/entities/app_settings.dart` — add `@Default(false) bool householdBannerDismissed`
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — add `dismissHouseholdBanner()`, update `_toDomain`, `restoreSettings`
- `lib/core/database/app_database.dart` — bump `schemaVersion` to 17, add `if (from < 17)` block

**Migration (from < 17):**
```dart
if (from < 17) {
  await m.addColumn(appSettingsTable, appSettingsTable.householdBannerDismissed);
}
```

**Tests:** Migration test, repository methods.

---

### T2: Household trigger logic (pure)

**Files:**
- `lib/core/household/household_trigger.dart` — **new file**, pure logic

```dart
bool shouldShowHouseholdBanner({
  required DateTime? installDate,
  required bool bannerDismissed,
  required DateTime now,
}) {
  if (installDate == null || bannerDismissed) return false;
  return now.difference(installDate).inDays >= 365;
}
```

**Tests:** `test/core/household/household_trigger_test.dart` — pure unit tests.

---

### T3: Dashboard household banner

**Files:**
- `lib/features/dashboard/presentation/widgets/household_banner.dart` — **new file**
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — conditionally show banner

**Banner design:**
```
┌─────────────────────────────────────────────┐
│  👨‍👩‍👧‍👦  Add a household member               │
│                                             │
│  You've been tracking for over a year.      │
│  Share the app with family — track          │
│  habits together.                           │
│                                             │
│  [ Learn more ]              [ Dismiss ]    │
└─────────────────────────────────────────────┘
```

**Behavior:**
- "Learn more" → navigates to Settings > Household (or a placeholder screen if multi-profile isn't built yet).
- "Dismiss" → calls `dismissHouseholdBanner()`, banner disappears permanently.
- Banner is only shown once (dismissed = permanent).

**Tests:** Widget test — banner shows after 12 months, dismiss works, no re-show.

---

### T4: Settings "Household" section

**Files:**
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add "Household" tile
- `lib/features/settings/presentation/screens/household_settings_screen.dart` — **new file** (placeholder)

**Placeholder screen content:**
- "Household plans let you track habits for your whole family."
- "Multi-profile support is coming soon."
- "In the meantime, you can export/import data to share settings."

**Tests:** Settings navigation test.

---

### T5: Documentation

**Files:**
- `docs/engineering/household-plan-positioning.md` — **new file**, documents:
  - When to surface the offer (12 months tenure)
  - Where (Dashboard banner + Settings)
  - How it connects to multi-profile (once that lands)
  - How it connects to Premium subscription (once that lands)
  - The `installDate` dependency

---

### T6: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~8 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `householdBannerTitle` — "Add a household member"
- `householdBannerBody` — "You've been tracking for over a year. Share the app with family."
- `householdBannerLearnMore` — "Learn more"
- `householdBannerDismiss` — "Dismiss"
- `householdSettingsTitle` — "Household"
- `householdSettingsComingSoon` — "Multi-profile support is coming soon."
- `householdSettingsDescription` — "Track habits for your whole family with separate profiles."

---

## Task sequencing

```
T1 (schema) ──→ T2 (trigger) ──→ T3 (banner) ──→ T6 (i18n)
T3 ──→ T4 (settings)
T4 ──→ T5 (docs)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add household_banner_dismissed to app_settings (migration 17)` |
| 2 | T2 | `feat(household): add tenure-based banner trigger logic` |
| 3 | T3 | `feat(dashboard): add household plan suggestion banner` |
| 4 | T4 | `feat(settings): add household settings placeholder screen` |
| 5 | T5 | `docs: add household plan positioning document` |
| 6 | T6 | `feat(i18n): add en/bn strings for household plan hook` |
