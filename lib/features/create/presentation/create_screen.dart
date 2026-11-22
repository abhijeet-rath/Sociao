import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/create_repository.dart';

enum CreateMode { post, story }

/// Create Post / Story. Designed to match the other screens (no reference).
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key, this.initialMode = CreateMode.post});

  final CreateMode initialMode;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  late CreateMode _mode = widget.initialMode;
  final _caption = TextEditingController();
  final _music = TextEditingController();
  PickedMedia? _media;
  List<UserSummary> _tagged = [];
  bool _publishing = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _music.dispose();
    super.dispose();
  }

  bool get _canPublish {
    if (_publishing) return false;
    return _mode == CreateMode.story
        ? _media != null
        : (_caption.text.trim().isNotEmpty || _media != null);
  }

  Future<void> _pick({required bool video}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 85,
          );
    if (file == null) return;
    final name = file.name.toLowerCase();
    final ext = name.contains('.')
        ? name.split('.').last
        : (video ? 'mp4' : 'jpg');
    final mime = file.mimeType ?? _mimeFor(ext, video);
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _media = PickedMedia(
        bytes: bytes,
        extension: ext,
        contentType: mime,
        isVideo: video,
      );
      _error = null;
    });
  }

  String _mimeFor(String ext, bool video) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mp4' => 'video/mp4',
    _ => video ? 'video/mp4' : 'image/jpeg',
  };

  Future<void> _chooseTags() async {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null) return;
    final picked = await showModalBottomSheet<List<UserSummary>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagPicker(selected: _tagged, userId: me),
    );
    if (picked != null) setState(() => _tagged = picked);
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    final repo = ref.read(createRepositoryProvider);
    try {
      if (_mode == CreateMode.story) {
        await repo.createStory(_media!);
      } else {
        await repo.createPost(
          caption: _caption.text,
          media: _media,
          musicTitle: _media?.isVideo == true ? _music.text : null,
          taggedUserIds: _tagged.map((u) => u.id).toList(),
        );
      }
      ref.invalidate(postListProvider);
      ref.invalidate(storiesProvider);
      final me = ref.read(currentUserProvider)?.id;
      if (me != null) ref.invalidate(profileProvider(me));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == CreateMode.story ? 'Story shared' : 'Post published',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null ? null : ref.watch(profileProvider(me)).value;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton.icon(
          onPressed: _publishing ? null : () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
        ),
        title: const Text('Create'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: _mode == CreateMode.story ? 'Share' : 'Post',
              expand: false,
              isLoading: _publishing,
              onPressed: _canPublish ? _publish : null,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ModeSwitch(
              value: _mode,
              onChanged: _publishing ? null : (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 16),
            if (_mode == CreateMode.post)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          url: profile?.avatarUrl,
                          name: profile?.displayName ?? '',
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          profile?.username ?? '',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _caption,
                      maxLines: 6,
                      minLines: 3,
                      maxLength: 2200,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MediaArea(
                      media: _media,
                      onPickPhoto: () => _pick(video: false),
                      onPickVideo: () => _pick(video: true),
                      onRemove: () => setState(() => _media = null),
                    ),
                  ],
                ),
              )
            else
              _MediaArea(
                media: _media,
                tall: true,
                onPickPhoto: () => _pick(video: false),
                onPickVideo: () => _pick(video: true),
                onRemove: () => setState(() => _media = null),
              ),
            if (_mode == CreateMode.post) ...[
              const SizedBox(height: 16),
              _OptionRow(
                icon: Icons.person_add_alt,
                label: 'Tag people',
                value: _tagged.isEmpty
                    ? null
                    : _tagged.map((u) => '@${u.username}').join(', '),
                onTap: _chooseTags,
              ),
              if (_media?.isVideo == true) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note_outlined, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _music,
                          decoration: const InputDecoration(
                            hintText: 'Add music (artist - title)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                  TextButton(onPressed: _publish, child: const Text('Retry')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final CreateMode value;
  final ValueChanged<CreateMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(CreateMode mode, String label) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            onTap: onChanged == null ? null : () => onChanged!(mode),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        children: [
          item(CreateMode.post, 'Post'),
          item(CreateMode.story, 'Story'),
        ],
      ),
    );
  }
}

class _MediaArea extends StatelessWidget {
  const _MediaArea({
    required this.media,
    required this.onPickPhoto,
    required this.onPickVideo,
    required this.onRemove,
    this.tall = false,
  });

  final PickedMedia? media;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickVideo;
  final VoidCallback onRemove;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = tall ? 360.0 : 220.0;

    if (media != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media!.isVideo)
                ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.play_circle_outline, size: 56),
                  ),
                )
              else
                Image.memory(media!.bytes, fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Remove media',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: tall ? height : 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onPickPhoto,
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Photo'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              ),
              OutlinedButton.icon(
                onPressed: onPickVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Video'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              ),
            ],
          ),
          if (kIsWeb) const SizedBox(height: 0),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  if (value != null)
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.blue,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

/// Searchable list of the people I follow, multi-select.
class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.selected, required this.userId});

  final List<UserSummary> selected;
  final String userId;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  late final Set<String> _ids = widget.selected.map((u) => u.id).toSet();
  final _known = <String, UserSummary>{};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(
      followListProvider((
        userId: widget.userId,
        kind: FollowListKind.following,
      )),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search people you follow',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: following.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (users) {
                  for (final u in users) {
                    _known[u.id] = u;
                  }
                  final shown = users
                      .where(
                        (u) =>
                            u.displayName.toLowerCase().contains(_q) ||
                            u.username.contains(_q),
                      )
                      .toList();
                  if (shown.isEmpty) {
                    return const Center(child: Text('No one found'));
                  }
                  return ListView(
                    children: [
                      for (final u in shown)
                        CheckboxListTile(
                          value: _ids.contains(u.id),
                          onChanged: (v) => setState(
                            () =>
                                v == true ? _ids.add(u.id) : _ids.remove(u.id),
                          ),
                          secondary: UserAvatar(
                            url: u.avatarUrl,
                            name: u.displayName,
                            size: 40,
                          ),
                          title: Text(u.displayName),
                          subtitle: Text('@${u.username}'),
                        ),
                    ],
                  );
                },
              ),
            ),
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context, [
                for (final id in _ids)
                  if (_known[id] != null) _known[id]!,
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
