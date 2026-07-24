import 'package:flutter/material.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/water/data/weather_location_resolver.dart';

/// Shows a friendly explanation before requesting location access for
/// weather-aware reminder copy, then resolves that location if the user
/// agrees (`docs/superpowers/specs/02-delightful/
/// 07-weather-aware-water-nudge-copy-design.md`) — same
/// explainer-then-request pattern as `showNotificationPermissionExplainer`.
/// Returns whether both the dialog was accepted *and* location resolved
/// successfully; shows a snackbar and returns `false` if location fails.
/// [resolveLocation] overrides [resolveWeatherLocation] — test-only seam.
Future<bool> showWeatherNudgeExplainer(
  BuildContext context, {
  Future<Result<WeatherLocation>> Function()? resolveLocation,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.weatherNudgeSettingsTitle),
      content: Text(l10n.weatherNudgeSettingsExplainerBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.notificationPermissionNotNowButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.notificationPermissionAllowButton),
        ),
      ],
    ),
  );
  if (proceed != true) return false;

  final locationResult = await (resolveLocation ?? resolveWeatherLocation)();
  if (locationResult case Failure()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.weatherNudgePermissionDeniedSnackbar)),
      );
    }
    return false;
  }
  return true;
}
