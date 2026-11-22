import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../messages/presentation/messages_providers.dart';
import 'app_bottom_nav.dart';

/// Hosts the four tab branches and the floating bottom navigation bar.
/// The bar is hidden on the full-screen Video tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _videoTab = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: index == _videoTab
          ? null
          : AppBottomNav(
              currentIndex: index,
              inboxBadge: ref.watch(unreadConversationsProvider),
              onSelected: (i) =>
                  navigationShell.goBranch(i, initialLocation: i == index),
              onCreate: () => context.push(AppRoutes.create),
            ),
    );
  }
}
