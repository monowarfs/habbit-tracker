# Duplicate/Interaction Name Warning — Implementation Plan

**Spec:** [06-duplicate-interaction-name-warning-design.md](06-duplicate-interaction-name-warning-design.md)
**Run:** TBD
**Estimated effort:** L (dominated by dataset sourcing/review; code is M)
**Dependencies:** Medicine module complete (`medicines` table, `MedicineFormScreen`, `MedicineRepository`), `flutter/services.dart` for asset loading, Freezed codegen, `flutter gen-l10n`.

## Pre-requisites

- Medicine module's add/edit form (`MedicineFormScreen`) exists and has a `_DetailsStep` with a name `TextField`.
- `MedicineRepository` provides `allMedicines()` returning active medicines.
- `assets/` directory exists at project root.
- `build_runner build` and `flutter gen-l10n` run clean.
- **Critical:** Medical/legal review of the bundled dataset content is complete before T2–T10 begin. The dataset is health-adjacent content and must be vetted.

## Tasks

### Task 1: Source and vet the bundled dataset (medical/legal review)
**Effort:** L
**Files to create:** (none yet)
**Files to modify:** (none)
**Description:** Compile a small, well-vetted dataset of:
1. **Duplicate groups:** Common brand/generic name pairs (e.g. Paracetamol/Tylenol/Panadol, Ibuprofen/Advil/Motrin).
2. **Interactions:** A short list of well-established interacting pairs (e.g. Warfarin + Aspirin, Metformin + Alcohol).

Each entry needs: a generic name or pair, aliases/brands, severity (`info` for duplicates, `warning` for interactions), and a brief description. The dataset must go through medical and legal review before implementation begins on the remaining tasks.

**Acceptance criteria:**
- Dataset covers at least 5 duplicate groups and 5 interaction pairs.
- All entries reviewed by a qualified person.
- Disclaimer language approved.

**Test:** N/A (human review gate).

---

### Task 2: Create `medicine_interactions.json` asset
**Effort:** S
**Files to create:**
- `assets/data/medicine_interactions.json`

**Files to modify:** (none)
**Description:** Create the JSON asset file with the structure:
```json
{
  "version": "1.0.0",
  "lastUpdated": "YYYY-MM-DD",
  "disclaimer": "This dataset is for informational purposes only. Always consult a pharmacist or doctor.",
  "duplicateGroups": [
    {
      "id": "dg_001",
      "genericName": "Paracetamol",
      "aliases": ["Acetaminophen", "Tylenol", "Panadol", "Calpol"],
      "severity": "info"
    }
  ],
  "interactions": [
    {
      "id": "int_001",
      "pair": ["Warfarin", "Aspirin"],
      "severity": "warning",
      "description": "Increased bleeding risk when taken together."
    }
  ]
}
```

**Acceptance criteria:**
- Valid JSON with all required fields.
- `version` string is present.
- No duplicate group IDs or interaction IDs.
- All severity values are `info` or `warning`.

**Test:** JSON validates with `dart:convert` decode.

---

### Task 3: Add asset to `pubspec.yaml`
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `pubspec.yaml`

**Description:** Add under `flutter: assets:`:
```yaml
flutter:
  assets:
    - assets/data/medicine_interactions.json
```

**Acceptance criteria:**
- `flutter pub get` succeeds.
- `flutter run` can load the asset.

**Test:** `flutter pub get` succeeds without errors.

---

### Task 4: Create `MedicineInteraction` entity + Freezed class
**Effort:** S
**Files to create:**
- `lib/features/medicine/domain/entities/medicine_interaction.dart`

**Files to modify:** (none)
**Description:** Create the domain entity with:
- `MedicineInteractionType` enum: `duplicate`, `interaction`.
- `MedicineInteractionSeverity` enum: `info`, `warning`.
- `@freezed` `MedicineInteraction` class with fields: `type`, `severity`, `medicineName`, `matchedName`, `description`.

