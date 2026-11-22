/// One row of the `inbox()` RPC.
class InboxItem {
  const InboxItem({
    required this.conversationId,
    required this.otherUserId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.unread,
  });

  final String conversationId;
  final String otherUserId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId;
  final bool unread;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    conversationId: json['conversation_id'] as String,
    otherUserId: json['other_user_id'] as String,
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    lastMessage: json['last_message'] as String? ?? '',
    lastMessageAt: DateTime.parse(json['last_message_at'] as String).toLocal(),
    lastSenderId: json['last_sender_id'] as String? ?? '',
    unread: json['unread'] as bool? ?? false,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    body: json['body'] as String? ?? '',
    readAt: json['read_at'] == null
        ? null
        : DateTime.parse(json['read_at'] as String).toLocal(),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

/// Heart reactions summarised for one message.
class ReactionSummary {
  const ReactionSummary({this.count = 0, this.mine = false});

  final int count;
  final bool mine;
}

/// Summarises raw `message_reactions` rows into per-message counts.
Map<String, ReactionSummary> summarizeReactions(
  Iterable<Map<String, dynamic>> rows,
  String? me,
) {
  final counts = <String, int>{};
  final mine = <String>{};
  for (final r in rows) {
    final id = r['message_id'] as String;
    counts[id] = (counts[id] ?? 0) + 1;
    if (r['user_id'] == me) mine.add(id);
  }
  return {
    for (final e in counts.entries)
      e.key: ReactionSummary(count: e.value, mine: mine.contains(e.key)),
  };
}
