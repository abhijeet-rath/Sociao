import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Bottom bar: Home, Video, centred dark "+" pill, Inbox, Profile.
/// [currentIndex] maps to the four tab branches (the + is an action only).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.onCreate,
    this.inboxBadge = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreate;

  /// Number of conversations with unread messages (0 hides the badge).
  final int inboxBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NavItem(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    selected: currentIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _NavItem(
                    label: 'Video',
                    icon: Icons.smart_display_outlined,
                    activeIcon: Icons.smart_display,
                    selected: currentIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  // A min-size Column (not Center): Center would expand to the
                  // full screen height and swallow the page body.
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Create',
                          child: Material(
                            color: scheme.primary,
                            shape: const StadiumBorder(),
                            elevation: 6,
                            shadowColor: AppColors.ink.withValues(alpha: 0.25),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: onCreate,
                              child: SizedBox(
                                width: 76,
                                height: 56,
                                child: Icon(Icons.add, color: scheme.onPrimary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NavItem(
                    label: 'Inbox',
                    badge: inboxBadge,
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    selected: currentIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                  _NavItem(
                    label: 'Profile',
                    icon: Icons.account_circle_outlined,
                    activeIcon: Icons.account_circle,
                    selected: currentIndex == 3,
                    onTap: () => onSelected(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final int badge;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(
                  selected ? activeIcon : icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
