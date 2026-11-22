import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';
import '../domain/notification_item.dart';

class NotificationsRepository {
  const NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<NotificationItem>> fetch() async {
    try {
      final rows = await _client
          .from('notifications')
          .select(
            '*, actor:profiles!notifications_actor_id_fkey(username,full_name,avatar_url)',
          )
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map(NotificationItem.fromJson).toList();
    } catch (e) {
      throw AppException('Could not load notifications.', cause: e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (e) {
      throw AppException('Could not update notifications.', cause: e);
    }
  }

  /// Emits whenever my notifications change (Realtime).
  Stream<void> watchChanges(String userId) => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((_) {});
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(supabaseClientProvider)),
);

final _notificationChangesProvider = StreamProvider<void>((ref) {
  final me = ref.watch(currentUserProvider.select((u) => u?.id));
  if (me == null) return const Stream.empty();
  return ref.watch(notificationsRepositoryProvider).watchChanges(me);
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) {
  ref.watch(_notificationChangesProvider);
  return ref.watch(notificationsRepositoryProvider).fetch();
});

final unreadNotificationsProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.isRead).length ??
      0,
);
