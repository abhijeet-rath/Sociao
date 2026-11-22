import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/pill_stat.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../feed/domain/post.dart';
import '../../feed/domain/post_query.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../feed/presentation/widgets/post_card_for.dart';
import '../../messages/presentation/open_chat.dart';
import '../domain/profile.dart';
import 'profile_controller.dart';

enum _Tab { post, video, tag }

/// Profile (reference screens 07/08). With no [userId] it shows my own
/// profile (the bottom-nav tab); otherwise another user's profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _Tab _tab = _Tab.post;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 500) {
        final id = _userId;
        if (id != null) {
          ref.read(postListProvider(_queryFor(id)).notifier).loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? get _userId => widget.userId ?? ref.read(currentUserProvider)?.id;

  PostQuery _queryFor(String id) => switch (_tab) {
    _Tab.post => PostQuery.userPosts(id),
    _Tab.video => PostQuery.userVideos(id),
    _Tab.tag => PostQuery.tagged(id),
  };

  Future<void> _refresh(String id) async {
    ref.invalidate(profileProvider(id));
    ref.invalidate(postListProvider(_queryFor(id)));
    await ref.read(postListProvider(_queryFor(id)).future);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final id = widget.userId ?? me;
    if (id == null) return const Scaffold();
    final isOwn = id == me;
    final profile = ref.watch(profileProvider(id));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: !isOwn,
        leading: isOwn ? null : const BackButton(),
        titleSpacing: isOwn ? AppSpacing.page : 0,
        title: Text(
          isOwn ? 'Profile' : (profile.value?.username ?? ''),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (isOwn)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.page),
              child: CircleIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingSkeleton(itemCount: 3),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(profileProvider(id)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => _refresh(id),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    4,
                    AppSpacing.page,
                    16,
                  ),
                  child: _Header(profile: p, isOwn: isOwn),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _TabSwitch(
                    value: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _TabContent(tab: _tab, userId: id, query: _queryFor(id)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile, required this.isOwn});

  final Profile profile;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                url: profile.avatarUrl,
                name: profile.displayName,
                size: 64,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '@${profile.username}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(profile.bio, style: theme.textTheme.bodyLarge),
          ],
          if (profile.website != null && profile.website!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openWebsite(context, profile.website!),
              child: Text(
                profile.website!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillStat(
                  value: Formatters.compact(profile.followingCount),
                  label: 'Following',
                  onTap: () => context.push(AppRoutes.following(profile.id)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillStat(
                  value: Formatters.compact(profile.followersCount),
                  label: 'Followers',
                  onTap: () => context.push(AppRoutes.followers(profile.id)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillStat(
                  value: Formatters.compact(profile.postsCount),
                  label: 'Posts',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isOwn)
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.editProfile),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Edit Profile'),
            )
          else
            Row(
              children: [
                Expanded(child: _FollowButton(profile: profile)),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => openChatWith(context, ref, profile.id),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context, String site) async {
    final uri = Uri.tryParse(site.startsWith('http') ? site : 'https://$site');
    if (uri == null || !await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      label: profile.isFollowing ? 'Following' : 'Follow',
      onPressed: () async {
        try {
          await ref.read(profileProvider(profile.id).notifier).toggleFollow();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.value, required this.onChanged});

  final _Tab value;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(_Tab tab, IconData icon, String label) {
      final selected = tab == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            onTap: () => onChanged(tab),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: selected ? scheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        children: [
          item(_Tab.post, Icons.grid_view_rounded, 'Post'),
          item(_Tab.video, Icons.smart_display_outlined, 'Video'),
          item(_Tab.tag, Icons.person_pin_outlined, 'Tag'),
        ],
      ),
    );
  }
}

class _TabContent extends ConsumerWidget {
  const _TabContent({
    required this.tab,
    required this.userId,
    required this.query,
  });

  final _Tab tab;
  final String userId;
  final PostQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(postListProvider(query));
    return list.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(postListProvider(query)),
          ),
        ),
      ),
      data: (state) {
        if (state.posts.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: EmptyState(
                icon: switch (tab) {
                  _Tab.post => Icons.grid_view_rounded,
                  _Tab.video => Icons.smart_display_outlined,
                  _Tab.tag => Icons.person_pin_outlined,
                },
                message: switch (tab) {
                  _Tab.post => 'No posts yet',
                  _Tab.video => 'No videos yet',
                  _Tab.tag => 'No tagged posts yet',
                },
              ),
            ),
          );
        }
        if (tab == _Tab.post) {
          return SliverList.separated(
            itemCount: state.posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: PostCardFor(
                key: ValueKey(state.posts[i].id),
                post: state.posts[i],
                query: query,
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          sliver: SliverGrid.builder(
            itemCount: state.posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, i) => _GridTile(post: state.posts[i]),
          ),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = post.previewUrl;
    return GestureDetector(
      onTap: post.isVideo
          ? () => context.push(AppRoutes.videoViewer(post.id))
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            if (preview != null)
              CachedNetworkImage(
                imageUrl: preview,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              )
            else
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  post.caption,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (post.isVideo) ...[
              if (preview == null)
                const Center(child: Icon(Icons.play_circle_outline, size: 40)),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.count(post.viewsCount),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
