import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';

/// A picked file ready to upload.
class PickedMedia {
  const PickedMedia({
    required this.bytes,
    required this.extension,
    required this.contentType,
    required this.isVideo,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
  final bool isVideo;
}

class CreateRepository {
  const CreateRepository(this._client);

  final SupabaseClient _client;

  static const _uuid = Uuid();

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('You are signed out.');
    return id;
  }

  Future<String> _upload(String bucket, String path, PickedMedia media) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          media.bytes,
          fileOptions: FileOptions(contentType: media.contentType),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Uploads the media (if any), inserts the post and tags. The post id is
  /// generated here so the storage path can contain it.
  Future<void> createPost({
    required String caption,
    PickedMedia? media,
    String? musicTitle,
    List<String> taggedUserIds = const [],
  }) async {
    final me = _me;
    final id = _uuid.v4();
    try {
      String? mediaUrl;
      if (media != null) {
        mediaUrl = media.isVideo
            ? await _upload('videos', '$me/$id/video.${media.extension}', media)
            : await _upload('posts', '$me/$id/image.${media.extension}', media);
      }
      await _client.from('posts').insert({
        'id': id,
        'user_id': me,
        'caption': caption.trim(),
        'media_type': media == null
            ? 'none'
            : (media.isVideo ? 'video' : 'image'),
        'media_url': mediaUrl,
        'music_title': (musicTitle == null || musicTitle.trim().isEmpty)
            ? null
            : musicTitle.trim(),
      });
      if (taggedUserIds.isNotEmpty) {
        await _client.from('post_tags').insert([
          for (final u in taggedUserIds) {'post_id': id, 'tagged_user_id': u},
        ]);
      }
    } on StorageException catch (e) {
      throw AppException(
        e.message.toLowerCase().contains('size')
            ? 'That file is too large.'
            : 'Could not upload your media.',
        cause: e,
      );
    } catch (e) {
      throw AppException('Could not publish your post.', cause: e);
    }
  }

  Future<void> createStory(PickedMedia media) async {
    final me = _me;
    final id = _uuid.v4();
    try {
      final url = await _upload('stories', '$me/$id.${media.extension}', media);
      await _client.from('stories').insert({
        'id': id,
        'user_id': me,
        'media_url': url,
        'media_type': media.isVideo ? 'video' : 'image',
      });
    } catch (e) {
      throw AppException('Could not share your story.', cause: e);
    }
  }
}

final createRepositoryProvider = Provider<CreateRepository>(
  (ref) => CreateRepository(ref.watch(supabaseClientProvider)),
);
