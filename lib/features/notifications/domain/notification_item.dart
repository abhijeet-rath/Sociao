class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.postId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String? actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;

  /// Sentence shown next to the actor's name.
  String get message => switch (type) {
    'like' => 'liked your post',
    'comment' => 'commented on your post',
    'follow' => 'started following you',
    'message' => 'sent you a message',
    _ => 'interacted with you',
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final actor = (json['actor'] as Map<String, dynamic>?) ?? const {};
    final full = actor['full_name'] as String? ?? '';
    return NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String,
      actorId: json['actor_id'] as String?,
      actorName: full.isNotEmpty
          ? full
          : (actor['username'] as String? ?? 'Someone'),
      actorAvatarUrl: actor['avatar_url'] as String?,
      postId: json['post_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
