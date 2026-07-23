# Smart Default Goal Suggestion

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water's onboarding today presumably starts a new user with a bare
default daily goal number, which is either arbitrary or requires the
user to already know a reasonable target for themselves. Generic
hydration-app formulas (weight/age/climate-based estimates) are
well-established and give a much better starting point than a flat
default, reducing the chance a new user's very first experience with
Water is a goal that's obviously wrong for them (too easy or
discouragingly high). This is a small, static-formula feature — no
model, no learning, just a better-informed default at the moment a
`WaterGoal` is first created.

## Goals
- At onboarding (or first Water setup), ask for a small number of simple
  inputs (e.g. age, weight, general climate) and compute a suggested
  starting daily water goal from a standard hydration formula.
- Present the suggestion as an editable default, not a locked value —
  the user can always adjust it immediately or later through the
  existing goal-setting flow.
- Keep the formula and its inputs simple enough to ask for in a single
  onboarding step without feeling like a medical intake form.

## Non-goals / out of scope
- No personalized/adaptive model — a fixed, well-known formula
  (e.g. weight-based ml/kg with a climate adjustment factor), not
  anything that learns or updates from usage over time.
- Not a replacement for the existing goal-editing flow — this only
  affects the initial suggested value at first setup.
- No health-conditions-aware tailoring (e.g. medical conditions
  affecting fluid intake) — scoped to the same general-population
  formula generic hydration apps already use, with the same caveats
  those apps carry (not medical advice).

## Proposed approach (high-level)
A static, well-established hydration formula (no model, purely arithmetic
— e.g. a baseline ml/kg-of-bodyweight figure with a fixed adjustment for a
selected climate/activity bucket) computes a suggested daily total from a
few onboarding inputs. That suggested number simply becomes the initial
value pre-filled into the existing `WaterGoal` entity/goal-setting form
at first setup — no new entity or storage mechanism needed, since a
`WaterGoal` already exists and already supports being edited later
through Water's existing goal-history flow. The onboarding step itself
(where age/weight/climate inputs are collected) is the only genuinely new
surface; everything downstream of "here's a suggested number" reuses
existing goal-setting and goal-history machinery unchanged.

## Dependencies & prerequisites
- An onboarding flow/step to collect the small set of inputs (age,
  weight, climate) — if onboarding doesn't yet have a dedicated
  multi-step flow, this may be the first feature to introduce one, or it
  could be folded into Water's existing first-time setup if one exists.
- The existing `WaterGoal` entity and goal-setting form as the
  integration point — no schema changes anticipated.
- Clear copy noting this is a general estimate, not medical guidance,
  given it touches age/weight inputs.

## Open questions for the implementation round
- Which specific formula/constants to use, and does it need unit
  conversion given the existing `WaterUnit` settings enum (ml vs. other
  units already supported)?
- Are age/weight/climate all necessary, or does a simpler two-input
  version (e.g. weight + climate only) capture most of the value with
  less onboarding friction?
- Does this run only at first-ever Water setup, or is it also offered
  later as a "recalculate my suggested goal" option in Settings for an
  existing user whose weight/climate has changed?
- Should the climate input be a manual picker, or could it default from
  the device's locale/region as a starting guess the user can override?

## Effort & sequencing notes
Complexity S — the formula itself is trivial; the only real work is the
onboarding UI for collecting the few inputs, and deciding whether that
onboarding step already exists or needs to be introduced. Retention
impact is Low since it's a one-time first-impression improvement rather
than an ongoing engagement driver, so it's reasonable to sequence
whenever onboarding work is otherwise being touched rather than as a
standalone push.

---

## Implementation Plan (Low-Level)

### Schema changes

No new Drift tables or columns. The suggestion pre-fills the existing
`WaterGoal` entity via `WaterRepository.setGoal()`. The user's inputs
(age, weight, climate) are not persisted — they're used once to compute
the suggestion, then discarded. If the user later wants to recalculate,
they re-enter the inputs.

