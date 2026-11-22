import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/post.dart';
import 'action_pill.dart';

/// A post in the feed (reference screen 03): author row, caption, optional
/// image / video preview, and the like / comment / share / bookmark actions.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
    required this.onOptions,
    this.onOpenMedia,
    this.onOpenAuthor,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final VoidCallback onOptions;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = post.previewUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onOpenAuthor,
                child: UserAvatar(
                  url: post.avatarUrl,
                  name: post.displayName,
                  size: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      Formatters.timeAgo(post.createdAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.more_horiz,
                tooltip: 'Post options',
                size: 40,
                onPressed: onOptions,
              ),
            ],
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(post.caption, style: theme.textTheme.bodyLarge),
          ],
          if (preview != null || post.isVideo) ...[
            const SizedBox(height: 12),
            _Media(url: preview, isVideo: post.isVideo, onTap: onOpenMedia),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              // Scales down on narrow phones instead of overflowing.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        ActionPill(
                          tooltip: post.likedByMe ? 'Unlike' : 'Like',
                          icon: post.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          iconColor: post.likedByMe ? AppColors.like : null,
                          label: Formatters.count(post.likesCount),
                          onTap: onLike,
                        ),
                        const SizedBox(width: 8),
                        ActionPill(
                          tooltip: 'Comments',
                          icon: Icons.chat_bubble_outline,
                          label: Formatters.count(post.commentsCount),
                          onTap: onComment,
                        ),
                        const SizedBox(width: 8),
                        ActionPill(
                          tooltip: 'Share',
                          icon: Icons.send_outlined,
                          label: Formatters.count(post.sharesCount),
                          onTap: onShare,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ActionPill(
                tooltip: post.bookmarkedByMe ? 'Remove bookmark' : 'Bookmark',
                icon: post.bookmarkedByMe
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                onTap: onBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.url, required this.isVideo, this.onTap});

  final String? url;
  final bool isVideo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(color: scheme.surfaceContainerHighest);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.35,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                placeholder
              else
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (isVideo)
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
