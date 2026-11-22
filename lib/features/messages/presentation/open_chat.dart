import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../data/messages_repository.dart';

/// Opens the chat with [userId], creating the conversation if needed.
Future<void> openChatWith(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  try {
    final id = await ref
        .read(messagesRepositoryProvider)
        .getOrCreateConversation(userId);
    if (context.mounted) context.push(AppRoutes.chat(id));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
