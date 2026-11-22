/// A user's public profile plus the numbers shown in the header.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.website,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String bio;
  final String? website;
  final int postsCount;
  final int followersCount;
  final int followingCount;

  /// Whether the signed-in user follows this profile (false for own profile).
  final bool isFollowing;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory Profile.fromJson(
    Map<String, dynamic> profile,
    Map<String, dynamic>? stats, {
    bool isFollowing = false,
  }) => Profile(
    id: profile['id'] as String,
    username: profile['username'] as String? ?? '',
    fullName: profile['full_name'] as String? ?? '',
    avatarUrl: profile['avatar_url'] as String?,
    bio: profile['bio'] as String? ?? '',
    website: profile['website'] as String?,
    postsCount: (stats?['posts_count'] as num?)?.toInt() ?? 0,
    followersCount: (stats?['followers_count'] as num?)?.toInt() ?? 0,
    followingCount: (stats?['following_count'] as num?)?.toInt() ?? 0,
    isFollowing: isFollowing,
  );

  Profile copyWith({bool? isFollowing, int? followersCount}) => Profile(
    id: id,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    bio: bio,
    website: website,
    postsCount: postsCount,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount,
    isFollowing: isFollowing ?? this.isFollowing,
  );
}

/// Compact user row for Followers / Following lists and pickers.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );
}
