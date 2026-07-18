import 'package:habit_tracker/core/modules/habit_module.dart';

/// The single shared list of registered modules
/// (`technical/architecture.md`).
///
/// Adding a future module (e.g. Sleep) means writing
/// `lib/features/sleep/` and adding one line here — no other file in this
/// list or in `core/` is touched.
// NEW MODULE GOES HERE
final List<HabitModule> habitModules = <HabitModule>[];
