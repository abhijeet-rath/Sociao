import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sociao/core/utils/app_exception.dart';
import 'package:sociao/features/comments/data/comments_repository.dart';
import 'package:sociao/features/comments/domain/comment.dart';
import 'package:sociao/features/comments/presentation/comments_controller.dart';
import 'package:sociao/features/messages/domain/message_models.dart';

class _MockComments extends Mock implements CommentsRepository {}

Comment _c(String id, {String? parent, int likes = 0, bool liked = false}) =>
    Comment.fromJson({
      'id': id,
      'post_id': 'p',
      'user_id': 'u',
      'parent_id': parent,
      'body': 'text $id',
      'likes_count': likes,
      'created_at': DateTime.now().toIso8601String(),
      'author': {'username': 'randy', 'full_name': 'Randy V'},
    }, likedByMe: liked);

void main() {
  group('buildThreads', () {
    test('groups replies under their parent, oldest first', () {
      final threads = buildThreads([
        _c('a'),
        _c('b'),
        _c('a1', parent: 'a'),
        _c('a2', parent: 'a'),
      ]);
      expect(threads.map((t) => t.comment.id), ['a', 'b']);
      expect(threads[0].replies.map((r) => r.id), ['a1', 'a2']);
      expect(threads[1].replies, isEmpty);
    });
  });

  group('CommentsController', () {
    late _MockComments repo;
    late ProviderContainer container;

    setUp(() {
      repo = _MockComments();
      container = ProviderContainer(
        overrides: [commentsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    Future<CommentsController> load(List<Comment> initial) async {
      when(() => repo.fetchComments('p')).thenAnswer((_) async => initial);
      await container.read(commentsProvider('p').future);
      return container.read(commentsProvider('p').notifier);
    }

    List<Comment> current() =>
        container.read(commentsProvider('p')).requireValue;

    test('a reply to a reply attaches to the same top-level parent', () async {
      final ctrl = await load([_c('a'), _c('a1', parent: 'a')]);
      when(
        () => repo.addComment(
          postId: 'p',
          body: 'hi',
          parentId: any(named: 'parentId'),
        ),
      ).thenAnswer(
        (i) async => _c('new', parent: i.namedArguments[#parentId] as String?),
      );

      await ctrl.add('hi', parentId: 'a1'); // replying to a reply

      verify(() => repo.addComment(postId: 'p', body: 'hi', parentId: 'a'))
          .called(1);
      expect(current().last.parentId, 'a');
    });

    test('like is optimistic and rolls back on failure', () async {
      final ctrl = await load([_c('a', likes: 2)]);
      when(() => repo.toggleLike('a')).thenThrow(const AppException('no'));

      await expectLater(ctrl.toggleLike('a'), throwsA(isA<AppException>()));

      expect(current().single.likedByMe, isFalse);
      expect(current().single.likesCount, 2);
    });

    test('like updates count when the server agrees', () async {
      final ctrl = await load([_c('a', likes: 2)]);
      when(() => repo.toggleLike('a')).thenAnswer((_) async => true);

      await ctrl.toggleLike('a');

      expect(current().single.likedByMe, isTrue);
      expect(current().single.likesCount, 3);
    });

    test(
      'deleting a comment also removes its replies and reports the count',
      () async {
        final ctrl = await load([_c('a'), _c('a1', parent: 'a'), _c('b')]);
        when(() => repo.deleteComment('a')).thenAnswer((_) async {});

        final removed = await ctrl.delete('a');

        expect(removed, 2);
        expect(current().map((c) => c.id), ['b']);
      },
    );
  });

  group('summarizeReactions', () {
    test('counts hearts per message and flags mine', () {
      final out = summarizeReactions([
        {'message_id': 'm1', 'user_id': 'me'},
        {'message_id': 'm1', 'user_id': 'other'},
        {'message_id': 'm2', 'user_id': 'other'},
      ], 'me');
      expect(out['m1']!.count, 2);
      expect(out['m1']!.mine, isTrue);
      expect(out['m2']!.count, 1);
      expect(out['m2']!.mine, isFalse);
      expect(out['m3'], isNull);
    });
  });
}
