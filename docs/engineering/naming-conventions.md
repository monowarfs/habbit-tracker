# Naming Conventions

## Files

`snake_case.dart` throughout (standard Dart convention), with a suffix that
identifies the file's role, matching `../technical/folder-structure.md`'s
tree exactly:

| Suffix | Role | Location |
|---|---|---|
| `_screen.dart` | A routed, full-page widget | `presentation/screens/` |
| *(descriptive name, no forced suffix)* | A reusable, non-page widget — the `widgets/` folder location already signals its role, so `water_progress_ring.dart` doesn't also need a `_widget` suffix | `presentation/widgets/` |
| `_controller.dart` | A Riverpod `Notifier`/`AsyncNotifier` (mutations) | `presentation/providers/` |
| `_providers.dart` | Plain read providers grouped for a feature (when not controller classes) | `presentation/providers/` |
| `_usecase.dart` | One use case per file | `domain/usecases/` |
| `_repository.dart` | Abstract repository interface | `domain/repositories/` |
| `_repository_impl.dart` | Concrete Drift-backed implementation | `data/repositories/` |
| `_table.dart` | Drift table definition | `data/tables/` |
| `_dao.dart` | Drift DAO | `data/daos/` |
| `_module.dart` | `HabitModule` implementation | feature root (e.g. `water_module.dart`) |
| `_test.dart` | Test file (mirroring rule below) | `test/` |

## Classes

`UpperCamelCase`, no Hungarian prefixes (no `IWaterRepository` — the
interface is just `WaterRepository`, its implementation is
`WaterRepositoryImpl`, the suffix carries the distinction). Class suffix
matches the file's role: `WaterRepository` (interface) /
`WaterRepositoryImpl` (impl) / `WaterController` / `WaterHomeScreen` /
`LogWaterEntryUseCase` — note the explicit `UseCase` suffix on the class
even when the file itself is named without it (`log_water_entry.dart`),
since "LogWaterEntry" alone reads as a noun/event, not as an
action-invoking class.

## Providers

`camelCase` + `Provider` suffix, always. The name states **what the
provider exposes**, never its implementation:

- `todaysWaterEntriesProvider` — not `waterLogsStreamProvider`.
- `waterGoalProvider` — the current goal, resolved value.
- `waterControllerProvider` — the mutation controller; the word
  `Controller` stays *in* the provider name (not just the class name)
  because call sites read naturally as
  `ref.watch(waterControllerProvider.notifier).logEntry(...)`.

## DB tables

`snake_case`, plural nouns — matches `../technical/database-design.md`
exactly: `water_logs`, `medicine_doses`, `prayer_records`. Columns:
`snake_case`, singular: `amount_ml`, `scheduled_for`, `deleted_at`.

## ARB keys

Pattern: `moduleName_screen_element` — each segment itself `camelCase`,
segments joined by a single underscore, e.g.:

- `water_addEntryScreen_saveButton`
- `medicine_doseDetail_snoozeButton`
- `common_pinLock_forgotPinLink`

**Why this exact shape:** Flutter's `gen_l10n` turns every ARB key
directly into a generated Dart method name (`AppLocalizations.of(context)
.water_addEntryScreen_saveButton`), so the whole key must be a valid Dart
identifier — letters, digits, and underscores only, no spaces or hyphens.
The `module_screen_element` structure keeps keys groupable and
greppable (searching `medicine_doseDetail_` finds every string on that one
screen) without needing a nested-object ARB structure gen_l10n doesn't
support well.

## Route names

Path segments (already established in `../product/navigation-map.md`):
plain lowercase, e.g. `/medicine/dose/:id`. GoRouter's optional `name:`
parameter (used for `context.goNamed(...)` calls instead of raw path
strings, so a path typo is a compile-time-checkable named-route typo
instead) uses `camelCase` matching the screen's purpose:
`name: 'medicineDoseDetail'`, `name: 'prayerQadha'`.

## Test file mirroring rule

Every source file worth testing has a corresponding test file at the
**identical relative path**, with `lib/` replaced by `test/` and `.dart`
replaced by `_test.dart`:

```
lib/features/water/domain/usecases/calculate_water_streak.dart
test/features/water/domain/calculate_water_streak_test.dart
```

(Note: `usecases/`/`repositories/`/`tables/` subfolders collapse to one
flat `domain/`/`data/` test folder per feature, matching
`folder-structure.md`'s test tree — the mirroring rule is about the
*source-to-test name mapping*, not requiring an identical subfolder depth,
since test files are grouped by layer for browsability, not by the
source's own internal folder structure.) This makes "does this file have
a test" and "where is this file's test" both mechanical lookups, not
something that requires remembering a separate mapping.
