import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../messages/presentation/open_chat.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'profile_controller.dart';

/// Followers / Following list with search (reference screens 12/13).
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({super.key, required this.userId, required this.kind});

  final String userId;
  final FollowListKind kind;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  FollowListKey get _key => (userId: widget.userId, kind: widget.kind);

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _remove(UserSummary user) async {
    final confirmed = await _confirm(
      'Remove follower?',
      '${user.displayName} will no longer follow you.',
      'Remove',
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileRepositoryProvider).removeFollower(user.id);
      ref.invalidate(followListProvider(_key));
      ref.invalidate(profileProvider(widget.userId));
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _unfollow(UserSummary user) async {
    final confirmed = await _confirm(
      'Unfollow ${user.displayName}?',
      'You will stop seeing their stories.',
      'Unfollow',
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileRepositoryProvider).toggleFollow(user.id);
      ref.invalidate(followListProvider(_key));
      ref.invalidate(profileProvider(widget.userId));
      ref.invalidate(myFollowingIdsProvider);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<bool?> _confirm(String title, String body, String action) =>
      showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider)?.id;
    final isOwn = widget.userId == me;
    final isFollowers = widget.kind == FollowListKind.followers;
    final list = ref.watch(followListProvider(_key));
    final myFollowing = ref.watch(myFollowingIdsProvider).value ?? const {};
    final q = _query.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
        ),
        title: Text(isFollowers ? 'Followers' : 'Following'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleIconButton(
              icon: _searching ? Icons.close : Icons.search,
              tooltip: _searching ? 'Close search' : 'Search',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query.clear();
              }),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name or username',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          Expanded(
            child: list.when(
              loading: () => const LoadingSkeleton(itemCount: 6),
              error: (e, _) => ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(followListProvider(_key)),
              ),
              data: (users) {
                final shown = q.isEmpty
                    ? users
                    : users
                          .where(
                            (u) =>
                                u.displayName.toLowerCase().contains(q) ||
                                u.username.toLowerCase().contains(q),
                          )
                          .toList();
                if (shown.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    message: q.isNotEmpty
                        ? 'No matches for "$q"'
                        : (isFollowers
                              ? 'No followers yet'
                              : 'Not following anyone yet'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(followListProvider(_key));
                    await ref.read(followListProvider(_key).future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: theme.colorScheme.outline),
                    itemBuilder: (_, i) {
                      final u = shown[i];
                      // Followers (own list): Message if I follow them back,
                      // otherwise Remove. All other lists: Message.
                      final showRemove =
                          isOwn && isFollowers && !myFollowing.contains(u.id);
                      return InkWell(
                        onTap: () => u.id == me
                            ? context.go(AppRoutes.profile)
                            : context.push(AppRoutes.userProfile(u.id)),
                        onLongPress: isOwn && !isFollowers
                            ? () => _unfollow(u)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              UserAvatar(
                                url: u.avatarUrl,
                                name: u.displayName,
                                size: 60,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      '@${u.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (u.id != me)
                                showRemove
                                    ? TextButton(
                                        onPressed: () => _remove(u),
                                        child: Text(
                                          'Remove',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      )
                                    : OutlinedButton(
                                        onPressed: () =>
                                            openChatWith(context, ref, u.id),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.blue,
                                          shape: const StadiumBorder(),
                                          side: BorderSide(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                        child: const Text('Message'),
                                      ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