Run `build_runner build --delete-conflicting-outputs`.

**Acceptance criteria:**
- Entity compiles after codegen.
- Enums cover all expected variants.

**Test:** `build_runner build` succeeds.

---

### Task 5: Create `CheckMedicineInteractionsUseCase` + unit tests
**Effort:** M
**Files to create:**
- `lib/features/medicine/domain/usecases/check_medicine_interactions.dart`
- `test/features/medicine/domain/usecases/check_medicine_interactions_test.dart`

**Files to modify:** (none)
**Description:** Implement the use case:
1. Load the bundled JSON asset (cached after first load via a static field).
2. Parse into `duplicateGroups` and `interactions` structures.
3. **Duplicate check:** For each group, check if `candidateName` (normalized: trimmed, lowercase) matches any alias. If yes, check if any other alias in the group matches an active medicine's name (excluding `excludeMedicineId`). Emit `MedicineInteraction(type: duplicate, ...)`.
4. **Interaction check:** For each pair, check if `candidateName` matches one side and an active medicine matches the other. Emit `MedicineInteraction(type: interaction, ...)`.
5. Return all matches.

Asset loading uses `rootBundle.loadString('assets/data/medicine_interactions.json')`. The `Future` is cached in a static field.

Write tests:
1. Candidate matches duplicate group, active medicine matches different alias → `duplicate`
2. Candidate matches interaction pair, active medicine matches other → `interaction`
3. Candidate matches but no active medicine matches → empty list
4. `excludeMedicineId` prevents self-matching
5. Case-insensitive matching
6. Whitespace trimming
7. Candidate matches both duplicate and interaction → both returned
8. Empty active medicines list → empty result
9. Empty candidate name → empty result
10. Very long candidate name → empty result

**Acceptance criteria:**
- Use case compiles.
- All 10 test cases pass.
- Asset loading is cached (not re-loaded per call).

**Test:** `flutter test test/features/medicine/domain/usecases/check_medicine_interactions_test.dart`

---

### Task 6: Create dataset validation test
**Effort:** S
**Files to create:**
- `test/features/medicine/domain/usecases/medicine_interactions_dataset_test.dart`

**Files to modify:** (none)
**Description:** Write a test that loads the bundled JSON asset and validates:
1. JSON structure parses without error.
2. No duplicate group IDs.
3. No duplicate interaction IDs.
4. All severity values are valid enum values (`info`/`warning`).
5. Version string is present and non-empty.
6. Every duplicate group has at least 2 aliases.
7. Every interaction pair has exactly 2 entries.
8. No interaction pair where both sides are in the same duplicate group (redundant).

**Acceptance criteria:**
- Test passes with the current dataset.
- Fails if any structural invariant is violated.

**Test:** `flutter test test/features/medicine/domain/usecases/medicine_interactions_dataset_test.dart`

---

### Task 7: Add `checkMedicineInteractionsProvider`
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/medicine/presentation/providers/medicine_providers.dart`

**Description:** Add a `@riverpod` provider:
```dart
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

**Acceptance criteria:**
- Provider compiles after codegen.
- Returns a valid `List<MedicineInteraction>` (empty or non-empty).
- Handles loading/error states via `AsyncValue`.

**Test:** `flutter analyze` passes.

---

### Task 8: Create `MedicineInteractionBanner` widget
**Effort:** S
**Files to create:**
- `lib/features/medicine/presentation/widgets/medicine_interaction_banner.dart`

**Files to modify:** (none)
**Description:** Create a `ConsumerWidget` that:
1. Takes `name` (String) and optional `excludeMedicineId` (String?).
2. If `name.trim().length < 3`, returns `SizedBox.shrink()`.
3. Watches `checkMedicineInteractionsProvider(name: name, excludeMedicineId: excludeMedicineId)`.
4. If interactions list is empty or still loading, returns `SizedBox.shrink()`.
5. Otherwise renders a dismissible warning banner:
   - `info` severity: `Info` icon + light blue background + "This may be the same as {medicine}."
   - `warning` severity: `Warning` icon + light amber background + "This may interact with {medicine}. Consult your pharmacist."
   - Dismissible via X button (local `_isDismissed` state — reappears on next edit if condition persists).

