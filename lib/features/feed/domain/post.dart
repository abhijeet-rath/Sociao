enum MediaType {
  none,
  image,
  video;

  static MediaType parse(String? value) => switch (value) {
    'image' => MediaType.image,
    'video' => MediaType.video,
    _ => MediaType.none,
  };
}

/// A row of the `post_feed` view (post + author + my like/bookmark state).
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.musicTitle,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.savesCount,
    required this.viewsCount,
    required this.createdAt,
    required this.likedByMe,
    required this.bookmarkedByMe,
  });

  final String id;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String caption;
  final MediaType mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? musicTitle;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;
  final int viewsCount;
  final DateTime createdAt;
  final bool likedByMe;
  final bool bookmarkedByMe;

  bool get isVideo => mediaType == MediaType.video;

  /// Image shown in the feed: the image itself, or a video's thumbnail.
  String? get previewUrl => isVideo ? thumbnailUrl : mediaUrl;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    caption: json['caption'] as String? ?? '',
    mediaType: MediaType.parse(json['media_type'] as String?),
    mediaUrl: json['media_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    musicTitle: json['music_title'] as String?,
    likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
    commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
    sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
    savesCount: (json['saves_count'] as num?)?.toInt() ?? 0,
    viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    likedByMe: json['liked_by_me'] as bool? ?? false,
    bookmarkedByMe: json['bookmarked_by_me'] as bool? ?? false,
  );

  Post copyWith({
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? savesCount,
    bool? likedByMe,
    bool? bookmarkedByMe,
  }) => Post(
    id: id,
    userId: userId,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    caption: caption,
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    thumbnailUrl: thumbnailUrl,
    musicTitle: musicTitle,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    sharesCount: sharesCount ?? this.sharesCount,
    savesCount: savesCount ?? this.savesCount,
    viewsCount: viewsCount,
    createdAt: createdAt,
    likedByMe: likedByMe ?? this.likedByMe,
    bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
  );
}
