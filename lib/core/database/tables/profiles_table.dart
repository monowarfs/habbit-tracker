import 'package:drift/drift.dart';

/// Family/multi-profile support (`docs/superpowers/specs/04-premium/
/// 03-family-multi-profile-design.md`) — local-only, single-device profile
/// switching. Every pre-existing row across the app defaults to the
/// `'system'` profile id via the Task 2 migration, so this table's first
/// row (seeded by `ProfileRepository`) always has id `'system'`.
@DataClassName('ProfileRow')
class ProfilesTable extends Table {
  @override
  String get tableName => 'profiles';

  /// `'system'` for the pre-migration default profile; a generated uuid
  /// for every profile created afterward.
  TextColumn get id => text()();

  /// User-chosen name shown in the profile switcher.
  TextColumn get displayName => text()();

  /// A named color key (e.g. `'teal'`), resolved to an actual `Color` by
  /// the presentation layer — mirrors `AppSettingsTable.activePaletteId`.
  TextColumn get avatarColor => text()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// Soft-delete marker; null = not deleted. Deleting a profile doesn't
  /// erase its data rows (`ProfileRepository.deleteProfile`), just the
  /// profile itself.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
