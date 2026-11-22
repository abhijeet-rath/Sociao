import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';
import '../../profile/domain/profile.dart';
import '../domain/message_models.dart';

class MessagesRepository {
  const MessagesRepository(this._client);

  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  Future<List<InboxItem>> fetchInbox() async {
    try {
      final rows = await _client.rpc('inbox') as List<dynamic>;
      return rows
          .map((r) => InboxItem.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException('Could not load your messages.', cause: e);
    }
  }

  /// Opens (or creates) the 1:1 conversation with [otherUserId].
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      return await _client.rpc(
        'get_or_create_conversation',
        params: {'p_other': otherUserId},
      ) as String;
    } catch (e) {
      throw AppException('Could not open the chat.', cause: e);
    }
  }

  /// The other participant of a conversation.
  Future<UserSummary> fetchPartner(String conversationId) async {
    try {
      final conv = await _client
          .from('conversations')
          .select('user_a, user_b')
          .eq('id', conversationId)
          .single();
      final otherId = conv['user_a'] == _me
          ? conv['user_b'] as String
          : conv['user_a'] as String;
      final profile = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', otherId)
          .single();
      return UserSummary.fromJson(profile);
    } catch (e) {
      throw AppException('Could not load this chat.', cause: e);
    }
  }

  /// Live message list for one conversation (Supabase Realtime).
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(ChatMessage.fromJson).toList());

  /// Live reactions on every message I can see.
  Stream<List<Map<String, dynamic>>> watchReactions() => _client
      .from('message_reactions')
      .stream(primaryKey: ['message_id', 'user_id']);

  /// Emits whenever any message changes; used to refresh the inbox.
  Stream<void> watchMessageChanges() => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .map((_) {});

  Future<void> sendMessage(String conversationId, String body) async {
    final me = _me;
    if (me == null) throw const AppException('You are signed out.');
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': me,
        'body': body.trim(),
      });
    } catch (e) {
      throw AppException('Message not sent. Please try again.', cause: e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      throw AppException('Could not update read state.', cause: e);
    }
  }

  Future<void> setHeart(String messageId, {required bool on}) async {
    final me = _me;
    if (me == null) return;
    try {
      if (on) {
        await _client.from('message_reactions').upsert({
          'message_id': messageId,
          'user_id': me,
        });
      } else {
        await _client
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', me);
      }
    } catch (e) {
      throw AppException('Could not update the reaction.', cause: e);
    }
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => MessagesRepository(ref.watch(supabaseClientProvider)),
);