**Acceptance criteria:**
- Banner renders when a match is found.
- Banner dismisses locally (state resets when screen is re-entered).
- `SizedBox.shrink()` for no-match and short-name cases.
- Uses `AppLocalizations` for all user-facing strings.

**Test:** `flutter analyze` passes.

---

### Task 9: Integrate banner into `MedicineFormScreen`
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/medicine/presentation/screens/medicine_form_screen.dart`

**Description:** In `_DetailsStep`, after the name `TextField`, add:
```dart
MedicineInteractionBanner(
  name: nameController.text,
  excludeMedicineId: excludeMedicineId,
)
```

Pass `excludeMedicineId` from `MedicineFormScreen.editMedicineId` (when editing, exclude the current medicine from interaction checks). Wrap the banner in a `ValueListenableBuilder` on `nameController` so it reactively updates as the user types.

**Acceptance criteria:**
- Banner appears below the name field as user types.
- Banner disappears when name is cleared or changed to non-matching.
- When editing, the current medicine doesn't trigger a self-match.
- No visual regression in the existing form layout.

**Test:** `flutter analyze` passes; manual smoke test of add/edit flows.

---

### Task 10: Add localization strings (en/bn)
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:** Add ARB keys:

### `app_en.arb`
| Key | Value |
|-----|-------|
| `medicineInteractionDuplicateTitle` | `"Possible duplicate"` |
| `medicineInteractionDuplicateBody` | `"This may be the same active ingredient as {medicine}."` |
| `medicineInteractionWarningTitle` | `"Possible interaction"` |
| `medicineInteractionWarningBody` | `"This may interact with {medicine}. Consult your pharmacist."` |
| `medicineInteractionDisclaimer` | `"This is informational only — always consult a healthcare professional."` |

### `app_bn.arb`
Bangla equivalents for all keys above.

Run `flutter gen-l10n` after editing.

**Acceptance criteria:**
- `flutter gen-l10n` produces valid output with no missing keys.
- All keys have both en and bn translations.
- `{medicine}` placeholder present in body strings.

**Test:** `flutter gen-l10n` succeeds; `flutter analyze` passes.

---

## Schema Migration

**No schema changes.** This feature reads existing `medicines` table only. The bundled dataset is an app asset, not a database table.

## Localization Keys

See Task 10 above for the full list.

## Risk Notes

- **Dataset staleness:** The bundled JSON is static — it will go stale as new brand names and interactions emerge. The `version` field enables future app updates to refresh the dataset. Consider a "last updated" display in the settings or a banner if the dataset is >6 months old.
- **Medical/legal review gate:** Task 1 is a hard prerequisite for Tasks 2–10. Do not proceed with implementation until the dataset content and disclaimer language have been reviewed. This is a product/legal decision, not an engineering one.
- **False positives:** The matching is case-insensitive string comparison against a small, curated dataset. False positives are unlikely with the current approach (exact alias matches), but if fuzzy matching is added later, false-positive risk increases.
- **Non-blocking warning:** The banner is dismissible and non-blocking — it does not prevent the user from saving the medicine. This is intentional: a blocking UX would train users to reflexively dismiss safety warnings.
- **Asset loading in background isolate:** If the use case is ever called from a background context (unlikely for this feature, but worth noting), `rootBundle.loadString` won't work outside the main isolate. The current use case is only called from the presentation layer, so this is fine.
- **`assets/data/` directory:** Ensure the `assets/data/` directory is created before adding the JSON file. The `pubspec.yaml` asset entry must match the actual path.