### Domain entities

**New file:** `lib/features/water/domain/entities/water_goal_suggestion.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'water_goal_suggestion.freezed.dart';

/// The climate bucket used in the hydration formula.
enum ClimateZone {
  /// Cool/moderate climate.
  cool,

  /// Temperate climate.
  temperate,

  /// Hot climate.
  hot,

  /// Very hot / humid climate.
  veryHot,
}

/// Inputs used to compute the water goal suggestion.
@freezed
sealed class WaterGoalInputs with _$WaterGoalInputs {
  const factory WaterGoalInputs({
    required int ageYears,
    required int weightKg,
    required ClimateZone climate,
  }) = _WaterGoalInputs;
}

/// The result of the hydration formula — suggested goal plus the
/// formula breakdown for transparency.
@freezed
sealed class WaterGoalSuggestion with _$WaterGoalSuggestion {
  const factory WaterGoalSuggestion({
    required int suggestedMl,
    required WaterGoalInputs inputs,
    required String formulaDescription,
  }) = _WaterGoalSuggestion;
}
```

### Use case

**New file:** `lib/features/water/domain/usecases/suggest_water_goal.dart`

```dart
import 'package:habit_tracker/features/water/domain/entities/water_goal_suggestion.dart';

/// Computes a suggested daily water goal from basic user inputs.
/// Pure — no repository, no I/O, no side effects.
///
/// Formula: baseline 30-35 ml/kg adjusted by age and climate.
/// This is a general-population heuristic, not medical advice.
class SuggestWaterGoalUseCase {
  const SuggestWaterGoalUseCase();

  /// Returns a [WaterGoalSuggestion] for [inputs].
  WaterGoalSuggestion execute(WaterGoalInputs inputs) {
    // Base: 33 ml per kg of body weight (midpoint of 30-35 range)
    var mlPerKg = 33.0;

    // Age adjustment: children/teens need more per kg, older adults slightly less
    if (inputs.ageYears < 18) {
      mlPerKg = 35.0;
    } else if (inputs.ageYears > 65) {
      mlPerKg = 30.0;
    }

    // Climate adjustment: hot climates increase needs by 12-25%
    final climateFactor = switch (inputs.climate) {
      ClimateZone.cool => 0.90,
      ClimateZone.temperate => 1.0,
      ClimateZone.hot => 1.15,
      ClimateZone.veryHot => 1.25,
    };

    final raw = mlPerKg * inputs.weightKg * climateFactor;

    // Round to nearest 50 ml for a clean, adjustable number
    final suggested = (raw / 50).round() * 50;

    // Clamp to reasonable bounds (1000-5000 ml)
    final clamped = suggested.clamp(1000, 5000);

    return WaterGoalSuggestion(
      suggestedMl: clamped,
      inputs: inputs,
      formulaDescription: _describeFormula(mlPerKg, climateFactor, inputs),
    );
  }

  String _describeFormula(
    double mlPerKg,
    double climateFactor,
    WaterGoalInputs inputs,
  ) {
    // Human-readable description for the onboarding UI, e.g.:
    // "Based on 33 ml × 70 kg × 1.15 (hot climate) ≈ 2680 ml/day"
    final climateLabel = switch (inputs.climate) {
      ClimateZone.cool => 'cool climate',
      ClimateZone.temperate => 'temperate climate',
      ClimateZone.hot => 'hot climate',
      ClimateZone.veryHot => 'very hot climate',
    };
    final base = (mlPerKg * inputs.weightKg).round();
    return '$mlPerKg ml × ${inputs.weightKg} kg × '
        '${climateFactor.toStringAsFixed(2)} ($climateLabel) ≈ '
        '${(mlPerKg * inputs.weightKg * climateFactor).round()} ml/day';
  }
}
```

### Presentation layer

