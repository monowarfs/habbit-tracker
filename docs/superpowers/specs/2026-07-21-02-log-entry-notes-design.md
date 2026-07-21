# Log Entry Notes — Free-Text Notes on Water/Medicine/Prayer Logs

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis flags **notes/free-text on any log entry**
("felt dizzy after this dose") as a Must-Have, Complexity-S gap inspired by
TickTick/Streaks. Today none of the three loggable-entity tables
(`water_logs`, `medicine_doses`, `prayer_records`) has anywhere to put
free text — `Medicine.dosageNote` exists, but that's a per-*medicine*
label ("take with food"), not a per-*dose-instance* log note, and neither
Water nor Prayer has any free-text field anywhere in their schema. Users
have no way to annotate an individual log ("skipped dose — felt nauseous",
"drank extra because of the heat", "prayed at the office instead of
home").

## Design

**One nullable `TEXT notes` column per log table**, following this
session's own `biometric_enabled`/`screen_privacy_enabled` precedent
(`docs/superpowers/specs/2026-07-21-pin-lock-toggles-fix-design.md`):
schema bump + `m.addColumn` per column, domain entity gains the field,
repository read/write paths plumb it through, backup export/import
round-trips it.

### Schema

- `water_logs.notes` — nullable `TEXT`.
- `medicine_doses.notes` — nullable `TEXT`.
- `prayer_records.notes` — nullable `TEXT`.
- `schemaVersion` → `4`; `onUpgrade`'s existing `if (from < N)` seam
  (`app_database.dart:81-83`) gets an `if (from < 4)` block with three
  `m.addColumn(...)` calls — `waterLogsTable.notes`,
  `medicineDosesTable.notes`, `prayerRecordsTable.notes` — same shape as
  the `if (from < 3)` block immediately above it.

No new table, no index — notes are never queried/filtered on in this
round (see Out of scope), so there's nothing to index.

### Domain entities

Each entity gains one nullable field, no default needed (nullable already
means "absent" is representable):

- `WaterEntry.notes` (`String?`) — `lib/features/water/domain/entities/water_entry.dart`.
- `MedicineDose.notes` (`String?`) — `lib/features/medicine/domain/entities/medicine_dose.dart`.
- `PrayerRecord.notes` (`String?`) — `lib/features/prayer/domain/entities/prayer_record.dart`.

Freezed regenerates (`dart run build_runner build`) after each change —
no new providers, no codegen-affecting signature beyond the added field.

### Repository plumbing

**Water** (`water_repository_impl.dart`) — notes travel through the two
write paths that already exist, no new method:
- `addEntry({..., String? notes})` — one new optional named param,
  inserted into `WaterLogsTableCompanion.insert(notes: Value(notes))`.
- `updateEntry(id, {..., String? notes})` — same treatment as
  `amountMl`/`loggedAt`'s existing `Value.absent()` "unless specified"
  pattern, so calling `updateEntry` without touching `notes` doesn't
  clobber an existing one.
- `_entryFromRow` reads `row.notes` straight through.

**Medicine** (`medicine_repository_impl.dart`) — doses are materialized,
never manually created, so there's no "add dose" call site to thread
notes through. Notes need their own small write path, independent of
`markDoseDone`/`markDoseSkipped`/`undoDose` — a user should be able to
annotate a dose regardless of its status (before, at, or after marking
it), matching the feature's own example ("felt dizzy after this dose" is
naturally written *after* marking done, but "skipping — feeling sick"
just as naturally happens at skip time or before). New method:
```dart
Future<Result<void>> updateDoseNotes(String doseId, String? notes)
```
implemented via the same `_resolveDose` skeleton the three status actions
already share (`medicine_repository_impl.dart:488-516`), writing just
`notes`/`updatedAt` — no `statusChangedAt` bump, since editing a note is
not a status change. `restoreDose` (the import path) gains a `notes`
param passed straight into the insert. `_doseFromRow` reads `row.notes`.

