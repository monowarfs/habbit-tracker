import 'package:habit_tracker/core/changelog/changelog_entry.dart';

/// The app's changelog, newest-first. One entry appended by hand each
/// release alongside the version bump in `pubspec.yaml`.
final List<ChangelogEntry> kChangelogEntries = [
  ChangelogEntry(
    version: '1.1.0',
    highlights: [
      (l10n) => l10n.changelog1_1_0_bullet1,
      (l10n) => l10n.changelog1_1_0_bullet2,
    ],
  ),
];
