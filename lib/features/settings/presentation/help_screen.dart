import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

const _faqs = <(String, String)>[
  (
    'How do I change my profile photo?',
    'Go to Profile, tap Edit Profile, then tap the pencil on your photo.',
  ),
  (
    'How do I post a photo or video?',
    'Tap the + button in the bottom bar, choose Photo or Video, add a caption and tap Post.',
  ),
  (
    'How do I remove a follower?',
    'Open Profile, tap Followers, then tap Remove next to their name.',
  ),
  (
    'How do I switch to dark mode?',
    'Open Settings and choose Light, Dark or System under Dark Mode.',
  ),
  (
    'I forgot my password',
    'Password reset by email is coming soon. For now, contact the app administrator.',
  ),
];

/// Help & Support: a short FAQ.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
        ),
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final faq in _faqs)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(faq.$1, style: theme.textTheme.titleSmall),
              childrenPadding: const EdgeInsets.only(bottom: 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(faq.$2, style: theme.textTheme.bodyLarge)],
            ),
        ],
      ),
    );
  }
}
