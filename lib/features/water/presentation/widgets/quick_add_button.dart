import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';

/// A one-tap quick-add preset button (FR-W-03) — tapping logs immediately,
/// no confirmation dialog.
class QuickAddButton extends StatelessWidget {
  /// Creates a quick-add button for [amountMl].
  const QuickAddButton({
    required this.amountMl,
    required this.unit,
    required this.onTap,
    super.key,
  });

  /// The preset amount, in ml.
  final int amountMl;

  /// The user's preferred display unit (D-01/FR-W-02).
  final WaterUnit unit;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(foregroundColor: ModuleAccents.water),
      child: Text('+${formatWaterAmount(context, amountMl, unit)}'),
    );
  }
}
