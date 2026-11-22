import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/comments_repository.dart';
import '../domain/comment.dart';

/// Flat, chronological comment list for one post with optimistic likes.
class CommentsController extends AsyncNotifier<List<Comment>> {
  CommentsController(this.postId);

  final String postId;

  CommentsRepository get _repo => ref.read(commentsRepositoryProvider);

  @override
  Future<List<Comment>> build() =>
      ref.watch(commentsRepositoryProvider).fetchComments(postId);

  /// Adds a comment, or a reply when [parentId] is set. A reply to a reply is
  /// attached to the same top-level parent (replies are one level deep).
  Future<void> add(String body, {String? parentId}) async {
    final list = state.value ?? const <Comment>[];
    String? effectiveParent = parentId;
    if (parentId != null) {
      final parent = list.where((c) => c.id == parentId).firstOrNull;
      effectiveParent = parent?.parentId ?? parentId;
    }
    final created = await _repo.addComment(
      postId: postId,
      body: body,
      parentId: effectiveParent,
    );
    state = AsyncData([...list, created]);
  }

  Future<void> toggleLike(String commentId) async {
    final list = state.value;
    if (list == null) return;
    final before = list.firstWhere((c) => c.id == commentId);
    _set(
      commentId,
      (c) => c.copyWith(
        likedByMe: !c.likedByMe,
        likesCount: c.likesCount + (c.likedByMe ? -1 : 1),
      ),
    );
    try {
      final liked = await _repo.toggleLike(commentId);
      if (liked != !before.likedByMe) {
        _set(
          commentId,
          (c) => c.copyWith(
            likedByMe: liked,
            likesCount: before.likesCount + (liked ? 1 : 0),
          ),
        );
      }
    } catch (_) {
      _set(commentId, (_) => before);
      rethrow;
    }
  }

  /// Deletes a comment (and its replies, via cascade). Returns how many
  /// comments disappeared so callers can adjust the post's counter.
  Future<int> delete(String commentId) async {
    final list = state.value ?? const <Comment>[];
    await _repo.deleteComment(commentId);
    final remaining = list
        .where((c) => c.id != commentId && c.parentId != commentId)
        .toList();
    state = AsyncData(remaining);
    return list.length - remaining.length;
  }

  void _set(String id, Comment Function(Comment) update) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final c in list) c.id == id ? update(c) : c]);
  }
}

final commentsProvider =
    AsyncNotifierProvider.family<CommentsController, List<Comment>, String>(
      CommentsController.new,
    );
