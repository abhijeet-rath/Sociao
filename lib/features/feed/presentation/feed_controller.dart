import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';
import '../domain/post_query.dart';
import '../domain/story_item.dart';

class FeedState {
  const FeedState({
    this.posts = const [],
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool loadingMore;

  FeedState copyWith({List<Post>? posts, bool? hasMore, bool? loadingMore}) =>
      FeedState(
        posts: posts ?? this.posts,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Home feed with pagination and optimistic like / bookmark updates.
/// The database is the source of truth: after each RPC the returned state is
/// reconciled, and on failure the optimistic change is rolled back and the
/// error rethrown so the UI can show a message.
class FeedController extends AsyncNotifier<FeedState> {
  FeedController(this.query);

  final PostQuery query;
  int _page = 0;
  final _pending = <String>{};

  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  @override
  Future<FeedState> build() async {
    // Reload when the signed-in user changes so liked_by_me is correct.
    ref.watch(currentUserProvider.select((u) => u?.id));
    _page = 0;
    final posts = await _repo.fetchPosts(page: 0, query: query);
    return FeedState(
      posts: posts,
      hasMore: posts.length == FeedRepository.pageSize,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _repo.fetchPosts(page: _page + 1, query: query);
      _page++;
      final known = current.posts.map((p) => p.id).toSet();
      state = AsyncData(
        current.copyWith(
          posts: [
            ...current.posts,
            ...next.where((p) => !known.contains(p.id)),
          ],
          hasMore: next.length == FeedRepository.pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) => _optimistic(
    postId,
    apply: (p) => p.copyWith(
      likedByMe: !p.likedByMe,
      likesCount: p.likesCount + (p.likedByMe ? -1 : 1),
    ),
    commit: () => _repo.toggleLike(postId),
    reconcile: (p, liked) => liked == p.likedByMe
        ? p
        : p.copyWith(
            likedByMe: liked,
            likesCount: p.likesCount + (liked ? 1 : -1),
          ),
  );

  Future<void> toggleBookmark(String postId) => _optimistic(
    postId,
    apply: (p) => p.copyWith(
      bookmarkedByMe: !p.bookmarkedByMe,
      savesCount: p.savesCount + (p.bookmarkedByMe ? -1 : 1),
    ),
    commit: () => _repo.toggleBookmark(postId),
    reconcile: (p, saved) => saved == p.bookmarkedByMe
        ? p
        : p.copyWith(
            bookmarkedByMe: saved,
            savesCount: p.savesCount + (saved ? 1 : -1),
          ),
  );

  Future<void> recordShare(String postId) async {
    _replace(postId, (p) => p.copyWith(sharesCount: p.sharesCount + 1));
    try {
      await _repo.logShare(postId);
    } catch (_) {
      _replace(postId, (p) => p.copyWith(sharesCount: p.sharesCount - 1));
    }
  }

  /// Keeps the comment pill in sync after adding/removing a comment.
  void bumpComments(String postId, int delta) => _replace(
    postId,
    (p) =>
        p.copyWith(commentsCount: (p.commentsCount + delta).clamp(0, 1 << 31)),
  );

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        posts: current.posts.where((p) => p.id != postId).toList(),
      ),
    );
  }

  Future<void> _optimistic(
    String postId, {
    required Post Function(Post) apply,
    required Future<bool> Function() commit,
    required Post Function(Post, bool) reconcile,
  }) async {
    // Ignore taps while a request for this post is in flight.
    if (!_pending.add(postId)) {
      return;
    }
    final before = _find(postId);
    if (before == null) {
      _pending.remove(postId);
      return;
    }
    _replace(postId, apply);
    try {
      final serverState = await commit();
      _replace(postId, (p) => reconcile(p, serverState));
    } catch (e) {
      _replace(postId, (_) => before);
      rethrow;
    } finally {
      _pending.remove(postId);
    }
  }

  Post? _find(String id) {
    final posts = state.value?.posts;
    if (posts == null) return null;
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replace(String id, Post Function(Post) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        posts: [for (final p in current.posts) p.id == id ? update(p) : p],
      ),
    );
  }
}

/// Post list for a [PostQuery]; `postListProvider(PostQuery.home)` is the feed.
final postListProvider =
    AsyncNotifierProvider.family<FeedController, FeedState, PostQuery>(
      FeedController.new,
    );

/// Stories row (own stories are excluded: the "Add Story" tile represents me).
final storiesProvider = FutureProvider<List<StoryItem>>((ref) async {
  final me = ref.watch(currentUserProvider)?.id;
  final stories = await ref.watch(feedRepositoryProvider).fetchStories();
  return stories.where((s) => s.userId != me).toList();
});
