import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/water_module.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'module_registry.g.dart';

/// The single shared list of registered modules
/// (`../../technical/architecture.md`).
///
/// A Riverpod provider, not a bare list — `HabitModule.pendingNotifications`/
/// `exportData`/`importData` don't take a `Ref` (they run from non-widget
/// code like the future boot receiver), so each module's repository is
/// injected once, here, at construction time. `dashboardSummary`/
/// `settingsEntry` still take their own `WidgetRef` and can watch whatever
/// providers they need independently.
///
/// Adding a future module (e.g. Sleep) means writing `lib/features/sleep/`
/// and adding one line below — no other file in this list or in `core/` is
/// touched.
@Riverpod(keepAlive: true)
List<HabitModule> habitModules(Ref ref) {
  return [
    // NEW MODULE GOES HERE
    WaterModule(ref.watch(waterRepositoryProvider)),
  ];
}
