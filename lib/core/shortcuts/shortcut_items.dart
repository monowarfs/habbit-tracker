import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

/// The fixed set of 3 static home-screen/app shortcuts — one per module,
/// `type` matching `HabitModule.id` exactly (`'water'`/`'medicine'`
/// /`'prayer'`). `icon` is left `null` for v1: native drawable/asset-catalog
/// icons are a separate design/asset task, out of scope here.
List<ShortcutItem> buildShortcutItems(AppLocalizations l10n) => [
  ShortcutItem(type: 'water', localizedTitle: l10n.waterQuickAddAction),
  ShortcutItem(type: 'medicine', localizedTitle: l10n.medicineMarkDoneAction),
  ShortcutItem(type: 'prayer', localizedTitle: l10n.prayerMarkPrayedAction),
];
