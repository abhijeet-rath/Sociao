import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/domain/profile.dart';
import '../data/messages_repository.dart';
import '../domain/message_models.dart';
import 'messages_providers.dart';

/// One-to-one chat (reference screen 09) with realtime messages and hearts.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  bool _marking = false;
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
    _input.clear();
    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendMessage(widget.conversationId, text);
    } catch (e) {
      _input.text = text; // restore so nothing is lost
      _toast('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleHeart(String messageId, bool currentlyMine) async {
    try {
      await ref
          .read(messagesRepositoryProvider)
          .setHeart(messageId, on: !currentlyMine);
    } catch (e) {
      _toast('$e');
    }
  }

  void _markReadIfNeeded(List<ChatMessage> messages, String? me) {
    if (_marking) return;
    final hasUnread = messages.any((m) => m.senderId != me && m.readAt == null);
    if (!hasUnread) return;
    _marking = true;
    ref
        .read(messagesRepositoryProvider)
        .markRead(widget.conversationId)
        .whenComplete(() => _marking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider)?.id;
    final partner = ref.watch(chatPartnerProvider(widget.conversationId));
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final reactions = ref.watch(reactionsProvider);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(chatMessagesProvider(widget.conversationId), (_, next) {
      final list = next.value;
      if (list != null) _markReadIfNeeded(list, me);
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leading: const BackButton(),
        title: Text(
          partner.value?.displayName ?? '',
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          CircleIconButton(
            icon: Icons.videocam_outlined,
            tooltip: 'Video call',
            onPressed: () => _toast('Calls are coming soon'),
          ),
          const SizedBox(width: 8),
          CircleIconButton(
            icon: Icons.phone_outlined,
            tooltip: 'Voice call',
            onPressed: () => _toast('Calls are coming soon'),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: isDark
                  ? AppColors.darkBackground
                  : const Color(0xFFF5F5F5),
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(
                  message: 'Could not load messages.',
                  onRetry: () => ref.invalidate(
                    chatMessagesProvider(widget.conversationId),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          'Say hi 👋',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _MessageList(
                        messages: list,
                        me: me,
                        partner: partner.value,
                        reactions: reactions,
                        onToggleHeart: _toggleHeart,
                      ),
              ),
            ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
            onAttach: () => _toast('Attachments are coming soon'),
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.me,
    required this.partner,
    required this.reactions,
    required this.onToggleHeart,
  });

  final List<ChatMessage> messages;
  final String? me;
  final UserSummary? partner;
  final Map<String, ReactionSummary> reactions;
  final void Function(String messageId, bool mine) onToggleHeart;

  @override
  Widget build(BuildContext context) {
    // Newest at the bottom: reverse list so it stays anchored there.
    final reversed = messages.reversed.toList();
    final width = MediaQuery.sizeOf(context).width - 32; // list padding
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final m = reversed[i];
        final older = i + 1 < reversed.length ? reversed[i + 1] : null;
        final newer = i > 0 ? reversed[i - 1] : null;
        final startsGroup = older == null || older.senderId != m.senderId;
        final endsGroup = newer == null || newer.senderId != m.senderId;
        final summary = reactions[m.id] ?? const ReactionSummary();
        return Padding(
          padding: EdgeInsets.only(top: startsGroup ? 14 : 4),
          child: _Bubble(
            // Leave room beside the bubble for the avatar (48) and timestamp.
            maxBubbleWidth: (width * 0.72).clamp(
              120.0,
              width - (m.senderId == me ? 90 : 140),
            ),
            message: m,
            isMine: m.senderId == me,
            showAvatar: m.senderId != me && startsGroup,
            showTime: endsGroup,
            partner: partner,
            reaction: summary,
            onToggleHeart: () => onToggleHeart(m.id, summary.mine),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.showTime,
    required this.partner,
    required this.reaction,
    required this.onToggleHeart,
    required this.maxBubbleWidth,
  });

  final double maxBubbleWidth;
  final ChatMessage message;
  final bool isMine;
  final bool showAvatar;
  final bool showTime;
  final UserSummary? partner;
  final ReactionSummary reaction;
  final VoidCallback onToggleHeart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bubbleColor = isMine
        ? (isDark ? theme.colorScheme.primary : AppColors.ink)
        : theme.colorScheme.surface;
    final textColor = isMine
        ? (isDark ? theme.colorScheme.onPrimary : Colors.white)
        : theme.colorScheme.onSurface;
    final time = Text(
      Formatters.messageTime(message.createdAt),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final bubble = GestureDetector(
      onDoubleTap: onToggleHeart,
      onLongPress: onToggleHeart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          message.body,
          style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
        ),
      ),
    );

    final heart = reaction.count > 0
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: onToggleHeart,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: reaction.mine
                          ? AppColors.like
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reaction.count}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (isMine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showTime) ...[time, const SizedBox(width: 10)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [bubble, heart],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 48,
          child: showAvatar
              ? UserAvatar(
                  url: partner?.avatarUrl,
                  name: partner?.displayName ?? '',
                  size: 38,
                )
              : null,
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bubble, heart],
          ),
        ),
        if (showTime) ...[const SizedBox(width: 10), time],
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              InkWell(
                onTap: onAttach,
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Attach',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Message...',
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
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            tooltip: 'Send message',
                            onPressed: sending ? null : onSend,
                            icon: const Icon(Icons.send_rounded),
                          )
                        : const Icon(Icons.graphic_eq, color: AppColors.grey),
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
