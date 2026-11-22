import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/message_models.dart';
import 'messages_providers.dart';

/// Messages inbox (reference screen 06).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final me = ref.watch(currentUserProvider)?.id;

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
                      'Messages',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Expanded(
              child: inbox.when(
                loading: () => LoadingSkeleton(
                  itemCount: 5,
                  itemBuilder: (_, _) => const ListTile(
                    leading: CircleAvatar(radius: 26),
                    title: Text('Placeholder name'),
                    subtitle: Text('Placeholder last message'),
                  ),
                ),
                error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(inboxProvider),
                ),
                data: (items) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inboxProvider);
                    await ref.read(inboxProvider.future);
                  },
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(
                              height: 400,
                              child: EmptyState(
                                icon: Icons.chat_bubble_outline,
                                message: 'No conversations yet. Open a profile and tap Message to start one.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          itemBuilder: (_, i) =>
                              _InboxRow(item: items[i], me: me),
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

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item, required this.me});

  final InboxItem item;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: item.unread
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.chat(item.conversationId)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: 14,
          ),
          child: Row(
            children: [
              UserAvatar(url: item.avatarUrl, name: item.displayName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          Formatters.messageTime(item.lastMessageAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.lastSenderId == me
                                ? 'You: ${item.lastMessage}'
                                : item.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: item.unread
                                  ? theme.colorScheme.onSurface
                                  : muted,
                            ),
                          ),
                        ),
                        if (item.unread)
                          Container(
                            key: const Key('unread-dot'),
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
