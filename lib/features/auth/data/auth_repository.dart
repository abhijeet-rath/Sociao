import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/app_exception.dart';

/// Result of a sign-up: [needsEmailConfirmation] is true when the project
/// requires email confirmation and no session was created yet.
class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AppException(_friendly(e), cause: e);
    } catch (e) {
      throw AppException('Could not sign in. Check your connection.', cause: e);
    }
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      return SignUpResult(needsEmailConfirmation: res.session == null);
    } on AuthException catch (e) {
      throw AppException(_friendly(e), cause: e);
    } catch (e) {
      throw AppException(
        'Could not create the account. Check your connection.',
        cause: e,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppException('Could not sign out. Please try again.', cause: e);
    }
  }

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Incorrect email or password.';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (m.contains('password')) return e.message;
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
