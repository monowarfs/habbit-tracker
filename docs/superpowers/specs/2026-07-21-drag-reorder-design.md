# Drag-to-Reorder for the Medicine List

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis lists "drag-to-reorder habits/medicines"
(manual priority order for list displays) as Must-Have, complexity S, deps
"a `sort_order` column, `ReorderableListView`" — inspired by Habitica/
TickTick. Before designing it, this spec surveys every module for a list
that's actually (a) multiple independent user-created items and (b) shown
in a single scrollable list where order is a user preference, not derived
from something else (time, religious convention, a fixed enum).

**Medicine — the one real fit.** `MedicineListScreen`
(`lib/features/medicine/presentation/screens/medicine_list_screen.dart`)
renders every medicine (active/archived tabs) as a plain `ListView` of
`ListTile`s, backed by `medicinesProvider(includeArchived: ...)` →
`MedicineRepositoryImpl.watchMedicines()`
(`lib/features/medicine/data/repositories/medicine_repository_impl.dart:32`).
That query has **no `orderBy` at all** — rows come back in whatever order
SQLite happens to return them (in practice insertion/rowid order, but nothing
in the schema guarantees it). `MedicinesTable`
(`lib/features/medicine/data/tables/medicines_table.dart`) has no ordering
column today. This is exactly the "multiple medicines, each independent"
collection the Atlas item describes, and it's the only list in the app with
that shape.

**Water — doesn't apply, and don't add the mechanism there.** Water is a
single goal/log per day, not a list of user items. The nearest thing to an
orderable list is `WaterSettings.quickAddAmountsMl`
(`lib/features/water/domain/entities/water_settings.dart`), a `List<int>` of
preset amounts — but it's stored as one JSON-encoded `TextColumn` on the
singleton `water_settings` row (`quickAddAmountsMl` in
`water_settings_table.dart`), not one row per preset. It is *already* an
ordered list; reordering it is a matter of splicing the Dart `List<int>` and
calling the existing `updateQuickAddAmounts()` — no `sort_order` column,
because there's no per-item row to hang one on. That's a much smaller,
different change than what this spec covers, and the Atlas item's stated
deps (a `sort_order` column) don't fit it. Not designed here.

**Prayer — explicitly excluded.** The five daily prayers are a fixed
`PrayerName` enum (`lib/features/prayer/domain/entities/prayer_record.dart`),
always shown in canonical chronological order (Fajr → Dhuhr → Asr → Maghrib
→ Isha) because that order is dictated by prayer time, not user taste.
Letting a user drag Isha above Fajr would be actively wrong. No reorder
affordance belongs here.

**Dashboard module order — a different, larger feature; excluded.**
`habitModulesProvider` → `buildHabitModules()`
(`lib/core/modules/module_registry.dart`) returns a hardcoded
`[MedicineModule, WaterModule, PrayerModule]` list consumed by both the
dashboard's summary-card stack and the bottom-nav `StatefulShellRoute`
branches. Making that user-orderable would mean a new single `AppSettings`
preference (an ordered list of module ids, same shape as Water's
`quickAddAmountsMl` — no per-row `sort_order`) and a decision about whether
bottom-nav tab order should follow dashboard card order or stay fixed. That's
a real but separate feature with its own tradeoffs; out of scope for this S
spec, which is scoped to the one item the Atlas dependency list actually
describes (a `sort_order` column on a table of user-created rows).

## Design

**New column** — `MedicinesTable` gains:

```dart
/// Manual display order (lower sorts first). Set on create to
/// max(existing sortOrder) + 1; updated in bulk by drag-to-reorder.
IntColumn get sortOrder => integer().withDefault(const Constant(0))();
```

**Migration** — `schemaVersion` bumps `3` → `4`. Following the existing
`if (from < N)` seam at `app_database.dart:70-84`:

```dart
if (from < 4) {
  await m.addColumn(medicinesTable, medicinesTable.sortOrder);
  // Backfill: preserve today's de-facto order (createdAt ascending,
  // the same order the un-ordered query happened to return in practice)
  // instead of leaving every existing row tied at 0, which would look
  // like a random shuffle to an upgrading user.
  final existing = await (select(medicinesTable)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();
  for (var i = 0; i < existing.length; i++) {
    await (update(medicinesTable)
          ..where((t) => t.id.equals(existing[i].id)))
        .write(MedicinesTableCompanion(sortOrder: Value(i)));
  }
}
```

