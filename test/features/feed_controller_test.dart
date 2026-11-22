import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sociao/core/supabase/supabase_client.dart';
import 'package:sociao/core/utils/app_exception.dart';
import 'package:sociao/features/feed/data/feed_repository.dart';
import 'package:sociao/features/feed/domain/post.dart';
import 'package:sociao/features/feed/domain/post_query.dart';
import 'package:sociao/features/feed/presentation/feed_controller.dart';

class _MockRepo extends Mock implements FeedRepository {}

Post _post(String id, {bool liked = false, int likes = 0}) => Post.fromJson({
  'id': id,
  'user_id': 'u1',
  'username': 'marilyn.torff',
  'full_name': 'Marilyn Torff',
  'caption': 'hello',
  'media_type': 'none',
  'likes_count': likes,
  'created_at': DateTime.now().toIso8601String(),
  'liked_by_me': liked,
});

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> loadFeed(List<Post> posts) async {
    when(() => repo.fetchPosts(page: 0, query: PostQuery.home))
        .thenAnswer((_) async => posts);
    await container.read(postListProvider(PostQuery.home).future);
  }

  Post current(String id) => container
      .read(postListProvider(PostQuery.home))
      .requireValue
      .posts
      .firstWhere((p) => p.id == id);

  test('like updates count and state, matching the server', () async {
    await loadFeed([_post('a', likes: 5)]);
    when(() => repo.toggleLike('a')).thenAnswer((_) async => true);

    await container
        .read(postListProvider(PostQuery.home).notifier)
        .toggleLike('a');

    expect(current('a').likedByMe, isTrue);
    expect(current('a').likesCount, 6);
  });

  test('unlike decrements the count', () async {
    await loadFeed([_post('a', liked: true, likes: 5)]);
    when(() => repo.toggleLike('a')).thenAnswer((_) async => false);

    await container
        .read(postListProvider(PostQuery.home).notifier)
        .toggleLike('a');

    expect(current('a').likedByMe, isFalse);
    expect(current('a').likesCount, 4);
  });

  test('failed like rolls back and rethrows', () async {
    await loadFeed([_post('a', likes: 5)]);
    when(() => repo.toggleLike('a')).thenThrow(const AppException('nope'));

    await expectLater(
      container.read(postListProvider(PostQuery.home).notifier).toggleLike('a'),
      throwsA(isA<AppException>()),
    );

    expect(current('a').likedByMe, isFalse);
    expect(current('a').likesCount, 5);
  });

  test('server state wins when it differs from the optimistic guess', () async {
    // UI thought "not liked", but the server says the like already existed.
    await loadFeed([_post('a', likes: 5)]);
    when(() => repo.toggleLike('a')).thenAnswer((_) async => false);

    await container
        .read(postListProvider(PostQuery.home).notifier)
        .toggleLike('a');

    expect(current('a').likedByMe, isFalse);
    expect(current('a').likesCount, 5);
  });

  test('delete removes the post from the list', () async {
    await loadFeed([_post('a'), _post('b')]);
    when(() => repo.deletePost('a')).thenAnswer((_) async {});

    await container
        .read(postListProvider(PostQuery.home).notifier)
        .deletePost('a');

    final ids = container
        .read(postListProvider(PostQuery.home))
        .requireValue
        .posts;
    expect(ids.map((p) => p.id), ['b']);
  });
}
