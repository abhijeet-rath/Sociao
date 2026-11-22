/// A row of the `story_tray` view: one entry per user with active stories.
class StoryItem {
  const StoryItem({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.isLive,
    required this.hasUnseen,
  });

  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final bool isLive;
  final bool hasUnseen;

  /// First name, as shown under the avatar ("Drake").
  String get label {
    final name = fullName.trim().isNotEmpty ? fullName.trim() : username;
    return name.split(RegExp(r'\s+')).first;
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
    userId: json['user_id'] as String,
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    isLive: json['is_live'] as bool? ?? false,
    hasUnseen: json['has_unseen'] as bool? ?? false,
  );
}
