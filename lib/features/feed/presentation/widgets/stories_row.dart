import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/story_item.dart';
import '../feed_controller.dart';

/// Horizontal stories row: "Add Story" first, then people I follow.
/// Ring colour: red = live (with "Live" badge), blue = unseen, none = seen.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key, required this.onAddStory, required this.onOpen});

  final VoidCallback onAddStory;
  final ValueChanged<StoryItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider);
    final items = stories.value ?? const <StoryItem>[];

    return SizedBox(
      height: 104,
      child: Skeletonizer(
        enabled: stories.isLoading,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          itemCount: stories.isLoading ? 5 : items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            if (stories.isLoading) {
              return const _Tile(
                label: 'Loading',
                child: CircleAvatar(radius: 32),
              );
            }
            if (i == 0) {
              return _Tile(
                label: 'Add Story',
                onTap: onAddStory,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              );
            }
            final story = items[i - 1];
            final ring = story.isLive
                ? AppColors.like
                : story.hasUnseen
                ? AppColors.blue
                : Theme.of(context).colorScheme.outline;
            return _Tile(
              label: story.label,
              onTap: () => onOpen(story),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  UserAvatar(
                    url: story.avatarUrl,
                    name: story.fullName,
                    size: 58,
                    ringColor: ring,
                  ),
                  if (story.isLive)
                    const Positioned(bottom: -4, child: _LiveBadge()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            SizedBox(height: 68, child: Center(child: child)),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Live',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
