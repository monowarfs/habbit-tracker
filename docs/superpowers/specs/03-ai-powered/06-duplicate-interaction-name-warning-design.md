# Duplicate/Interaction Name Warning

**Category:** AI-Powered · **Atlas complexity:** L · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A user managing multiple medicines (or a caregiver managing them on
someone's behalf) has no signal today if two active medicines they've
entered happen to be a common brand/generic pairing (e.g. adding both a
brand-name and its generic equivalent without realizing they're the same
active ingredient) or a well-known interacting pair. Medisafe ships a
live drug-interaction check backed by a maintained external database;
this app's offline-first, no-account, no-network posture rules that
architecture out, but a small bundled reference table covering the most
common, well-established pairings is still a meaningful safety net
without compromising the app's trust story.

## Goals
- Warn the user, at the point of adding/editing a medicine, if its
  name matches a known brand/generic duplicate or a well-documented
  interacting pair already present among their other active medicines.
- Keep the warning clearly scoped as informational, not medical advice —
  point the user to consult a pharmacist/doctor, never assert a
  diagnosis or dosing recommendation.
- Ship with a bundled, offline dataset covering a deliberately small,
  well-vetted set of common pairings rather than attempting broad
  coverage.

## Non-goals / out of scope
- No live drug-interaction API call of any kind — this stays fully
  offline, matching the app's no-network trust story.
- Not a comprehensive interaction-checking feature — the atlas explicitly
  scopes this as a bundled reference table, not a substitute for a
  pharmacist consultation or a full drug-interaction database.
- No attempt to cover every medicine name/spelling variant, dosage-form
  interaction nuance, or non-common-pairing edge case in the first pass.

## Proposed approach (high-level)
A small bundled dataset (shipped as an app asset, similar in spirit to
Prayer's bundled city dataset) maps known brand names to generic
equivalents and lists a short set of well-established interacting name
pairs. When a medicine is added or edited, MedicineModule checks the new
name against the user's other currently-active medicines using simple
string/alias matching against this bundled table — no external call, no
inference beyond table lookup. A match surfaces as a dismissible warning
banner on the add/edit form, worded carefully as an informational flag
("these are commonly the same/interacting medicine — check with your
pharmacist") rather than a diagnosis. This is squarely a data/content
problem more than a code problem: the bulk of the effort is compiling
and vetting the bundled dataset, not the matching logic itself.

## Dependencies & prerequisites
- A vetted, bundled interaction/duplicate-name dataset — this requires
  legal/medical review before shipping, given it's health-adjacent
  content presented to users making real medication decisions.
- A clear, reviewed disclaimer/copy treatment so the warning can't be
  misread as medical advice.
- MedicineModule's existing add/edit flow as the integration point.

## Open questions for the implementation round
- Who sources and vets the bundled dataset, and what's the process for
  keeping it accurate/updated across app releases (a static asset can go
  stale)?
- What's the legal review bar for shipping any health-adjacent warning
  content, even clearly caveated as informational?
- Does the warning block adding the medicine (requiring explicit
  acknowledgment) or just display non-blocking, given the risk of
  training users to reflexively dismiss safety warnings?
- Should this cover only exact/near-exact name matches, or attempt
  fuzzy matching against common misspellings/brand variants — the latter
  meaningfully increases both matching complexity and false-positive risk.

## Effort & sequencing notes
Complexity L — despite simple matching logic, the dataset-sourcing and
legal/medical review requirements make this the heaviest-effort item in
the category, and retention impact is Low since it's a safety/trust
feature rather than an engagement driver. Reasonable to sequence last
among the on-device items, pending a decision on whether the legal review
overhead is worth taking on at all for a first cut.

## Implementation Plan (Low-Level)

### Schema changes

**No new Drift tables.** This feature reads existing data only:

- `medicines` — to check the new name against currently active
  (non-archived) medicines.
- The bundled asset dataset (shipped as an app asset, not a DB table).

### Bundled asset dataset

**File:** `assets/data/medicine_interactions.json`

```json
{
  "version": "1.0.0",
  "lastUpdated": "2026-07-23",
  "disclaimer": "This dataset is for informational purposes only. Always consult a pharmacist or doctor.",
  "duplicateGroups": [
    {
      "id": "dg_001",
      "genericName": "Paracetamol",
      "aliases": ["Acetaminophen", "Tylenol", "Panadol", "Calpol"],
      "severity": "info"
    },
    {
      "id": "dg_002",
      "genericName": "Ibuprofen",
      "aliases": ["Advil", "Motrin", "Brufen"],
      "severity": "info"
    }
  ],
  "interactions": [
    {
      "id": "int_001",
      "pair": ["Warfarin", "Aspirin"],
      "severity": "warning",
      "description": "Increased bleeding risk when taken together."
    },
    {
      "id": "int_002",
      "pair": ["Metformin", "Alcohol"],
      "severity": "warning",
      "description": "Alcohol increases the risk of lactic acidosis with Metformin."
    }
  ]
}
```

**Design decisions:**
- JSON format (not CSV) for nested structure and readability.
- `duplicateGroups`: brand/generic aliases mapped to a single
  `genericName`. A match triggers when the user's input name matches any
  alias in a group that also contains another alias matching an existing
  active medicine.
- `interactions`: explicit pairs. Match triggers when both names in a
  pair match active medicines (case-insensitive, trimmed).
- `severity`: `info` (duplicate) or `warning` (interaction). Controls
  banner color/icon.
- `version` field for future dataset updates across app releases.

**pubspec.yaml addition:**

```yaml
flutter:
  assets:
    - assets/data/medicine_interactions.json
```

### Domain entities

**File:** `lib/features/medicine/domain/entities/medicine_interaction.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine_interaction.freezed.dart';

/// Type of medicine name match detected.
enum MedicineInteractionType {
  /// Two active medicines are the same active ingredient (brand/generic
  /// duplicate).
  duplicate,

  /// Two active medicines have a well-documented interaction.
  interaction,
}

/// Severity of a detected medicine name warning.
enum MedicineInteractionSeverity {
  /// Informational — likely a duplicate.
  info,

  /// Warning — known interaction, recommend consulting a pharmacist.
  warning,
}

/// A detected medicine name duplicate or interaction.
@freezed
sealed class MedicineInteraction with _$MedicineInteraction {
  /// Creates a medicine interaction warning.
  const factory MedicineInteraction({
    required MedicineInteractionType type,
    required MedicineInteractionSeverity severity,
    required String medicineName,
    required String matchedName,
    required String description,
  }) = _MedicineInteraction;
}
```

### Use case signatures

**File:** `lib/features/medicine/domain/usecases/check_medicine_interactions.dart`

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_interaction.dart';

/// Loads and queries the bundled medicine interaction dataset.
///
/// Pure logic — the asset loading is a one-time future, and the matching
/// is synchronous string comparison.
class CheckMedicineInteractionsUseCase {
  /// Creates the use case.
  const CheckMedicineInteractionsUseCase();

  /// Checks [candidateName] against the bundled dataset and the user's
  /// [activeMedicines] (excluding [excludeMedicineId] when editing).
  ///
  /// Returns an empty list if no matches are found.
  Future<List<MedicineInteraction>> execute({
    required String candidateName,
    required List<Medicine> activeMedicines,
    String? excludeMedicineId,
  });
}
```

**Key logic:**
1. Load the bundled JSON asset (cached after first load).
2. Normalize `candidateName`: trim, lowercase.
3. **Duplicate check:** For each `duplicateGroup`, check if
   `candidateName` matches any alias in the group. If yes, check if any
   other alias in the same group matches an active medicine's name
   (excluding `excludeMedicineId`). If so, emit a `duplicate` interaction.
4. **Interaction check:** For each `interactions` pair, check if
   `candidateName` matches one side and an active medicine's name matches
   the other side. If so, emit an `interaction` interaction.
5. Return all matches (could be multiple if the name hits both a
   duplicate and an interaction).

**Caching:** The JSON asset is loaded once and cached in a static
field. The asset is small (~5-10 KB) and rarely changes.

### Data layer

No new repository. The use case loads the bundled asset directly (same
pattern as `PrayerCitiesLoader` for the bundled city dataset).

**File to modify:** `lib/features/medicine/presentation/providers/medicine_providers.dart`

Add a Riverpod provider that calls the use case:

```dart
/// Checks for medicine name interactions/duplicates for [name].
@riverpod
Future<List<MedicineInteraction>> checkMedicineInteractions(
  CheckMedicineInteractionsRef ref, {
  required String name,
  String? excludeMedicineId,
}) async {
  final repository = ref.watch(medicineRepositoryProvider);
  final medicines = await repository.allMedicines();
  final activeMedicines = medicines.where((m) => m.archivedAt == null).toList();
  return const CheckMedicineInteractionsUseCase().execute(
    candidateName: name,
    activeMedicines: activeMedicines,
    excludeMedicineId: excludeMedicineId,
  );
}
```

### Presentation layer

**File to modify:** `lib/features/medicine/presentation/screens/medicine_form_screen.dart`

Add a warning banner widget below the name `TextField` in `_DetailsStep`.
The banner appears reactively as the user types (debounced, ~300ms).

```dart
// In _DetailsStep, after the name TextField:
_MedicineInteractionBanner(
  name: nameController.text,
  excludeMedicineId: excludeMedicineId,
)
```

**New widget:** `lib/features/medicine/presentation/widgets/medicine_interaction_banner.dart`

```dart
/// A dismissible warning banner shown when medicine name matches
/// a known duplicate or interaction.
class MedicineInteractionBanner extends ConsumerWidget {
  const MedicineInteractionBanner({
    super.key,
    required this.name,
    this.excludeMedicineId,
  });

  final String name;
  final String? excludeMedicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (name.trim().length < 3) return const SizedBox.shrink();
    final interactionsAsync = ref.watch(
      checkMedicineInteractionsProvider(
        name: name,
        excludeMedicineId: excludeMedicineId,
      ),
    );
    return interactionsAsync.when(
      data: (interactions) {
        if (interactions.isEmpty) return const SizedBox.shrink();
        return _WarningBanner(interactions: interactions);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

The `_WarningBanner` renders:
- `info` severity: `Info` icon + light blue background
- `warning` severity: `Warning` icon + light amber background
- Text: "This may be the same as / interact with {matched medicine}.
  Consult your pharmacist."
- Dismissible via an X button (local state only — reappears on next
  edit if the condition persists).

**Wire into form:** Pass `excludeMedicineId` from
`MedicineFormScreen.editMedicineId` to `_DetailsStep`.

### Localization

**Files to modify:**

- `lib/core/l10n/app_en.arb` — add:
  - `medicineInteractionDuplicateTitle`: "Possible duplicate"
  - `medicineInteractionDuplicateBody`: "This may be the same active ingredient as {medicine}."
  - `medicineInteractionWarningTitle`: "Possible interaction"
  - `medicineInteractionWarningBody`: "This may interact with {medicine}. Consult your pharmacist."
  - `medicineInteractionDisclaimer`: "This is informational only — always consult a healthcare professional."
- `lib/core/l10n/app_bn.arb` — Bangla equivalents.

### Dataset validation

A one-time validation script (or test) ensures the bundled dataset is
well-formed:
- No duplicate group IDs.
- No interaction pair where both sides are in the same duplicate group
  (redundant).
- All severity values are valid enum values.
- Version string is present.

**File:** `test/features/medicine/domain/usecases/medicine_interactions_dataset_test.dart`

### Testing strategy

**New test files:**

1. `test/features/medicine/domain/usecases/check_medicine_interactions_test.dart`
   - Case: candidate matches a duplicate group, another active medicine
     matches a different alias → `duplicate` returned.
   - Case: candidate matches one side of an interaction pair, another
     active medicine matches the other → `interaction` returned.
   - Case: candidate matches but no active medicine matches → empty list.
   - Case: `excludeMedicineId` prevents self-matching.
   - Case: case-insensitive matching ("paracetamol" matches "Paracetamol").
   - Case: whitespace trimming ("  Ibuprofen  " matches "Ibuprofen").
   - Case: candidate matches both a duplicate and an interaction → both
     returned.
   - Case: empty active medicines list → empty result.
   - Edge case: candidate name is empty string → empty result.
   - Edge case: candidate name is very long → empty result (no match).

2. `test/features/medicine/domain/usecases/medicine_interactions_dataset_test.dart`
   - Validates JSON structure.
   - Validates no duplicate IDs.
   - Validates all severity values are valid.

### File paths

**Create:**

- `assets/data/medicine_interactions.json` (bundled dataset)
- `lib/features/medicine/domain/entities/medicine_interaction.dart`
- `lib/features/medicine/domain/entities/medicine_interaction.freezed.dart`
  (generated)
- `lib/features/medicine/domain/usecases/check_medicine_interactions.dart`
- `lib/features/medicine/presentation/widgets/medicine_interaction_banner.dart`
- `test/features/medicine/domain/usecases/check_medicine_interactions_test.dart`
- `test/features/medicine/domain/usecases/medicine_interactions_dataset_test.dart`

**Modify:**

- `pubspec.yaml` — add `assets/data/` to flutter assets
- `lib/features/medicine/presentation/screens/medicine_form_screen.dart` —
  integrate `MedicineInteractionBanner` into `_DetailsStep`
- `lib/features/medicine/presentation/providers/medicine_providers.dart` —
  add `checkMedicineInteractionsProvider`
- `lib/core/l10n/app_en.arb` — add interaction warning strings
- `lib/core/l10n/app_bn.arb` — add interaction warning strings

### Sequencing

| # | Task | Depends on | Effort |
|---|------|------------|--------|
| T1 | Source and vet the bundled dataset (medical/legal review) | — | L |
| T2 | Create `medicine_interactions.json` asset | T1 | S |
| T3 | Add asset to `pubspec.yaml` | T2 | S |
| T4 | Create `MedicineInteraction` entity + freezed | — | S |
| T5 | Create `CheckMedicineInteractionsUseCase` + unit tests | T3, T4 | M |
| T6 | Create dataset validation test | T3 | S |
| T7 | Add `checkMedicineInteractionsProvider` | T5 | S |
| T8 | Create `MedicineInteractionBanner` widget | T7 | S |
| T9 | Integrate banner into `MedicineFormScreen` | T8 | S |
| T10 | Add localization strings (en/bn) | — | S |

**Total effort: L** — dominated by T1 (dataset sourcing and medical/legal
review). The code implementation (T2–T10) is M, but the dataset
compilation and review gate make this L overall.

**Critical dependency:** T1 requires a decision on who sources and vets
the dataset, and the legal review bar for shipping health-adjacent
warning content. This is a product/legal decision, not an engineering
one, and should be resolved before engineering begins on T2–T10.
