import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/create/presentation/create_screen.dart';
import '../../features/feed/presentation/home_screen.dart';
import '../../features/feed/presentation/story_viewer_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/messages/presentation/inbox_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/follow_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/video/presentation/video_screen.dart';
import '../supabase/supabase_client.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const video = '/video';
  static const inbox = '/inbox';
  static const profile = '/profile';
  static const create = '/create';
  static const createStory = '/create?mode=story';
  static const settings = '/settings';
  // (routes below are full-screen, pushed above the tab shell)
  static const notifications = '/notifications';
  static const editProfile = '/edit-profile';
  static const help = '/help';

  static String userProfile(String id) => '/u/$id';
  static String followers(String id) => '/u/$id/followers';
  static String following(String id) => '/u/$id/following';
  static String videoViewer(String postId) => '/video-viewer/$postId';
  static String chat(String conversationId) => '/chat/$conversationId';
  static String story(String userId) => '/story/$userId';
}

/// Re-runs the router redirect whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  final rootKey = GlobalKey<NavigatorState>();

  // Full-screen routes pushed above the tab shell (no bottom bar).
  GoRoute full(
    String path,
    Widget Function(BuildContext, GoRouterState) builder,
  ) => GoRoute(path: path, parentNavigatorKey: rootKey, builder: builder);

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == AppRoutes.login || loc == AppRoutes.signup;
      if (!loggedIn) return onAuthPage ? null : AppRoutes.login;
      if (onAuthPage) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, _) => const SignupScreen()),
      full(
        AppRoutes.create,
        (_, s) => CreateScreen(
          initialMode: s.uri.queryParameters['mode'] == 'story'
              ? CreateMode.story
              : CreateMode.post,
        ),
      ),
      full(AppRoutes.settings, (_, _) => const SettingsScreen()),
      full(AppRoutes.notifications, (_, _) => const NotificationsScreen()),
      full(AppRoutes.editProfile, (_, _) => const EditProfileScreen()),
      full(AppRoutes.help, (_, _) => const HelpScreen()),
      full(
        '/u/:userId',
        (_, s) => ProfileScreen(userId: s.pathParameters['userId']),
      ),
      full(
        '/u/:userId/followers',
        (_, s) => FollowListScreen(
          userId: s.pathParameters['userId']!,
          kind: FollowListKind.followers,
        ),
      ),
      full(
        '/u/:userId/following',
        (_, s) => FollowListScreen(
          userId: s.pathParameters['userId']!,
          kind: FollowListKind.following,
        ),
      ),
      full(
        '/video-viewer/:postId',
        (_, s) => VideoScreen(initialPostId: s.pathParameters['postId']),
      ),
      full(
        '/chat/:conversationId',
        (_, s) =>
            ChatScreen(conversationId: s.pathParameters['conversationId']!),
      ),
      full(
        '/story/:userId',
        (_, s) => StoryViewerScreen(userId: s.pathParameters['userId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.video,
                builder: (_, _) => const VideoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inbox,
                builder: (_, _) => const InboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
