import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required this.requireEmailVerification});

  final SupabaseClient _client;
  final bool requireEmailVerification;
  bool _recovery = false;

  @override
  AuthSession? currentSession() => _map(_client.auth.currentSession);

  @override
  Stream<AuthSession?> authChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) _recovery = true;
      if (event.event == AuthChangeEvent.signedOut) _recovery = false;
      if (event.event == AuthChangeEvent.userUpdated) _recovery = false;
      return _map(event.session);
    });
  }

  @override
  Future<bool> signIn({required String email, required String password}) {
    return _guard(() async {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response.session != null;
    });
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return response.session != null;
    });
  }

  @override
  Future<void> signOut() {
    return _guard(() => _client.auth.signOut());
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) {
    return _guard(
      () => _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo),
    );
  }

  @override
  Future<void> updatePassword(String password) {
    return _guard(() async {
      await _client.auth.updateUser(UserAttributes(password: password));
      _recovery = false;
    });
  }

  @override
  Future<void> resendVerification(String email) {
    return _guard(
      () => _client.auth.resend(email: email.trim(), type: OtpType.signup),
    );
  }

  @override
  void clearRecovery() => _recovery = false;

  AuthSession? _map(Session? session) {
    final user = session?.user;
    if (user == null) return null;
    final confirmed = user.emailConfirmedAt != null && user.emailConfirmedAt!.isNotEmpty;
    return AuthSession(
      userId: user.id,
      email: user.email ?? '',
      emailVerified: !requireEmailVerification || confirmed,
      passwordRecovery: _recovery,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw mapFailure(error);
    }
  }
}
