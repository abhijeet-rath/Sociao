import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../feed/presentation/feed_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'profile_controller.dart';

/// Edit Profile (reference screen 10).
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null ? null : ref.watch(profileProvider(me));

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        title: const Text('Edit Profile'),
      ),
      body: profile == null
          ? const SizedBox.shrink()
          : profile.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(profileProvider(me!)),
              ),
              data: (p) => _EditForm(profile: p),
            ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _username = TextEditingController(text: widget.profile.username);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _website = TextEditingController(
    text: widget.profile.website ?? '',
  );
  XFile? _newAvatar;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _website.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file != null) setState(() => _newAvatar = file);
  }

  String? _validateWebsite(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );
    return (uri == null || !uri.host.contains('.'))
        ? 'Enter a valid link'
        : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    try {
      final username = _username.text
          .trim()
          .replaceFirst('@', '')
          .toLowerCase();
      if (username != widget.profile.username &&
          !await repo.isUsernameAvailable(username)) {
        _toast('That username is already taken.');
        return;
      }
      String? avatarUrl;
      if (_newAvatar != null) {
        avatarUrl = await repo.uploadAvatar(
          await _newAvatar!.readAsBytes(),
          _newAvatar!.mimeType ?? 'image/jpeg',
        );
      }
      await repo.updateProfile(
        fullName: _name.text.trim(),
        username: username,
        bio: _bio.text.trim(),
        website: _website.text.trim(),
        avatarUrl: avatarUrl,
      );
      ref.invalidate(profileProvider(widget.profile.id));
      // Feed cards show author info, so refresh every cached post list.
      ref.invalidate(postListProvider);
      if (mounted) {
        _toast('Profile saved');
        context.pop();
      }
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Stack(
                children: [
                  _newAvatar == null
                      ? UserAvatar(
                          url: widget.profile.avatarUrl,
                          name: widget.profile.displayName,
                          size: 110,
                        )
                      : FutureBuilder(
                          future: _newAvatar!.readAsBytes(),
                          builder: (_, snap) => ClipOval(
                            child: SizedBox(
                              width: 110,
                              height: 110,
                              child: snap.hasData
                                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                                  : const ColoredBox(color: AppColors.chip),
                            ),
                          ),
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: theme.colorScheme.surface,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.edit_outlined, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Name',
              controller: _name,
              textInputAction: TextInputAction.next,
              validator: Validators.fullName,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Username',
              controller: _username,
              prefixText: '@',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.username((v ?? '').replaceFirst('@', '')),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Bio',
              controller: _bio,
              maxLines: 5,
              validator: (v) => (v ?? '').length > 200
                  ? 'Keep it under 200 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Link',
              hint: 'yourwebsite.com',
              controller: _website,
              keyboardType: TextInputType.url,
              validator: _validateWebsite,
            ),
            const SizedBox(height: 28),
            AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
