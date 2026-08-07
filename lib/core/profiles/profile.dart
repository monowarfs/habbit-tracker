import 'package:habit_tracker/core/database/app_database.dart';

/// A family member's local profile (`docs/superpowers/specs/04-premium/
/// 03-family-multi-profile-design.md`). Kept as a plain class separate
/// from Drift's generated `ProfileRow` because `part`-file-declared types
/// can't be referenced from `@riverpod`-generated code
/// (`active_profile_provider.dart` hits `InvalidTypeException` if it
/// returns `ProfileRow` directly).
class Profile {
  /// Creates a profile.
  const Profile({
    required this.id,
    required this.displayName,
    required this.avatarColor,
    required this.createdAt,
  });

  /// `'system'` for the pre-migration default profile; a generated uuid
  /// for every profile created afterward.
  final String id;

  /// User-chosen name shown in the profile switcher.
  final String displayName;

  /// A named color key (e.g. `'teal'`), resolved to an actual `Color` by
  /// the presentation layer.
  final String avatarColor;

  /// UTC epoch millis.
  final int createdAt;
}

/// Maps a Drift row to the domain type.
extension ProfileRowMapping on ProfileRow {
  /// Converts to [Profile].
  Profile toDomain() => Profile(
    id: id,
    displayName: displayName,
    avatarColor: avatarColor,
    createdAt: createdAt,
  );
}
