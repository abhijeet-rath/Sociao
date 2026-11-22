import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';
import '../domain/comment.dart';

class CommentsRepository {
  const CommentsRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, author:profiles!comments_user_id_fkey(username,full_name,avatar_url)';

  Future<List<Comment>> fetchComments(String postId) async {
    try {
      final rows = await _client
          .from('comments')
          .select(_select)
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      final liked = <String>{};
      final me = _client.auth.currentUser?.id;
      if (me != null && rows.isNotEmpty) {
        final likes = await _client
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', me)
            .inFilter(
              'comment_id',
              rows.map((r) => r['id'] as String).toList(),
            );
        liked.addAll(likes.map((l) => l['comment_id'] as String));
      }
      return rows
          .map((r) => Comment.fromJson(r, likedByMe: liked.contains(r['id'])))
          .toList();
    } catch (e) {
      throw AppException('Could not load comments.', cause: e);
    }
  }

  Future<Comment> addComment({
    required String postId,
    required String body,
    String? parentId,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw const AppException('You are signed out.');
    try {
      final row = await _client
          .from('comments')
          .insert({
            'post_id': postId,
            'user_id': me,
            'body': body.trim(),
            'parent_id': ?parentId,
          })
          .select(_select)
          .single();
      return Comment.fromJson(row);
    } catch (e) {
      throw AppException('Could not post your comment.', cause: e);
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await _client.from('comments').delete().eq('id', id);
    } catch (e) {
      throw AppException('Could not delete the comment.', cause: e);
    }
  }

  Future<bool> toggleLike(String commentId) async {
    try {
      return await _client.rpc(
        'toggle_comment_like',
        params: {'p_comment_id': commentId},
      ) as bool;
    } catch (e) {
      throw AppException('Could not update the like.', cause: e);
    }
  }
}

final commentsRepositoryProvider = Provider<CommentsRepository>(
  (ref) => CommentsRepository(ref.watch(supabaseClientProvider)),
);
