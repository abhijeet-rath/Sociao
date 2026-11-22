import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../comments/presentation/comments_sheet.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/domain/post.dart';
import '../../feed/domain/post_query.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../feed/presentation/widgets/post_card_for.dart';
import 'video_surface.dart';

/// Full-screen vertical video viewer (reference screen 04).
///
/// Used as the "Video" tab (no [initialPostId]) and as a pushed route
/// starting at a specific post.
class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key, this.initialPostId});

  final String? initialPostId;

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  PageController? _pages;
  int _index = 0;
  final _viewed = <String>{};
  static const _query = PostQuery.videos;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _onPage(int i, List<Post> posts) {
    setState(() => _index = i);
    if (i >= posts.length - 3) {
      ref.read(postListProvider(_query).notifier).loadMore();
    }
    _countView(posts[i]);
  }

  void _countView(Post post) {
    if (_viewed.add(post.id)) {
      ref.read(feedRepositoryProvider).incrementViews(post.id).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(postListProvider(_query));

    return Scaffold(
      backgroundColor: Colors.black,
      body: videos.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline,
            message: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(postListProvider(_query)),
          ),
        ),
        data: (state) {
          final posts = state.posts;
          if (posts.isEmpty) {
            return Stack(
              children: [
                const Center(
                  child: EmptyState(
                    icon: Icons.smart_display_outlined,
                    message: 'No videos yet',
                  ),
                ),
                _TopBar(onClose: _close),
              ],
            );
          }
          if (_pages == null) {
            final start = widget.initialPostId == null
                ? 0
                : posts.indexWhere((p) => p.id == widget.initialPostId);
            _index = start < 0 ? 0 : start;
            _pages = PageController(initialPage: _index);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _countView(posts[_index]),
            );
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                itemCount: posts.length,
                onPageChanged: (i) => _onPage(i, posts),
                itemBuilder: (_, i) => _VideoPage(
                  key: ValueKey(posts[i].id),
                  post: posts[i],
                  active: i == _index,
                  query: _query,
                ),
              ),
              _TopBar(onClose: _close),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
            Text(
              'Video',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends ConsumerWidget {
  const _VideoPage({
    super.key,
    required this.post,
    required this.active,
    required this.query,
  });

  final Post post;
  final bool active;
  final PostQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(postListProvider(query).notifier);
    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (active && post.mediaUrl != null)
          VideoSurface(url: post.mediaUrl!, posterUrl: post.thumbnailUrl)
        else
          ColoredBox(
            color: Colors.black,
            child: post.thumbnailUrl == null
                ? null
                : Image.network(post.thumbnailUrl!, fit: BoxFit.cover),
          ),
        // Gradient so white text stays readable on bright videos.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Colors.black54],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 110,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RailButton(
                  icon: Icons.favorite,
                  tooltip: post.likedByMe ? 'Unlike' : 'Like',
                  color: post.likedByMe ? AppColors.like : Colors.white,
                  count: post.likesCount,
                  onTap: () => guard(() => controller.toggleLike(post.id)),
                ),
                _RailButton(
                  icon: Icons.chat_bubble,
                  tooltip: 'Comments',
                  count: post.commentsCount,
                  onTap: () =>
                      showCommentsSheet(context, postId: post.id, query: query),
                ),
                _RailButton(
                  icon: Icons.send,
                  tooltip: 'Share',
                  count: post.sharesCount,
                  onTap: () => guard(() => sharePost(ref, post, query)),
                ),
                _RailButton(
                  icon: Icons.bookmark,
                  tooltip: post.bookmarkedByMe ? 'Remove from saved' : 'Save',
                  color: post.bookmarkedByMe ? AppColors.blue : Colors.white,
                  count: post.savesCount,
                  onTap: () => guard(() => controller.toggleBookmark(post.id)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 90,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        url: post.avatarUrl,
                        name: post.displayName,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          post.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (post.caption.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                  if (post.musicTitle != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            post.musicTitle!,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Tooltip(
            message: tooltip,
            child: Material(
              color: Colors.white24,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(icon, color: color, size: 26),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.count(count),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
