import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// A profile with optimistic follow / unfollow.
class ProfileController extends AsyncNotifier<Profile> {
  ProfileController(this.userId);

  final String userId;

  @override
  Future<Profile> build() =>
      ref.watch(profileRepositoryProvider).fetchProfile(userId);

  Future<void> toggleFollow() async {
    final before = state.value;
    if (before == null) return;
    final optimistic = before.copyWith(
      isFollowing: !before.isFollowing,
      followersCount: before.followersCount + (before.isFollowing ? -1 : 1),
    );
    state = AsyncData(optimistic);
    try {
      final following = await ref
          .read(profileRepositoryProvider)
          .toggleFollow(userId);
      if (following != optimistic.isFollowing) {
        state = AsyncData(
          optimistic.copyWith(
            isFollowing: following,
            followersCount: before.followersCount + (following ? 1 : 0),
          ),
        );
      }
      ref.invalidate(myFollowingIdsProvider);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final profileProvider =
    AsyncNotifierProvider.family<ProfileController, Profile, String>(
      ProfileController.new,
    );

/// The signed-in user's own profile.
final myProfileProvider = Provider<AsyncValue<Profile>?>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  return me == null ? null : ref.watch(profileProvider(me));
});

final myFollowingIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(profileRepositoryProvider).fetchMyFollowingIds();
});

typedef FollowListKey = ({String userId, FollowListKind kind});

final followListProvider =
    FutureProvider.family<List<UserSummary>, FollowListKey>(
      (ref, key) => ref
          .watch(profileRepositoryProvider)
          .fetchFollowList(key.userId, key.kind),
    );
