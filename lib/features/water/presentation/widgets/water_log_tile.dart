import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';

/// A single logged entry row, with a delete action (FR-W-09).
class WaterLogTile extends StatelessWidget {
  /// Creates a log entry tile.
  const WaterLogTile({
    required this.entry,
    required this.unit,
    required this.onDelete,
    this.onTap,
    super.key,
  });

  /// The entry to display.
  final WaterEntry entry;

  /// The user's preferred display unit (D-01).
  final WaterUnit unit;

  /// Called when the delete action is tapped.
  final VoidCallback onDelete;

  /// Called when the tile itself is tapped (edit, FR-W-09).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        entry.source == WaterEntrySource.quick
            ? Icons.flash_on
            : Icons.edit_note,
      ),
      title: Text(formatWaterAmount(context, entry.amountMl, unit)),
      subtitle: Text(formatWaterLogTime(context, entry.loggedAt)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: AppLocalizations.of(context)!.commonDelete,
        onPressed: onDelete,
      ),
    );
  }
}
