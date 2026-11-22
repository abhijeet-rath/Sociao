import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Drives the login / sign-up / sign-out buttons. State is `AsyncLoading`
/// while a request runs and `AsyncError` (with a user-safe message) on failure.
/// Successful sign-in/up changes the auth stream, and the router redirects.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn(String email, String password) =>
      _run(() => _repo.signIn(email: email, password: password));

  /// Returns true when the project requires email confirmation first.
  Future<bool> signUp(String fullName, String email, String password) async {
    var needsConfirmation = false;
    await _run(() async {
      final res = await _repo.signUp(
        fullName: fullName,
        email: email,
        password: password,
      );
      needsConfirmation = res.needsEmailConfirmation;
    });
    return needsConfirmation;
  }

  Future<void> signOut() => _run(_repo.signOut);

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