**New file:** `lib/features/water/presentation/screens/water_goal_onboarding_screen.dart`

A single-screen onboarding step shown when the user first sets up Water
(or optionally re-offered in Settings):

```dart
class WaterGoalOnboardingScreen extends ConsumerStatefulWidget {
  const WaterGoalOnboardingScreen({super.key});

  @override
  ConsumerState<WaterGoalOnboardingScreen> createState() =>
      _WaterGoalOnboardingScreenState();
}

class _WaterGoalOnboardingScreenState
    extends ConsumerState<WaterGoalOnboardingScreen> {
  final _weightController = TextEditingController();
  ClimateZone _climate = ClimateZone.temperate;
  int _age = 30;
  WaterGoalSuggestion? _suggestion;

  void _computeSuggestion() {
    final weight = int.tryParse(_weightController.text);
    if (weight == null || weight <= 0) return;
    setState(() {
      _suggestion = SuggestWaterGoalUseCase().execute(
        WaterGoalInputs(
          ageYears: _age,
          weightKg: weight,
          climate: _climate,
        ),
      );
    });
  }

  Future<void> _confirmGoal() async {
    if (_suggestion == null) return;
    await ref.read(waterControllerProvider.notifier).updateGoal(
      _suggestion!.suggestedMl,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.waterOnboardingTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(l10n.waterOnboardingSubtitle),
            const SizedBox(height: 8),
            Text(
              l10n.waterOnboardingDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // Age picker
            Text(l10n.waterOnboardingAgeLabel),
            Slider(
              value: _age.toDouble(),
              min: 10,
              max: 80,
              divisions: 70,
              label: '$_age',
              onChanged: (v) => setState(() => _age = v.round()),
            ),

            // Weight input
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.waterOnboardingWeightLabel,
                suffixText: 'kg',
              ),
              onChanged: (_) => _computeSuggestion(),
            ),

            // Climate picker
            Text(l10n.waterOnboardingClimateLabel),
            SegmentedButton<ClimateZone>(
              segments: [
                ButtonSegment(
                  value: ClimateZone.cool,
                  label: Text(l10n.waterClimateCool),
                ),
                ButtonSegment(
                  value: ClimateZone.temperate,
                  label: Text(l10n.waterClimateTemperate),
                ),
                ButtonSegment(
                  value: ClimateZone.hot,
                  label: Text(l10n.waterClimateHot),
                ),
                ButtonSegment(
                  value: ClimateZone.veryHot,
                  label: Text(l10n.waterClimateVeryHot),
                ),
              ],
              selected: {_climate},
              onSelectionChanged: (s) {
                setState(() => _climate = s.first);
                _computeSuggestion();
              },
            ),

            const SizedBox(height: 24),

            // Suggestion result
            if (_suggestion != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waterOnboardingSuggestedGoal(
                          _suggestion!.suggestedMl,
                        ),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _suggestion!.formulaDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirmGoal,
                child: Text(l10n.waterOnboardingConfirmGoal),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.waterOnboardingSkip),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Modify:** `lib/features/water/presentation/screens/water_settings_screen.dart`

Add a "Recalculate goal" button that navigates to the onboarding screen:

```dart
ListTile(
  title: Text(l10n.waterSettingsRecalculateGoal),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/water/goal-onboarding'),
),
```

**Modify:** `lib/core/router/app_router.dart`

Add route under the Water branch:

```dart
GoRoute(
  path: 'goal-onboarding',
  builder: (context, state) => const WaterGoalOnboardingScreen(),
),
```

**Modify:** `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`

Keys:
- `waterOnboardingTitle` — "Set Your Water Goal"
- `waterOnboardingSubtitle` — "Tell us a bit about yourself for a personalized starting goal."
- `waterOnboardingDisclaimer` — "This is a general estimate based on common hydration guidelines. It is not medical advice. You can adjust your goal anytime."
- `waterOnboardingAgeLabel` — "Your age"
- `waterOnboardingWeightLabel` — "Your weight"
- `waterOnboardingClimateLabel` — "Your climate"
- `waterClimateCool` — "Cool"
- `waterClimateTemperate` — "Temperate"
- `waterClimateHot` — "Hot"
- `waterClimateVeryHot` — "Very Hot"
- `waterOnboardingSuggestedGoal` — "Suggested: {amount} ml/day"
- `waterOnboardingConfirmGoal` — "Use this goal"
- `waterOnboardingSkip` — "Skip — use default"
- `waterSettingsRecalculateGoal` — "Recalculate suggested goal"

### Integration point

The onboarding screen calls `WaterController.updateGoal(suggestedMl)`,
which delegates to `WaterRepository.setGoal(goalMl, effectiveFrom: now)`.
This is the exact same path the existing goal-setting flow uses — no new
repository method needed.

The `_ensureGoalSeeded()` in `WaterRepositoryImpl` creates a default
2000 ml goal on first access. The onboarding screen overwrites this
with the computed suggestion. If the user skips, the 2000 ml default
stands.

### Testing strategy

| Test file | What it covers |
|---|---|
| `test/features/water/domain/usecases/suggest_water_goal_test.dart` | Unit: formula with various age/weight/climate combos. Verify ml/kg baseline, age adjustments, climate factors, 50ml rounding, 1000-5000 clamping. Pure, no mocks. |
| `test/features/water/domain/entities/water_goal_suggestion_test.dart` | Freezed entity construction, equality, copyWith. |
| `test/features/water/domain/entities/water_goal_inputs_test.dart` | Freezed entity construction with all ClimateZone values. |
| `test/features/water/presentation/screens/water_goal_onboarding_screen_test.dart` | Widget: age slider updates, weight input triggers suggestion, climate toggle changes suggestion, confirm button calls controller, skip button pops. |

### File paths

**Files to create:**
- `lib/features/water/domain/entities/water_goal_suggestion.dart`
- `lib/features/water/domain/usecases/suggest_water_goal.dart`
- `lib/features/water/presentation/screens/water_goal_onboarding_screen.dart`

**Files to modify:**
- `lib/features/water/presentation/screens/water_settings_screen.dart` — add recalculate button
- `lib/core/router/app_router.dart` — add goal-onboarding route
- `lib/core/l10n/app_en.arb` — add onboarding localization keys
- `lib/core/l10n/app_bn.arb` — add onboarding localization keys

### Sequencing

| # | Task | Depends on | Effort |
|---|---|---|---|
| T1 | `WaterGoalInputs` + `WaterGoalSuggestion` entities | — | S |
| T2 | `SuggestWaterGoalUseCase` + formula unit tests | T1 | S |
| T3 | `WaterGoalOnboardingScreen` UI | T1, T2 | M |
| T4 | Route registration + settings "Recalculate" button | T3 | S |
| T5 | Localization keys (en + bn) | — | S |
| T6 | Widget tests for onboarding screen | T3, T5 | S |

**Total estimated effort:** S (matching atlas complexity). The formula
is trivial arithmetic. The only real work is the onboarding screen UI
(T3), which is a straightforward form with a slider, text field,
segmented button, and a result card. Everything else is small.

### Open items to resolve before implementation

1. **Onboarding trigger:** Does this screen appear only at first Water
   setup (before any goal is set), or also as a recalculate option in
   Settings for existing users? The plan supports both — the screen is
   route-accessible from anywhere.
2. **Weight unit:** The plan assumes kg. If the app later supports lbs
   display (via `WaterUnit`), the onboarding screen should accept the
   user's preferred unit and convert internally. For v1, kg-only is
   sufficient given the target audience (Bangladesh market, metric
   default).
3. **Default climate from locale:** Could auto-select `ClimateZone.hot`
   for Bangla locale as a starting guess. Minor enhancement, not
   blocking.
