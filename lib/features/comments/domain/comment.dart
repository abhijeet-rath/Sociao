class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.parentId,
    required this.body,
    required this.likesCount,
    required this.createdAt,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.likedByMe,
  });

  final String id;
  final String postId;
  final String userId;
  final String? parentId;
  final String body;
  final int likesCount;
  final DateTime createdAt;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final bool likedByMe;

  bool get isReply => parentId != null;
  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory Comment.fromJson(
    Map<String, dynamic> json, {
    bool likedByMe = false,
  }) {
    final author = (json['author'] as Map<String, dynamic>?) ?? const {};
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      body: json['body'] as String? ?? '',
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      username: author['username'] as String? ?? '',
      fullName: author['full_name'] as String? ?? '',
      avatarUrl: author['avatar_url'] as String?,
      likedByMe: likedByMe,
    );
  }

  Comment copyWith({int? likesCount, bool? likedByMe}) => Comment(
    id: id,
    postId: postId,
    userId: userId,
    parentId: parentId,
    body: body,
    likesCount: likesCount ?? this.likesCount,
    createdAt: createdAt,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}

/// A top-level comment with its (single level of) replies, oldest first.
class CommentThread {
  const CommentThread(this.comment, this.replies);

  final Comment comment;
  final List<Comment> replies;
}

/// Groups a flat, chronologically ordered list into threads. Replies whose
/// parent is missing are ignored.
List<CommentThread> buildThreads(List<Comment> all) {
  final tops = all.where((c) => !c.isReply).toList();
  return [
    for (final top in tops)
      CommentThread(top, all.where((c) => c.parentId == top.id).toList()),
  ];
}
