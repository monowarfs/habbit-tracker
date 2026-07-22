import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

/// Dispatches a tapped home-screen/app shortcut to the module whose
/// [buildHabitModules]-built `id` equals [type], calling its headless
/// `onQuickAction()`. Mirrors
/// `core/notifications/notification_action_handler.dart`'s `_dispatch` —
/// same shape, no ledger, no navigation (the caller navigates once this
/// returns; see `main.dart`'s `QuickActions.initialize` callback).
Future<void> handleQuickAction({
  required String type,
  required AppDatabase db,
}) async {
  final modules = buildHabitModules(db);
  for (final module in modules) {
    if (module.id == type) {
      await module.onQuickAction();
      return;
    }
  }
}
