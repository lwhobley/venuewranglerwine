import 'auth_state.dart';

abstract interface class AuthRepository {
  AuthSession? currentSession();
  Stream<AuthSession?> authChanges();
  Future<bool> signIn({required String email, required String password});
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  });
  Future<void> updatePassword(String password);
  Future<void> resendVerification(String email);
  void clearRecovery();
}
