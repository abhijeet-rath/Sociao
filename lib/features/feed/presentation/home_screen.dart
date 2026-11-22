import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../notifications/data/notifications_repository.dart';
import '../domain/post_query.dart';
import 'feed_controller.dart';
import 'widgets/post_card_for.dart';
import 'widgets/stories_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(postListProvider(PostQuery.home).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    ref.invalidate(storiesProvider);
    await ref.read(postListProvider(PostQuery.home).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(postListProvider(PostQuery.home));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Social',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Badge(
                    isLabelVisible: ref.watch(unreadNotificationsProvider) > 0,
                    smallSize: 10,
                    child: CircleIconButton(
                      icon: Icons.notifications_none,
                      tooltip: 'Notifications',
                      onPressed: () => context.push(AppRoutes.notifications),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleIconButton(
                    icon: Icons.chat_bubble_outline,
                    tooltip: 'Messages',
                    onPressed: () => context.go(AppRoutes.inbox),
                  ),
                ],
              ),
            ),
            Expanded(
              child: feed.when(
                loading: () => const LoadingSkeleton(itemCount: 3),
                error: (e, _) => ErrorState(
                  message: e is Exception
                      ? '$e'
                      : 'Could not load your feed. Please try again.',
                  onRetry: () =>
                      ref.invalidate(postListProvider(PostQuery.home)),
                ),
                data: (state) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: state.posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            StoriesRow(
                              onAddStory: () =>
                                  context.push(AppRoutes.createStory),
                              onOpen: (_) =>
                                  _toast('Story viewer is coming soon'),
                            ),
                            SizedBox(
                              height: 320,
                              child: EmptyState(
                                icon: Icons.photo_library_outlined,
                                message: 'No posts yet. Follow people or share your first post.',
                                actionLabel: 'Create a post',
                                onAction: () => context.push(AppRoutes.create),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: state.posts.length + 2,
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: StoriesRow(
                                  onAddStory: () =>
                                      context.push(AppRoutes.createStory),
                                  onOpen: (story) => context.push(
                                    AppRoutes.story(story.userId),
                                  ),
                                ),
                              );
                            }
                            if (i == state.posts.length + 1) {
                              return SizedBox(
                                height: 56,
                                child: state.loadingMore
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.grey,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            }
                            final post = state.posts[i - 1];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.page,
                                0,
                                AppSpacing.page,
                                16,
                              ),
                              child: PostCardFor(
                                key: ValueKey(post.id),
                                post: post,
                                query: PostQuery.home,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
