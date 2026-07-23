import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// One release's changelog entry.
class ChangelogEntry {
  /// Creates a [ChangelogEntry].
  const ChangelogEntry({required this.version, required this.highlights});

  /// Semantic version this entry describes, e.g. `'1.1.0'` — matches
  /// `PackageInfo.version` (the part before `+buildNumber`).
  final String version;

  /// Localized bullet points for this release — each string is an
  /// `AppLocalizations` getter name resolved at display time.
  final List<String Function(AppLocalizations)> highlights;
}
