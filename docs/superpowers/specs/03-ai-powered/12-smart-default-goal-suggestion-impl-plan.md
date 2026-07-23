# Smart Default Goal Suggestion — Implementation Plan

**Spec:** [12-smart-default-goal-suggestion-design.md](./12-smart-default-goal-suggestion-design.md)
**Run:** TBD
**Estimated effort:** S
**Dependencies:** Water module (complete — `WaterGoal` entity, `WaterRepository.setGoal()`, `WaterController`)

## Pre-requisites

- Water module fully functional: `WaterGoal` entity, `WaterRepository.setGoal()`, `WaterController` with `updateGoal` method.
- `WaterGoalOnboardingScreen` or equivalent first-time setup flow exists (or this feature introduces it).
- Decision made on whether this runs only at first Water setup or also as a recalculate option in Settings.

## Tasks

### Task 1: `WaterGoalInputs` + `WaterGoalSuggestion` entities
**Effort:** S
**Files to create:**
- `lib/features/water/domain/entities/water_goal_suggestion.dart`

**Files to modify:** (none)

**Description:** Create `ClimateZone` enum (`cool`, `temperate`, `hot`, `veryHot`). Create `WaterGoalInputs` Freezed entity with `ageYears` (int), `weightKg` (int), `climate` (ClimateZone). Create `WaterGoalSuggestion` Freezed entity with `suggestedMl` (int), `inputs` (WaterGoalInputs), `formulaDescription` (String).

**Acceptance criteria:**
- `ClimateZone` enum has all four values.
- `WaterGoalInputs` compiles with generated `.freezed.dart`.
- `WaterGoalSuggestion` compiles with generated `.freezed.dart`.
- `formulaDescription` is a human-readable string explaining the formula breakdown.

**Test:** `test/features/water/domain/entities/water_goal_suggestion_test.dart` — Freezed construction, equality, copyWith for both entities. `test/features/water/domain/entities/water_goal_inputs_test.dart` — construction with all `ClimateZone` values.

---

### Task 2: `SuggestWaterGoalUseCase` + formula unit tests
**Effort:** S
**Files to create:**
- `lib/features/water/domain/usecases/suggest_water_goal.dart`

**Files to modify:** (none)

**Description:** Pure use case — no repository, no I/O, no side effects. Formula: baseline 33 ml/kg of body weight, adjusted by age (<18: 35 ml/kg, >65: 30 ml/kg) and climate (cool: 0.90x, temperate: 1.0x, hot: 1.15x, veryHot: 1.25x). Result rounded to nearest 50 ml, clamped to 1000–5000 ml. Returns `WaterGoalSuggestion` with the suggested value and a human-readable formula description.

**Acceptance criteria:**
- Baseline: 33 ml/kg for ages 18–65.
- Age adjustments: 35 ml/kg for <18, 30 ml/kg for >65.
- Climate factors: cool 0.90, temperate 1.0, hot 1.15, veryHot 1.25.
- Result rounded to nearest 50 ml.
- Result clamped to 1000–5000 ml range.
- `formulaDescription` is a readable string like "33 ml × 70 kg × 1.15 (hot climate) ≈ 2680 ml/day".

**Test:** `test/features/water/domain/usecases/suggest_water_goal_test.dart` — verify formula with various age/weight/climate combos, boundary values (min/max age, min/max weight, all climate zones), rounding behavior, clamping at 1000 and 5000.

---

### Task 3: `WaterGoalOnboardingScreen` UI
**Effort:** M
**Files to create:**
- `lib/features/water/presentation/screens/water_goal_onboarding_screen.dart`

**Files to modify:** (none)

**Description:** Single-screen onboarding step: age slider (10–80), weight text field (kg), climate segmented button (4 options). As inputs change, compute suggestion via `SuggestWaterGoalUseCase` and display in a Card with the formula description. "Use this goal" button calls `WaterController.updateGoal(suggestedMl)` and pops. "Skip — use default" button pops without changing the goal. Include disclaimer text: "This is a general estimate based on common hydration guidelines. It is not medical advice."

**Acceptance criteria:**
- Age slider ranges 10–80 with integer steps.
- Weight field accepts integer kg input.
- Climate picker shows all four `ClimateZone` options.
- Suggestion updates live as inputs change.
- "Use this goal" saves via `WaterController.updateGoal()` and navigates back.
- "Skip" pops without saving.
- Disclaimer text is visible and non-dismissible.

**Test:** `test/features/water/presentation/screens/water_goal_onboarding_screen_test.dart` — age slider updates, weight input triggers suggestion, climate toggle changes suggestion, confirm button calls controller, skip button pops.

---

