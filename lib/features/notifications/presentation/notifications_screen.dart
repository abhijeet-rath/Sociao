import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedOnce = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(notificationsProvider);

    // Opening the screen marks everything read (after the list is shown once,
    // so unread items still render highlighted on first paint).
    ref.listen(notificationsProvider, (_, next) {
      final list = next.value;
      if (!_markedOnce && list != null && list.any((n) => !n.isRead)) {
        _markedOnce = true;
        Future.delayed(const Duration(seconds: 2), () async {
          await ref
              .read(notificationsRepositoryProvider)
              .markAllRead()
              .catchError((_) {});
        });
      }
    });

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
        title: const Text('Notifications'),
      ),
      body: items.when(
        loading: () => const LoadingSkeleton(itemCount: 6),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none,
                message: 'No notifications yet',
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  await ref.read(notificationsProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.colorScheme.outline),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    return Material(
                      color: n.isRead
                          ? Colors.transparent
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                      child: InkWell(
                        onTap: n.actorId == null
                            ? null
                            : () => context.push(
                                AppRoutes.userProfile(n.actorId!),
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                url: n.actorAvatarUrl,
                                name: n.actorName,
                                size: 48,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: n.actorName,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          TextSpan(
                                            text: ' ${n.message}',
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Formatters.timeAgo(n.createdAt),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppColors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
