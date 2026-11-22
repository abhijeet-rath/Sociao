import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/feed_repository.dart';
import '../domain/story.dart';
import '../../video/presentation/video_surface.dart';
import 'feed_controller.dart';

final _userStoriesProvider = FutureProvider.autoDispose
    .family<List<Story>, String>(
      (ref, userId) =>
          ref.watch(feedRepositoryProvider).fetchUserStories(userId),
    );

/// Full-screen story viewer: tap right/left to move, auto-advances for
/// photos. Opening a story records a view, which turns the ring grey.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  int _index = 0;
  Timer? _timer;
  static const _photoDuration = Duration(seconds: 5);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(List<Story> stories) {
    _timer?.cancel();
    final story = stories[_index];
    ref.read(feedRepositoryProvider).markStoryViewed(story.id);
    if (story.isVideo) return; // videos are advanced manually
    _timer = Timer(_photoDuration, () => _next(stories));
  }

  void _next(List<Story> stories) {
    if (_index < stories.length - 1) {
      setState(() => _index++);
      _startTimer(stories);
    } else {
      _close();
    }
  }

  void _prev(List<Story> stories) {
    if (_index > 0) {
      setState(() => _index--);
      _startTimer(stories);
    }
  }

  void _close() {
    ref.invalidate(storiesProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final stories = ref.watch(_userStoriesProvider(widget.userId));
    final profile = ref.watch(profileProvider(widget.userId)).value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: stories.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: '$e',
          actionLabel: 'Close',
          onAction: _close,
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              message: 'This story has expired',
              actionLabel: 'Close',
              onAction: _close,
            );
          }
          if (_timer == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _timer == null) _startTimer(list);
            });
          }
          final story = list[_index];
          return Stack(
            fit: StackFit.expand,
            children: [
              if (story.isVideo)
                VideoSurface(key: ValueKey(story.id), url: story.mediaUrl)
              else
                CachedNetworkImage(
                  key: ValueKey(story.id),
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Tap zones: left third = previous, rest = next.
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _prev(list),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => story.isVideo ? null : _next(list),
                      onDoubleTap: () => _next(list),
                    ),
                  ),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: i <= _index
                                      ? Colors.white
                                      : Colors.white30,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          UserAvatar(
                            url: profile?.avatarUrl,
                            name: profile?.displayName ?? '',
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              profile?.username ?? '',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          if (story.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: _close,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
