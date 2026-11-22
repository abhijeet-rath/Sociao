/// One story item (a row of `stories`).
class Story {
  const Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.isVideo,
    required this.isLive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String mediaUrl;
  final bool isVideo;
  final bool isLive;
  final DateTime createdAt;

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    mediaUrl: json['media_url'] as String,
    isVideo: json['media_type'] == 'video',
    isLive: json['is_live'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}
