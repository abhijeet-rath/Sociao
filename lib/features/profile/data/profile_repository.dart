import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';
import '../domain/profile.dart';

enum FollowListKind { followers, following }

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  Future<Profile> fetchProfile(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      final stats = await _client
          .from('profile_stats')
          .select()
          .eq('profile_id', userId)
          .maybeSingle();
      var following = false;
      final me = _me;
      if (me != null && me != userId) {
        final row = await _client
            .from('follows')
            .select('follower_id')
            .eq('follower_id', me)
            .eq('following_id', userId)
            .maybeSingle();
        following = row != null;
      }
      return Profile.fromJson(profile, stats, isFollowing: following);
    } catch (e) {
      throw AppException('Could not load this profile.', cause: e);
    }
  }

  /// Returns the new follow state.
  Future<bool> toggleFollow(String userId) async {
    try {
      return await _client.rpc('toggle_follow', params: {'p_user_id': userId})
          as bool;
    } catch (e) {
      throw AppException(
        'Could not update follow. Please try again.',
        cause: e,
      );
    }
  }

  /// People who follow [userId] or are followed by [userId].
  Future<List<UserSummary>> fetchFollowList(
    String userId,
    FollowListKind kind,
  ) async {
    try {
      final followers = kind == FollowListKind.followers;
      final rows = await _client
          .from('follows')
          .select(
            followers
                ? 'created_at, user:profiles!follows_follower_id_fkey(id,username,full_name,avatar_url)'
                : 'created_at, user:profiles!follows_following_id_fkey(id,username,full_name,avatar_url)',
          )
          .eq(followers ? 'following_id' : 'follower_id', userId)
          .order('created_at', ascending: false);
      return rows
          .map((r) => UserSummary.fromJson(r['user'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException('Could not load the list.', cause: e);
    }
  }

  /// Ids of everyone the signed-in user follows.
  Future<Set<String>> fetchMyFollowingIds() async {
    final me = _me;
    if (me == null) return {};
    try {
      final rows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);
      return rows.map((r) => r['following_id'] as String).toSet();
    } catch (e) {
      throw AppException('Could not load your following list.', cause: e);
    }
  }

  /// Removes someone from my followers (they stop following me).
  Future<void> removeFollower(String followerId) async {
    final me = _me;
    if (me == null) return;
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', me);
    } catch (e) {
      throw AppException('Could not remove this follower.', cause: e);
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', _me ?? '')
          .maybeSingle();
      return row == null;
    } catch (e) {
      throw AppException('Could not check the username.', cause: e);
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String username,
    required String bio,
    required String? website,
    String? avatarUrl,
  }) async {
    final me = _me;
    if (me == null) throw const AppException('You are signed out.');
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            'username': username,
            'bio': bio,
            'website': (website == null || website.isEmpty) ? null : website,
            'avatar_url': ?avatarUrl,
          })
          .eq('id', me);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppException('That username is already taken.');
      }
      throw AppException('Could not save your profile.', cause: e);
    } catch (e) {
      throw AppException('Could not save your profile.', cause: e);
    }
  }

  /// Uploads to `avatars/{uid}/avatar.jpg` (replacing the old file) and returns
  /// a cache-busted public URL.
  Future<String> uploadAvatar(Uint8List bytes, String contentType) async {
    final me = _me;
    if (me == null) throw const AppException('You are signed out.');
    try {
      final path = '$me/avatar.jpg';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      throw AppException('Could not upload the photo.', cause: e);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
