import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sociao/core/supabase/supabase_client.dart';
import 'package:sociao/core/theme/app_theme.dart';
import 'package:sociao/core/utils/formatters.dart';
import 'package:sociao/features/messages/domain/message_models.dart';
import 'package:sociao/features/messages/presentation/inbox_screen.dart';
import 'package:sociao/features/messages/presentation/messages_providers.dart';
import 'package:sociao/features/profile/domain/profile.dart';
import 'package:sociao/features/settings/data/settings_controller.dart';
import 'package:sociao/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('choosing Dark in Settings updates and persists the theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    expect(container.read(settingsProvider).themeMode, ThemeMode.light);

    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(prefs.getString('theme'), 'dark');
    expect(find.text('Dark'), findsOneWidget); // shown as the row's value
  });

  testWidgets('Settings lists every row from the reference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    for (final label in [
      'Edit Profile',
      'Notifications',
      'Dark Mode',
      'Help & Support',
      'Languages',
      'Sign Out',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('inbox shows unread dot only for unread conversations', (
    tester,
  ) async {
    InboxItem item(String id, String name, bool unread) => InboxItem(
      conversationId: id,
      otherUserId: 'o$id',
      username: name.toLowerCase(),
      fullName: name,
      avatarUrl: null,
      lastMessage: 'hello $name',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 3)),
      lastSenderId: 'o$id',
      unread: unread,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          inboxProvider.overrideWith(
            (ref) async => [
              item('1', 'Ahmad', true),
              item('2', 'Randy', false),
            ],
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ahmad'), findsOneWidget);
    expect(find.text('Randy'), findsOneWidget);
    expect(find.text('3 min ago'), findsNWidgets(2));
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  test('messageTime uses short reference-style labels', () {
    DateTime ago(Duration d) => DateTime.now().subtract(d);
    expect(
      Formatters.messageTime(ago(const Duration(seconds: 10))),
      'Just now',
    );
    expect(
      Formatters.messageTime(ago(const Duration(minutes: 3))),
      '3 min ago',
    );
    expect(Formatters.messageTime(ago(const Duration(hours: 2))), '2 hr ago');
    expect(Formatters.messageTime(ago(const Duration(days: 2))), '2 d ago');
  });

  test('Profile and UserSummary parse database rows', () {
    final p = Profile.fromJson(
      {
        'id': 'u',
        'username': 'gustavo.levin',
        'full_name': 'Gustavo Levin',
        'bio': 'b',
      },
      {'posts_count': 24, 'followers_count': 12800, 'following_count': 490},
      isFollowing: true,
    );
    expect(p.displayName, 'Gustavo Levin');
    expect(Formatters.compact(p.followersCount), '12,8k');
    expect(p.isFollowing, isTrue);
    final toggled = p.copyWith(isFollowing: false, followersCount: 12799);
    expect(toggled.followersCount, 12799);
    expect(
      UserSummary.fromJson({'id': 'x', 'username': 'u', 'full_name': ''})
          .displayName,
      'u',
    );
  });
}
