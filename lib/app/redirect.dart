import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';
import '../features/onboarding/domain/tenant_session.dart';

const authRoutes = {'/sign-in', '/sign-up', '/reset-password'};
const unsignedInviteRoutes = {'/onboarding/join', '/invite'};

String? resolveRedirect({
  required AuthState auth,
  required AsyncValue<TenantSession> tenant,
  required String location,
}) {
  if (auth is AuthUnconfigured) {
    return location == '/setup' ? null : '/setup';
  }
  if (location == '/setup') return '/sign-in';
  if (auth is AuthSignedOut) {
    return authRoutes.contains(location) ? null : '/sign-in';
  }
  if (auth is! AuthSignedIn) return null;
  if (auth.passwordRecovery) {
    return location == '/auth/recovery' ? null : '/auth/recovery';
  }
  if (!auth.emailVerified) {
    return location == '/verify-email' ? null : '/verify-email';
  }
  if (tenant.isLoading) return null;
  if (tenant.hasError) {
    return location == '/app/home' ? null : '/app/home';
  }

  final session = tenant.value ?? TenantSession.empty();
  if (!session.hasMembership || (session.isPlatformAdmin && session.organizations.isEmpty)) {
    const allowed = {'/onboarding/organization', '/onboarding/join', '/invite'};
    return allowed.contains(location) ? null : '/onboarding/organization';
  }

  const entryGates = {
    '/',
    '/sign-in',
    '/sign-up',
    '/reset-password',
    '/verify-email',
    '/auth/recovery',
    '/onboarding/organization',
  };
  if (entryGates.contains(location)) {
    final next = session.hasVenue || !session.canCreateVenue ? '/app/home' : '/onboarding/venue';
    return next == location ? null : next;
  }
  return null;
}
