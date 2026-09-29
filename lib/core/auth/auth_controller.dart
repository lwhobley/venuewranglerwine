import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../offline/mutation_queue.dart';
import '../../features/wine_inventory/data/count_draft_store.dart';
import '../../features/workforce/data/workforce_repository.dart';
import '../../features/workforce/data/workforce_notifications.dart';

import '../config/app_config.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return SupabaseAuthRepository(
    Supabase.instance.client,
    requireEmailVerification: config.requireEmailVerification,
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final config = ref.watch(appConfigProvider);
    if (!config.isConfigured) return const AuthUnconfigured();
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.authChanges().listen((session) {
      state = _fromSession(session);
    });
    ref.onDispose(subscription.cancel);
    return _fromSession(repository.currentSession());
  }

  Future<bool> signIn({required String email, required String password}) {
    return ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, displayName: displayName);
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.rpc('workforce_push_disable');
    } catch (_) {
      // Local cleanup must still complete when the device has lost connectivity.
    }
    final notifications = ref.read(workforceNotificationsProvider);
    if (notifications.supported) await notifications.local.cancelAll();
    ref.invalidate(workforceNotificationsProvider);
    await ref.read(workforceDatabaseProvider).clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(CountDraftStore.draftsKey);
    await preferences.remove(CountDraftStore.syncKey);
    await preferences.remove(SharedPreferencesMutationQueue.storageKey);
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) {
    return ref
        .read(authRepositoryProvider)
        .requestPasswordReset(email: email, redirectTo: redirectTo);
  }

  Future<void> updatePassword(String password) {
    return ref.read(authRepositoryProvider).updatePassword(password);
  }

  Future<void> resendVerification() async {
    final current = state;
    if (current is! AuthSignedIn) return;
    await ref.read(authRepositoryProvider).resendVerification(current.email);
  }

  AuthState _fromSession(AuthSession? session) {
    if (session == null) return const AuthSignedOut();
    return AuthSignedIn(
      userId: session.userId,
      email: session.email,
      emailVerified: session.emailVerified,
      passwordRecovery: session.passwordRecovery,
    );
  }
}