### Task 4: Route registration + settings "Recalculate" button
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/router/app_router.dart`
- `lib/features/water/presentation/screens/water_settings_screen.dart`

**Description:** Register `/water/goal-onboarding` route under the Water branch in `app_router.dart`, pointing to `WaterGoalOnboardingScreen`. Add a "Recalculate suggested goal" `ListTile` in the Water settings screen that navigates to this route.

**Acceptance criteria:**
- Route `/water/goal-onboarding` is registered and navigable.
- "Recalculate suggested goal" button visible in Water settings.
- Tapping the button navigates to the onboarding screen.

**Test:** Widget test — verify route exists, button navigates correctly.

---

### Task 5: Localization keys (en + bn)
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:** Add all new localization keys for the onboarding flow in both English and Bangla.

**Acceptance criteria:**
- All keys present in both ARB files.
- `flutter gen-l10n` succeeds without errors.

**Test:** `flutter gen-l10n` compiles cleanly; verify keys in `AppLocalizations`.

---

### Task 6: Widget tests for onboarding screen
**Effort:** S
**Files to create:** (none)
**Files to modify:** (none)

**Description:** Run all unit and widget tests from prior tasks. Verify the onboarding screen widget test passes: age slider updates, weight input triggers suggestion, climate toggle changes suggestion, confirm button calls controller, skip button pops.

**Acceptance criteria:**
- All prior test files pass.
- Onboarding screen widget test covers all interactive elements.

**Test:** `flutter test test/features/water/presentation/screens/water_goal_onboarding_screen_test.dart`.

## Schema Migration

No schema migration needed. The suggestion pre-fills the existing `WaterGoal` entity via `WaterRepository.setGoal()`. User inputs (age, weight, climate) are not persisted — used once to compute the suggestion, then discarded.

## Localization Keys

| Key | English | Bangla |
|-----|---------|--------|
| `waterOnboardingTitle` | Set Your Water Goal | আপনার পানির লক্ষ্য নির্ধারণ করুন |
| `waterOnboardingSubtitle` | Tell us a bit about yourself for a personalized starting goal. | ব্যক্তিগতকৃত শুরুর লক্ষ্যের জন্য আমাদের কিছু তথ্য দিন। |
| `waterOnboardingDisclaimer` | This is a general estimate based on common hydration guidelines. It is not medical advice. You can adjust your goal anytime. | এটি সাধারণ হাইড্রেশন নির্দেশিকার উপর ভিত্তি করে একটি সাধারণ অনুমান। এটি চিকিৎসা পরামর্শ নয়। আপনি যেকোনো সময় আপনার লক্ষ্য সামঞ্জস্য করতে পারেন। |
| `waterOnboardingAgeLabel` | Your age | আপনার বয়স |
| `waterOnboardingWeightLabel` | Your weight | আপনার ওজন |
| `waterOnboardingClimateLabel` | Your climate | আপনার জলবায়ু |
| `waterClimateCool` | Cool | শীতল |
| `waterClimateTemperate` | Temperate | মৃদু |
| `waterClimateHot` | Hot | গরম |
| `waterClimateVeryHot` | Very Hot | খুব গরম |
| `waterOnboardingSuggestedGoal` | Suggested: {amount} ml/day | প্রস্তাবিত: {amount} মি.লি./দিন |
| `waterOnboardingConfirmGoal` | Use this goal | এই লক্ষ্য ব্যবহার করুন |
| `waterOnboardingSkip` | Skip — use default | এড়িয়ে যান — ডিফল্ট ব্যবহার করুন |
| `waterSettingsRecalculateGoal` | Recalculate suggested goal | প্রস্তাবিত লক্ষ্য পুনর্গণনা করুন |

## Risk Notes

1. **Formula is a heuristic, not medical advice** — the disclaimer text must be prominent and clear. The formula (33 ml/kg with age/climate adjustments) is a well-established general-population heuristic, but it should never be presented as personalized medical guidance.
2. **Weight unit assumption** — the plan assumes kg (metric), which is appropriate for the Bangladesh target market. If lbs support is added later via `WaterUnit`, the onboarding screen should accept the user's preferred unit and convert internally.
3. **Default climate from locale** — a minor enhancement could auto-select `ClimateZone.hot` for Bangla locale as a starting guess. Not blocking, but improves the first impression for the target market.
4. **Onboarding trigger** — the plan supports both first-time setup and recalculate-via-Settings. The screen is route-accessible from anywhere. The decision on when to show it automatically (if at all) is a product choice.
5. **Formula constants** — the 33 ml/kg baseline, age thresholds (18, 65), and climate factors (0.90–1.25) are based on standard hydration guidelines. These should be reviewed by a health advisor before production use, though the disclaimer already notes this is not medical advice.