(`this` inside the `migration` getter's closure is the `AppDatabase`
instance itself — same access `select`/`update` calls elsewhere in the
codebase use — so no extra plumbing is needed to run the backfill query.)

**Domain entity** — `Medicine` (`lib/features/medicine/domain/entities/
medicine.dart`) gains `@Default(0) int sortOrder`. `_medicineFromRow`/
`_medicineToJson` in `medicine_repository_impl.dart` and
`medicine_module.dart` map the new field through (export/import round-trips
it like every other column — no orchestrator changes needed since Medicine's
`exportData`/`importData` are self-contained in `medicine_module.dart`).

**Query order** — `watchMedicines()` gets an `orderBy`:

```dart
final query = _db.select(_db.medicinesTable)
  ..where((t) => t.deletedAt.isNull())
  ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
```

**Create appends to the end** — `createMedicine()` currently doesn't set
`sortOrder`, so it would default to `0` and jump to the top. Fix: compute
`max(existing sortOrder) + 1` before inserting (one extra `SELECT
MAX(sort_order)` on the same table, cheap for a per-user medicine list that
is realistically single/low-digit rows) and pass it into the
`MedicinesTableCompanion.insert(...)`. Archived medicines count too (their
`sortOrder` doesn't change on archive, so un-archiving restores them where
they were, not at the end).

**Reorder — a new repository method:**

```dart
// MedicineRepository
Future<Result<void>> reorderMedicines(List<String> orderedIds);
```

Implementation is a single write pass, `sortOrder = orderedIds.indexOf(id)`
for each id, wrapped in `_db.transaction()` so a drag never leaves the list
half-renumbered if one write fails partway through. `updatedAt` is *not*
bumped by a pure reorder — it's a display-order change, not a data edit to
the medicine itself (keeps `updatedAt`-based sync/audit semantics, if any
ever get added, meaningful).

**UI — `MedicineListScreen`.** The active-tab `ListView` in
`_MedicineListView` (`includeArchived: false`) becomes a
`ReorderableListView.builder` (drag handle via the default long-press
affordance, no new dependency — `ReorderableListView` is Flutter SDK).
`onReorder(oldIndex, newIndex)`:

1. Adjust `newIndex` for Flutter's documented off-by-one when dragging
   downward (`if (newIndex > oldIndex) newIndex -= 1;`).
2. Reorder a local copy of the currently-displayed id list.
3. Call `reorderMedicines(reordered)` through the controller (optimistic —
   the screen already reflects the new order locally; the DB write
   round-trips through the `medicinesProvider` stream to confirm).

The **archived tab stays a plain `ListView`** — archived items aren't
being actively triaged day-to-day, and archived rows keep whatever
`sortOrder` they had when archived so un-archiving doesn't lose their place;
no drag affordance needed there, one fewer thing to build.

**Empty/single-item list** — `ReorderableListView` handles 0/1 items fine
natively (no drag target if there's nothing to reorder against); no special
casing needed.

## Out of scope

- Water's `quickAddAmountsMl` reorder UI (already an ordered list; no
  `sort_order` column applies — see Problem section). A few-line follow-up
  if wanted, not this spec.
- Dashboard module display order (a new `AppSettings` preference, not a
  `sort_order` column on a row table — different mechanism, separate spec
  if pursued).
- Prayer reordering — deliberately not supported; canonical prayer order is
  correct by definition.
- Reordering *within* a single medicine's schedule/doses — schedules are
  time-driven (`scheduledFor`), not user-priority-driven; no ask for this
  in the Atlas item.
- Any change to `medicinesNeedingLowStockAlert()` or other non-list-display
  queries — they don't render a user-facing ordered list, so `sortOrder` is
  irrelevant to them and they keep their existing (unordered) queries.

## Global Constraints

- New DB column: `sort_order` (int, default `0`) on `medicines`.
- `schemaVersion` → `4`, migrated via `m.addColumn` + a one-time backfill
  (`createdAt` ascending) in the same `if (from < 4)` block.
- `createMedicine()` sets `sortOrder` to `max(existing) + 1`, never `0`,
  so new medicines append at the end instead of jumping to the top.
- New repository method `reorderMedicines(List<String> orderedIds)`,
  transactional, does not bump `updatedAt`.
- Only the active-tab medicine list gets `ReorderableListView`; the
  archived tab and every other module's lists are unchanged.
