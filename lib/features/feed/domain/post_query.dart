enum PostScope { all, user, videos, tagged }

/// Describes which posts a list shows. Used as the key of the post-list
/// provider so Home, the Profile tabs and the Video viewer all share the same
/// pagination and optimistic like/bookmark logic.
class PostQuery {
  const PostQuery._(this.scope, this.userId);

  /// Everyone's posts (Home feed).
  static const home = PostQuery._(PostScope.all, null);

  /// Everyone's videos (Video viewer).
  static const videos = PostQuery._(PostScope.videos, null);

  /// One user's posts (Profile "Post" tab).
  factory PostQuery.userPosts(String userId) =>
      PostQuery._(PostScope.user, userId);

  /// One user's videos (Profile "Video" tab).
  factory PostQuery.userVideos(String userId) =>
      PostQuery._(PostScope.videos, userId);

  /// Posts a user is tagged in (Profile "Tag" tab).
  factory PostQuery.tagged(String userId) =>
      PostQuery._(PostScope.tagged, userId);

  final PostScope scope;
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is PostQuery && other.scope == scope && other.userId == userId;

  @override
  int get hashCode => Object.hash(scope, userId);
}
