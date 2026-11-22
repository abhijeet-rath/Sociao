import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';
import '../domain/post.dart';
import '../domain/post_query.dart';
import '../domain/story_item.dart';
import '../domain/story.dart';

class FeedRepository {
  const FeedRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;

  Future<List<Post>> fetchPosts({
    required int page,
    PostQuery query = PostQuery.home,
  }) async {
    try {
      final from = page * pageSize;
      var request = _client.from('post_feed').select();
      switch (query.scope) {
        case PostScope.all:
          break;
        case PostScope.user:
          request = request.eq('user_id', query.userId!);
        case PostScope.videos:
          request = request.eq('media_type', 'video');
          if (query.userId != null) {
            request = request.eq('user_id', query.userId!);
          }
        case PostScope.tagged:
          final tags = await _client
              .from('post_tags')
              .select('post_id')
              .eq('tagged_user_id', query.userId!);
          final ids = tags.map((r) => r['post_id'] as String).toList();
          if (ids.isEmpty) return [];
          request = request.inFilter('id', ids);
      }
      final rows = await request
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1);
      return rows.map(Post.fromJson).toList();
    } catch (e) {
      throw AppException('Could not load posts. Please try again.', cause: e);
    }
  }

  Future<List<StoryItem>> fetchStories() async {
    try {
      final rows = await _client.from('story_tray').select();
      return rows.map(StoryItem.fromJson).toList();
    } catch (e) {
      throw AppException('Could not load stories.', cause: e);
    }
  }

  /// Active (not expired) stories of one user, oldest first.
  Future<List<Story>> fetchUserStories(String userId) async {
    try {
      final rows = await _client
          .from('stories')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: true);
      return rows.map(Story.fromJson).toList();
    } catch (e) {
      throw AppException('Could not load this story.', cause: e);
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await _client.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': me,
      }, ignoreDuplicates: true);
    } catch (_) {
      // Viewing still works if recording the view fails.
    }
  }

  /// Returns the new liked state as stored in the database.
  Future<bool> toggleLike(String postId) =>
      _toggle('toggle_like', {'p_post_id': postId});

  /// Returns the new bookmarked state as stored in the database.
  Future<bool> toggleBookmark(String postId) =>
      _toggle('toggle_bookmark', {'p_post_id': postId});

  Future<void> logShare(String postId) async {
    try {
      await _client.rpc('log_share', params: {'p_post_id': postId});
    } catch (e) {
      throw AppException('Could not record the share.', cause: e);
    }
  }

  /// Counts one view (used by the Video viewer and profile video grid).
  Future<void> incrementViews(String postId) async {
    try {
      await _client.rpc('increment_post_views', params: {'p_post_id': postId});
    } catch (e) {
      throw AppException('Could not record the view.', cause: e);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _client.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw AppException('Could not delete the post.', cause: e);
    }
  }

  Future<bool> _toggle(String fn, Map<String, dynamic> params) async {
    try {
      final result = await _client.rpc(fn, params: params);
      return result as bool;
    } catch (e) {
      throw AppException('Something went wrong. Please try again.', cause: e);
    }
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(supabaseClientProvider)),
);
