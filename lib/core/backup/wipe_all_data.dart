import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Deletes every row every registered module owns, plus the shared
/// common tables (`app_settings`, `achievements`, `notification_ledger`),
/// inside one transaction — the "replace" half of import
/// (`core/backup/import_orchestrator.dart`) and the "forgot PIN" full
/// data reset (`core/security/pin_lock_controller.dart`) share this
/// single wipe list rather than each keeping their own.
Future<void> wipeAllAppData(List<HabitModule> modules, AppDatabase db) async {
  await db.transaction(() async {
    for (final module in modules) {
      await module.wipeData();
    }
    await db.delete(db.appSettingsTable).go();
    await db.delete(db.achievementsTable).go();
    await db.delete(db.notificationLedgerTable).go();
  });
}