**Prayer** (`prayer_repository_impl.dart`) — same shape as Medicine, new
method:
```dart
Future<Result<void>> updatePrayerNotes(String recordId, String? notes)
```
via the existing `_resolveRecord` skeleton
(`prayer_repository_impl.dart:434-468`), with `guard: (_) => true` — unlike
`markPrayed`/`markMissedBySkip`, a note is legal to attach/edit in any
status, including `missed` (arguably the single most useful case: "missed
— was in a meeting"). `restoreRecord` gains a `notes` param.
`_recordFromRow` reads `row.notes`.

### UI

**Water** — `WaterAddEntryScreen` (`lib/features/water/presentation/screens/water_add_entry_screen.dart`)
already has a full add/edit form (amount, date/time, save) reused for
both creating a custom entry and editing any existing one (FR-W-09,
including quick-added entries). This is the one natural touchpoint: add
an optional multi-line `TextField` (`maxLength: 500`, 2-3 visible lines)
labeled "Notes" between the existing amount field and the date/time
`ListTile`, wired through `_amountController`'s sibling
`_notesController`, prefilled in `_prefillIfNeeded`, and passed to
`controller.logCustom(..., notes: ...)` / `controller.updateEntry(id, ...,
notes: ...)`. `WaterController`'s `_log`/`updateEntry` methods
(`water_controller.dart:26-66`) gain the pass-through param.

Quick-add (`QuickAddButton`) stays note-free by design — FR-W-03's
contract is "tapping logs immediately, no confirmation dialog," and a
note field would force exactly the dialog step that button exists to
avoid. A user who wants to annotate a quick-added entry taps its
`WaterLogTile` afterward (already wired to `onTap` → the edit screen,
FR-W-09) — the notes field is now there waiting.

**Medicine & Prayer** — neither `DoseTile` nor `PrayerTile` has an
add/edit screen or dialog anywhere in their flow; both are single-tap
timeline rows (mark done/skip, mark prayed). Forcing every dose/prayer
tap through a notes prompt would break that one-tap contract the same
way it would for Water's quick-add. Instead: one small shared bottom
sheet, `core/widgets/note_editor_sheet.dart`:
```dart
Future<String?> showNoteEditorSheet(
  BuildContext context, {
  required String? initialNotes,
})
```
— a `showModalBottomSheet` (precedent: `pin_settings_screen.dart:113`,
`prayer_history_screen.dart:132`) with one multi-line `TextFormField`
(`maxLength: 500`) and a Save button, returning the trimmed text (or
`null` if cleared/cancelled). Both `DoseTile` and `PrayerTile` gain a
small icon button — `Icons.sticky_note_2_outlined` (filled variant,
`Icons.sticky_note_2`, when `notes != null`) — placed in the leading
`CircleAvatar`/title row, that opens the sheet and calls
`medicineController.updateDoseNotes(doseId, result)` /
`prayerController.updatePrayerNotes(recordId, result)`. This keeps the
existing done/skip/prayed tap targets untouched — the note icon is a
fully separate, optional affordance.

**Length limit** — 500 chars, UI-enforced only (`TextField.maxLength`),
same "no DB-level constraint, UI caps input" treatment `Medicine
.dosageNote` already gets (no `CHECK` constraint on that column either).
An empty/whitespace-only note is canonicalized to `null` before saving
(one representation for "no note," not two) — trimmed in each screen's
save handler, not in the repository (matches how `WaterAddEntryScreen`
already does its own amount validation before calling the controller).

### Backup export/import

Notes live in each module's own `exportData()`/`importData()` payload
(`ModuleExport`), **not** in `export_orchestrator.dart`'s/`import
_orchestrator.dart`'s shared `common` block — those two files need **zero
changes**, unlike the PIN-toggle precedent where the field lived on
`AppSettings`. Three module files change:

- `water_module.dart`: `_entryToJson` adds `'notes': entry.notes`;
  `importData`'s `addEntry(...)` call adds
  `notes: json['notes'] as String?`.
- `medicine_module.dart`: `_doseToJson` adds `'notes': dose.notes`;
  `importData`'s `restoreDose(MedicineDose(...))` construction adds
  `notes: json['notes'] as String?`.
- `prayer_module.dart`: `_recordToJson` adds `'notes': record.notes`;
  `importData`'s `restoreRecord(PrayerRecord(...))` construction adds
  `notes: json['notes'] as String?`.

No `??` fallback needed (unlike `biometricEnabled`/`screenPrivacyEnabled`
in the PIN spec): those were non-nullable `bool`s where a missing JSON
key is ambiguous, so they needed an explicit default. `notes` is nullable
end-to-end — a JSON map lookup on a missing key already evaluates to
`null` in Dart, which *is* "no note," so an older backup missing the
`notes` key imports correctly with zero special-casing. `_migrations`
(`import_orchestrator.dart:18-19`) needs no new entry — this isn't an
envelope schema-version bump, just an additive, backward-compatible key
inside each module's own payload map.

### Localization

New strings in `app_en.arb`/`app_bn.arb`: a notes field label (e.g.
`waterAddEntryNotesLabel`), the bottom sheet's title/hint text for
Medicine and Prayer (can share one generic pair, e.g.
`logNotesSheetTitle`/`logNotesSheetHint`, under a shared key rather than
three near-duplicate module-prefixed ones — there's no per-module wording
difference to justify separate keys). Save button reuses the existing
`commonSave`.

## Out of scope

- **Search/filter by note text** — Run 15's cross-module `search()`
  (CLAUDE.md) searches each module's existing structured fields; wiring
  notes into that search index is a reasonable follow-up but adds scope
  beyond a Complexity-S column-plus-plumbing feature.
- **Rich text or attachments** — plain text only, matching
  `Medicine.dosageNote`'s existing precedent.
- **Note edit history/audit trail** — the column is overwritten in place,
  same as every other mutable field on these rows (`amountMl`,
  `status`, etc.) — no versioning.
- **A dedicated "add note" step in quick-add flows** — deliberately kept
  out per the UI section above; would reintroduce the confirmation-dialog
  friction FR-W-03 and the dose/prayer one-tap timeline both avoid by
  design.
- **DB-level length constraint** — 500 chars is a UI affordance only, not
  enforced by a `CHECK` constraint, consistent with how `dosageNote` is
  already handled.
- **Achievements/streak interaction** — notes are inert with respect to
  `core/achievements/` and `core/reports/`; nothing about a dose/prayer/
  water day's completion status changes based on whether a note is
  present.

## Global Constraints

- New DB columns: `notes` (nullable `TEXT`) on `water_logs`,
  `medicine_doses`, `prayer_records`.
- `schemaVersion` → `4`, migrated via three `m.addColumn` calls under one
  `if (from < 4)` block.
- New repository methods: `MedicineRepository.updateDoseNotes(doseId,
  notes)`, `PrayerRepository.updatePrayerNotes(recordId, notes)` — both
  status-independent (no `guard`/no `statusChangedAt` bump). Water reuses
  its existing `addEntry`/`updateEntry` with one new optional param each.
- UI cap: 500 chars, UI-only (`TextField.maxLength`), empty/whitespace
  canonicalized to `null` before persisting.
- Quick-add (Water) and one-tap done/skip/prayed toggles (Medicine/
  Prayer) remain note-free single-tap actions; notes are added via a
  separate, optional affordance (Water's existing edit screen; a new
  shared `note_editor_sheet.dart` bottom sheet for Medicine/Prayer).
- Backup: `notes` added to each module's own `exportData()`/
  `importData()` payload only — `export_orchestrator.dart`/
  `import_orchestrator.dart` and `BackupEnvelope`'s `common` block are
  untouched; no `_migrations` entry needed (nullable field, absent key
  already means `null`).
