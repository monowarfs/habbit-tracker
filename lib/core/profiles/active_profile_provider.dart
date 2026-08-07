import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_profile_provider.g.dart';

/// The shared [ProfileRepository].
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(databaseProvider));
}

/// The currently active profile. All profile-aware code reads from this
/// provider rather than the repository directly.
///
/// This is a one-shot fetch, not a live DB stream — after
/// `profileRepositoryProvider.setActiveProfile()`, the caller must
/// `ref.invalidate(activeProfileProvider)` (the profile switcher does this
/// on selection). Every provider that reads profile-scoped data should
/// `ref.watch(activeProfileProvider)` so Riverpod's dependency graph
/// refreshes it automatically when the active profile is invalidated.
@Riverpod(keepAlive: true)
Future<Profile> activeProfile(Ref ref) {
  return ref.watch(profileRepositoryProvider).getActiveProfile();
}

/// All non-deleted profiles, for the switcher and manage-profiles screen.
/// Not `keepAlive` — recomputed on demand, invalidated the same way as
/// [activeProfileProvider] after a create/update/delete.
@riverpod
Future<List<Profile>> profileList(Ref ref) {
  return ref.watch(profileRepositoryProvider).listProfiles();
}

/// Approximate data volume for [profileId], for the manage-profiles
/// screen's "N items" label.
@riverpod
Future<int> profileDataItemCount(Ref ref, String profileId) {
  return ref.watch(profileRepositoryProvider).dataItemCount(profileId);
}
