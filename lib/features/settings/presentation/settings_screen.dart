import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/settings_controller.dart';

const _languages = <(String, String, bool)>[
  ('en', 'English', true),
  ('es', 'Español', false),
  ('fr', 'Français', false),
  ('de', 'Deutsch', false),
];

String _themeLabel(ThemeMode m) => switch (m) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System',
};

/// Settings (reference screen 11).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    final state = ref.read(authControllerProvider);
    if (state.hasError && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${state.error}')));
    }
    // On success the auth stream fires and the router redirects to /login.
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final enabled = ref.watch(settingsProvider).notificationsEnabled;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SwitchListTile(
                value: enabled,
                title: const Text('Push notifications'),
                subtitle: const Text('Likes, comments, follows and messages'),
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setNotifications(v),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAccount(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? '-'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Member since'),
                subtitle: Text(
                  user?.createdAt == null
                      ? '-'
                      : user!.createdAt.split('T').first,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final langName = _languages
        .firstWhere(
          (l) => l.$1 == settings.language,
          orElse: () => _languages.first,
        )
        .$2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          _Row(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          const SectionHeader('Preferences'),
          _Row(
            icon: Icons.notifications_none,
            label: 'Notifications',
            onTap: () => _showNotifications(context),
          ),
          _MenuRow<ThemeMode>(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            valueLabel: _themeLabel(settings.themeMode),
            items: [
              for (final m in ThemeMode.values)
                PopupMenuItem(value: m, child: Text(_themeLabel(m))),
            ],
            onSelected: notifier.setThemeMode,
          ),
          const SectionHeader('Resources'),
          _Row(
            icon: Icons.settings_outlined,
            label: 'Setting',
            onTap: () => _showAccount(context, ref),
          ),
          _Row(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => context.push(AppRoutes.help),
          ),
          _MenuRow<String>(
            icon: Icons.language,
            label: 'Languages',
            valueLabel: langName,
            items: [
              for (final l in _languages)
                PopupMenuItem(
                  value: l.$1,
                  enabled: l.$3,
                  child: Text(l.$3 ? l.$2 : '${l.$2} (coming soon)'),
                ),
            ],
            onSelected: notifier.setLanguage,
          ),
          _Row(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 22),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBubble(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

/// Row with an inline dropdown on the right ("Light v", "English v").
class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<T>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBubble(icon),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text(valueLabel, style: theme.textTheme.bodyMedium),
            const Icon(Icons.expand_more, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}
