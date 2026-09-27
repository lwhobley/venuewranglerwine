import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/offline/mutation_queue.dart';
import '../data/supabase_tenant_repository.dart';
import '../domain/tenant_models.dart';
import '../domain/tenant_repository.dart';
import '../domain/tenant_session.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return SupabaseTenantRepository(Supabase.instance.client);
});

final tenantControllerProvider =
    AsyncNotifierProvider<TenantController, TenantSession>(TenantController.new);

class TenantController extends AsyncNotifier<TenantSession> {
  @override
  Future<TenantSession> build() async {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn || !auth.emailVerified || auth.passwordRecovery) {
      return TenantSession.empty();
    }
    return ref.read(tenantRepositoryProvider).loadSession(auth.userId);
  }

  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;
    state = await AsyncValue.guard(
      () => ref.read(tenantRepositoryProvider).loadSession(auth.userId),
    );
  }

  Future<void> createOrganization({
    required String name,
    required String slug,
    String? legalName,
  }) async {
    await ref.read(tenantRepositoryProvider).createOrganization(
      name: name,
      slug: slug,
      legalName: legalName,
    );
    await refresh();
  }

  Future<void> createVenue(CreateVenueRequest request) async {
    await ref.read(tenantRepositoryProvider).createVenue(request);
    await refresh();
  }

  Future<InviteSubmit> submitInvite({
    required String organizationId,
    required String? venueId,
    required String email,
    required String roleKey,
  }) async {
    final repository = ref.read(tenantRepositoryProvider);
    final token = generateInviteToken();
    try {
      final issue = await repository.createInvite(
        organizationId: organizationId,
        venueId: venueId,
        email: email,
        roleKey: roleKey,
        token: token,
      );
      await refresh();
      return issue.created ? InviteCreated(issue.id, token) : const InviteAlreadyOpen();
    } on NetworkFailure {
      final queue = await ref.read(mutationQueueProvider.future);
      await queue.enqueue(
        kind: 'invite',
        payload: {
          'organizationId': organizationId,
          'venueId': venueId ?? '',
          'email': email,
          'roleKey': roleKey,
          'token': token,
        },
      );
      return const InviteQueued();
    }
  }

  Future<List<String>> flushInvites() async {
    final queue = await ref.read(mutationQueueProvider.future);
    final pending = await queue.pending(kind: 'invite');
    final issued = <String>[];
    for (final item in pending) {
      final token = item.payload['token'] ?? '';
      try {
        final issue = await ref.read(tenantRepositoryProvider).createInvite(
          organizationId: item.payload['organizationId'] ?? '',
          venueId: (item.payload['venueId'] ?? '').isEmpty
              ? null
              : item.payload['venueId'],
          email: item.payload['email'] ?? '',
          roleKey: item.payload['roleKey'] ?? '',
          token: token,
        );
        await queue.remove(item.id);
        if (issue.created && token.isNotEmpty) issued.add(token);
      } on NetworkFailure {
        break;
      } catch (error) {
        final message = error is AppFailure ? error.message : 'Could not send invite.';
        await queue.markFailed(item.id, message);
      }
    }
    if (issued.isNotEmpty) await refresh();
    return issued;
  }

  Future<void> revokeInvite(String inviteId) async {
    await ref.read(tenantRepositoryProvider).revokeInvite(inviteId);
    await refresh();
  }

  Future<void> acceptInvite(String token) async {
    await ref.read(tenantRepositoryProvider).acceptInvite(token);
    await refresh();
  }

  Future<VenueLookup?> lookupVenue(String code) {
    return ref.read(tenantRepositoryProvider).lookupVenue(code);
  }

  Future<void> requestJoin({
    required String code,
    required String roleKey,
    String? message,
  }) async {
    await ref.read(tenantRepositoryProvider).requestJoin(
      code: code,
      roleKey: roleKey,
      message: message,
    );
  }

  Future<void> reviewJoin({required String requestId, required bool approve}) async {
    await ref.read(tenantRepositoryProvider).reviewJoin(
      requestId: requestId,
      approve: approve,
    );
    await refresh();
  }

  Future<void> assignRole({required String membershipId, required String roleKey}) async {
    await ref.read(tenantRepositoryProvider).assignRole(
      membershipId: membershipId,
      roleKey: roleKey,
    );
    await refresh();
  }

  Future<String?> venueJoinCode(String venueId) {
    return ref.read(tenantRepositoryProvider).venueJoinCode(venueId);
  }

  Future<void> updateDisplayName(String name) async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;
    await ref.read(tenantRepositoryProvider).updateDisplayName(userId: auth.userId, name: name);
    await refresh();
  }
}

sealed class InviteSubmit {
  const InviteSubmit();
}

class InviteCreated extends InviteSubmit {
  const InviteCreated(this.id, this.token);
  final String id;
  final String token;
}

class InviteAlreadyOpen extends InviteSubmit {
  const InviteAlreadyOpen();
}

class InviteQueued extends InviteSubmit {
  const InviteQueued();
}

String generateInviteToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
