import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/app/redirect.dart';
import 'package:venue_wrangler/core/auth/auth_state.dart';
import 'package:venue_wrangler/core/permissions/permission.dart';
import 'package:venue_wrangler/features/onboarding/domain/tenant_models.dart';
import 'package:venue_wrangler/features/onboarding/domain/tenant_session.dart';

void main() {
  final emptyTenant = AsyncData(TenantSession.empty());
  const signedOut = AuthSignedOut();
  const signedIn = AuthSignedIn(
    userId: 'user-1',
    email: 'owner@cellar.test',
    emailVerified: true,
    passwordRecovery: false,
  );

  test('unconfigured installs stay on setup', () {
    expect(resolveRedirect(auth: const AuthUnconfigured(), tenant: emptyTenant, location: '/sign-in'), '/setup');
  });

  test('signed-out visitors are sent to sign in', () {
    expect(resolveRedirect(auth: signedOut, tenant: emptyTenant, location: '/app/home'), '/sign-in');
  });

  test('a new owner is sent to organization setup', () {
    expect(resolveRedirect(auth: signedIn, tenant: emptyTenant, location: '/sign-in'), '/onboarding/organization');
  });

  test('a platform administrator can create the first organization', () {
    const session = TenantSession(
      userId: 'admin',
      memberships: [],
      organizations: [],
      venues: [],
      invites: [],
      joinRequests: [],
      auditEvents: [],
      isPlatformAdmin: true,
    );
    expect(
      resolveRedirect(auth: signedIn, tenant: const AsyncData(session), location: '/sign-in'),
      '/onboarding/organization',
    );
  });

  test('a platform administrator can access an organization without membership', () {
    const session = TenantSession(
      userId: 'admin',
      memberships: [],
      organizations: [Organization(id: 'org-1', name: 'Wine', slug: 'wine')],
      venues: [],
      invites: [],
      joinRequests: [],
      auditEvents: [],
      isPlatformAdmin: true,
    );
    expect(session.can('org-1', Permission.membershipInvite), isTrue);
    expect(session.canCreateVenue, isTrue);
    expect(
      resolveRedirect(auth: signedIn, tenant: const AsyncData(session), location: '/sign-in'),
      '/onboarding/venue',
    );
  });

  test('an owner without a venue is sent to venue setup from the entry gate', () {
    final session = TenantSession(
      userId: 'user-1',
      memberships: const [
        MembershipRecord(
          id: 'm1',
          organizationId: 'org-1',
          userId: 'user-1',
          roleKey: 'organization_owner',
          status: 'active',
        ),
      ],
      organizations: const [],
      venues: const [],
      invites: const [],
      joinRequests: const [],
      auditEvents: const [],
    );
    expect(
      resolveRedirect(auth: signedIn, tenant: AsyncData(session), location: '/onboarding/organization'),
      '/onboarding/venue',
    );
  });

  test('membership loading does not bounce a signed-in user', () {
    expect(resolveRedirect(auth: signedIn, tenant: const AsyncLoading(), location: '/app/home'), isNull);
  });

  test('password recovery is isolated from the workspace', () {
    const recovery = AuthSignedIn(
      userId: 'user-1',
      email: 'owner@cellar.test',
      emailVerified: true,
      passwordRecovery: true,
    );
    expect(resolveRedirect(auth: recovery, tenant: emptyTenant, location: '/app/home'), '/auth/recovery');
  });
}
