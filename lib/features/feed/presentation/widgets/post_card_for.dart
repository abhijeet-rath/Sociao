import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../comments/presentation/comments_sheet.dart';
import '../../domain/post.dart';
import '../../domain/post_query.dart';
import '../feed_controller.dart';
import 'post_card.dart';
import 'post_options_sheet.dart';

/// Share text for a post (no deep links exist yet).
String shareTextFor(Post post) => post.caption.isEmpty
    ? 'Check out @${post.username} on Sociao'
    : '${post.caption}\n- @${post.username} on Sociao';

/// Shares a post through the system sheet and records the share.
Future<void> sharePost(WidgetRef ref, Post post, PostQuery query) async {
  final result = await SharePlus.instance.share(
    ShareParams(text: shareTextFor(post)),
  );
  if (result.status != ShareResultStatus.dismissed) {
    await ref.read(postListProvider(query).notifier).recordShare(post.id);
  }
}

/// A [PostCard] wired to like / bookmark / share / comments / options for the
/// post list identified by [query].
class PostCardFor extends ConsumerWidget {
  const PostCardFor({super.key, required this.post, required this.query});

  final Post post;
  final PostQuery query;

  void _toast(BuildContext context, Object message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$message')));
  }

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) _toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(postListProvider(query).notifier);
    final me = ref.watch(currentUserProvider)?.id;

    return PostCard(
      post: post,
      onLike: () => _guard(context, () => controller.toggleLike(post.id)),
      onBookmark: () =>
          _guard(context, () => controller.toggleBookmark(post.id)),
      onShare: () => _guard(context, () => sharePost(ref, post, query)),
      onComment: () =>
          showCommentsSheet(context, postId: post.id, query: query),
      onOpenAuthor: () => post.userId == me
          ? context.go(AppRoutes.profile)
          : context.push(AppRoutes.userProfile(post.userId)),
      onOpenMedia: post.isVideo
          ? () => context.push(AppRoutes.videoViewer(post.id))
          : null,
      onOptions: () => showPostOptions(
        context,
        post: post,
        isOwner: post.userId == me,
        onDelete: () => _guard(context, () => controller.deletePost(post.id)),
      ),
    );
  }
}
