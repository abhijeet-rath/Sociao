import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../feed/domain/post_query.dart';
import '../../feed/presentation/feed_controller.dart';
import '../domain/comment.dart';
import 'comments_controller.dart';

/// Opens the comments bottom sheet for [postId]. [query] identifies the post
/// list whose comment counter should be kept in sync.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String postId,
  required PostQuery query,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _CommentsSheet(postId: postId, query: query, scroll: scroll),
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.query,
    required this.scroll,
  });

  final String postId;
  final PostQuery query;
  final ScrollController scroll;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  Comment? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentsProvider(widget.postId).notifier)
          .add(text, parentId: _replyingTo?.id);
      ref
          .read(postListProvider(widget.query).notifier)
          .bumpComments(widget.postId, 1);
      _input.clear();
      setState(() => _replyingTo = null);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(String id) async {
    try {
      await ref.read(commentsProvider(widget.postId).notifier).toggleLike(id);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _delete(Comment c) async {
    try {
      final removed = await ref
          .read(commentsProvider(widget.postId).notifier)
          .delete(c.id);
      ref
          .read(postListProvider(widget.query).notifier)
          .bumpComments(widget.postId, -removed);
    } catch (e) {
      _toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(commentsProvider(widget.postId));
    final me = ref.watch(currentUserProvider)?.id;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '${comments.value?.length ?? 0} Comments',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: comments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(commentsProvider(widget.postId)),
              ),
              data: (list) {
                final threads = buildThreads(list);
                if (threads.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: 'No comments yet. Start the conversation.',
                  );
                }
                return ListView.separated(
                  controller: widget.scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: threads.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 28, color: theme.colorScheme.outline),
                  itemBuilder: (_, i) => _ThreadView(
                    thread: threads[i],
                    me: me,
                    onLike: _like,
                    onReply: (c) => setState(() => _replyingTo = c),
                    onDelete: _delete,
                  ),
                );
              },
            ),
          ),
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingTo!.username}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel reply',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Comment...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      suffixIcon: _input.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Send comment',
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.thread,
    required this.me,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
  });

  final CommentThread thread;
  final String? me;
  final ValueChanged<String> onLike;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onDelete;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: thread.comment,
          me: me,
          onLike: onLike,
          onReply: onReply,
          onDelete: onDelete,
        ),
        if (thread.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 8),
            child: Container(
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: lineColor, width: 1.5)),
              ),
              child: Column(
                children: [
                  for (final reply in thread.replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CommentTile(
                        comment: reply,
                        me: me,
                        onLike: onLike,
                        onReply: onReply,
                        onDelete: onDelete,
                        avatarSize: 36,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.me,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    this.avatarSize = 44,
  });

  final Comment comment;
  final String? me;
  final ValueChanged<String> onLike;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onDelete;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          url: comment.avatarUrl,
          name: comment.displayName,
          size: avatarSize,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.timeAgo(comment.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const Spacer(),
                  if (comment.userId == me)
                    InkWell(
                      onTap: () => onDelete(comment),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment.body, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MiniPill(
                    icon: comment.likedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor: comment.likedByMe ? AppColors.like : null,
                    label: comment.likesCount > 0
                        ? '${comment.likesCount}'
                        : 'Like',
                    onTap: () => onLike(comment.id),
                  ),
                  const SizedBox(width: 8),
                  _MiniPill(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    onTap: () => onReply(comment),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
