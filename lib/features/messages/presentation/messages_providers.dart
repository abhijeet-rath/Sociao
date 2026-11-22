import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../profile/domain/profile.dart';
import '../data/messages_repository.dart';
import '../domain/message_models.dart';

final _messageChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(messagesRepositoryProvider).watchMessageChanges(),
);

/// Conversations with last message and unread flag. Refetches whenever a
/// message is inserted or updated (Realtime), and when the user changes.
final inboxProvider = FutureProvider<List<InboxItem>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  ref.watch(_messageChangesProvider);
  return ref.watch(messagesRepositoryProvider).fetchInbox();
});

/// Number of conversations with unread messages (bottom-nav badge).
final unreadConversationsProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).value?.where((i) => i.unread).length ?? 0,
);

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, conversationId) =>
      ref.watch(messagesRepositoryProvider).watchMessages(conversationId),
);

final _rawReactionsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(messagesRepositoryProvider).watchReactions(),
);

/// Heart counts per message id (for messages I can see).
final reactionsProvider = Provider<Map<String, ReactionSummary>>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  final rows = ref.watch(_rawReactionsProvider).value ?? const [];
  return summarizeReactions(rows, me);
});

final chatPartnerProvider = FutureProvider.family<UserSummary, String>(
  (ref, conversationId) =>
      ref.watch(messagesRepositoryProvider).fetchPartner(conversationId),
);
