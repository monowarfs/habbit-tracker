import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Icon per mood value (1-5), shared by the dashboard card, home
/// quick-log buttons, and the log list.
const Map<int, IconData> moodValueIcons = {
  1: Icons.sentiment_very_dissatisfied,
  2: Icons.sentiment_dissatisfied,
  3: Icons.sentiment_neutral,
  4: Icons.sentiment_satisfied,
  5: Icons.sentiment_very_satisfied,
};

/// The localized label for [moodValue] (1-5).
String moodValueLabel(AppLocalizations l10n, int moodValue) {
  return switch (moodValue) {
    1 => l10n.moodValue1,
    2 => l10n.moodValue2,
    3 => l10n.moodValue3,
    4 => l10n.moodValue4,
    _ => l10n.moodValue5,
  };
}
